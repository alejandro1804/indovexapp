import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/usuario.dart';
import '../../core/responsive.dart';
import '../tickets/tickets_screen.dart';
import '../repuestos/repuestos_screen.dart';
import '../maquinas/maquinas_screen.dart';
import '../reportes/reportes_screen.dart';
import '../configuracion/configuracion_screen.dart';
import '../auth/login_screen.dart';
import '../planes/planes_screen.dart';
import '../admin/empresas_screen.dart';
import '../admin/gestion_planes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Items cuando está en modo CLIENTE (normal)
  List<_NavItem> _buildNavItemsCliente(Usuario usuario) {
    final items = <_NavItem>[];

    if (usuario.tienePermiso('ver_tickets')) {
      items.add(_NavItem(
        label: 'Tickets',
        icon: Icons.confirmation_number_outlined,
        iconActivo: Icons.confirmation_number,
        screen: const TicketsScreen(),
      ));
    }

    if (usuario.tienePermiso('ver_stock')) {
      items.add(_NavItem(
        label: 'Repuestos',
        icon: Icons.inventory_2_outlined,
        iconActivo: Icons.inventory_2,
        screen: const RepuestosScreen(),
      ));
    }

    if (usuario.tienePermiso('ver_maquinas')) {
      items.add(_NavItem(
        label: 'Máquinas',
        icon: Icons.precision_manufacturing_outlined,
        iconActivo: Icons.precision_manufacturing,
        screen: const MaquinasScreen(),
      ));
    }

    if (usuario.tienePermiso('ver_reportes')) {
      items.add(_NavItem(
        label: 'Reportes',
        icon: Icons.bar_chart_outlined,
        iconActivo: Icons.bar_chart,
        screen: const ReportesScreen(),
      ));
    }

    if (usuario.esAdmin) {
      items.add(_NavItem(
        label: 'Config',
        icon: Icons.settings_outlined,
        iconActivo: Icons.settings,
        screen: const ConfiguracionScreen(),
      ));
    }

    return items;
  }

  // Items cuando está en modo ADMIN (super admin)
  List<_NavItem> _buildNavItemsAdmin() {
    return [
      _NavItem(
        label: 'Empresas',
        icon: Icons.domain_outlined,
        iconActivo: Icons.domain,
        screen: const EmpresasScreen(),
      ),
      _NavItem(
        label: 'Planes',
        icon: Icons.sell_outlined,
        iconActivo: Icons.sell,
        screen: const GestionPlanesScreen(),
      ),
    ];
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Widget _buildBannerTrial(int diasRestantes) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlanesScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: diasRestantes <= 2 ? Colors.red[700] : Colors.orange[700],
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                diasRestantes == 0
                    ? 'Tu período de prueba vence hoy. ¡Elegí un plan!'
                    : 'Te quedan $diasRestantes día${diasRestantes == 1 ? '' : 's'} de prueba. Tocá para ver planes.',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  // Banner que se muestra en modo admin para recordar que estás en ese modo
  Widget _buildBannerModoAdmin(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<AuthProvider>().toggleModoAdmin(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: const Color(0xFF1F4E79),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Modo administrador de plataforma — Tocá para volver a modo cliente',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            const Icon(Icons.swap_horiz, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final usuario = authProvider.usuario;

    if (usuario == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authProvider.trialVencido && !usuario.esSuperAdmin) {
      return PlanesScreen(bloqueante: true);
    }

    final modoAdmin = authProvider.modoAdmin && usuario.esSuperAdmin;
    final navItems = modoAdmin
        ? _buildNavItemsAdmin()
        : _buildNavItemsCliente(usuario);

    if (navItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1F4E79),
          foregroundColor: Colors.white,
          title: const Text('Indovex'),
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No tenés secciones habilitadas. Contactá al administrador de tu empresa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_selectedIndex >= navItems.length) _selectedIndex = 0;

    final isDesktop = Responsive.isTabletOrDesktop(context);

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
              title: const Text('Indovex', style: TextStyle(fontWeight: FontWeight.bold)),
              actions: [
                // Botón switcher solo visible para super admin
                if (usuario.esSuperAdmin)
                  Tooltip(
                    message: modoAdmin ? 'Cambiar a modo cliente' : 'Cambiar a modo admin',
                    child: IconButton(
                      icon: Icon(
                        modoAdmin
                            ? Icons.person_outline
                            : Icons.admin_panel_settings_outlined,
                        color: modoAdmin ? Colors.amber[300] : Colors.white70,
                      ),
                      onPressed: () {
                        context.read<AuthProvider>().toggleModoAdmin();
                        setState(() => _selectedIndex = 0);
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(usuario.nombre,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(
                          modoAdmin ? 'SUPER ADMIN' : usuario.rolNombre.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: modoAdmin ? Colors.amber[300] : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => _logout(context),
                ),
              ],
            ),
      body: Column(
        children: [
          // Banner modo admin
          if (modoAdmin) _buildBannerModoAdmin(context),
          // Banner trial (solo en modo cliente)
          if (!modoAdmin && authProvider.mostrarBannerTrial && !usuario.esSuperAdmin)
            _buildBannerTrial(authProvider.diasRestantesTrial),
          // Contenido principal
          Expanded(
            child: isDesktop
                ? Row(
                    children: [
                      Container(
                        width: 240,
                        color: const Color(0xFF1F4E79),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Indovex',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Gestión Industrial',
                                    style: TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                  const SizedBox(height: 20),
                                  const Divider(color: Colors.white24),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.white24,
                                        child: Text(
                                          usuario.nombre[0].toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              usuario.nombre,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              modoAdmin
                                                  ? 'SUPER ADMIN'
                                                  : usuario.rolNombre.toUpperCase(),
                                              style: TextStyle(
                                                color: modoAdmin
                                                    ? Colors.amber[300]
                                                    : Colors.white54,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Switcher en sidebar desktop
                                  if (usuario.esSuperAdmin) ...[
                                    const SizedBox(height: 12),
                                    GestureDetector(
                                      onTap: () {
                                        context.read<AuthProvider>().toggleModoAdmin();
                                        setState(() => _selectedIndex = 0);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white12,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              modoAdmin
                                                  ? Icons.person_outline
                                                  : Icons.admin_panel_settings_outlined,
                                              color: Colors.white70,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              modoAdmin
                                                  ? 'Modo cliente'
                                                  : 'Modo admin',
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: navItems.length,
                                itemBuilder: (context, index) {
                                  final item = navItems[index];
                                  final seleccionado = _selectedIndex == index;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      color: seleccionado
                                          ? Colors.white.withOpacity(0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: ListTile(
                                      leading: Icon(
                                        seleccionado
                                            ? item.iconActivo
                                            : item.icon,
                                        color: seleccionado
                                            ? Colors.white
                                            : Colors.white60,
                                        size: 22,
                                      ),
                                      title: Text(
                                        item.label,
                                        style: TextStyle(
                                          color: seleccionado
                                              ? Colors.white
                                              : Colors.white60,
                                          fontWeight: seleccionado
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          fontSize: 14,
                                        ),
                                      ),
                                      onTap: () =>
                                          setState(() => _selectedIndex = index),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: ListTile(
                                leading: const Icon(Icons.logout,
                                    color: Colors.white54, size: 22),
                                title: const Text('Cerrar sesión',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 14)),
                                onTap: () => _logout(context),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Responsive.maxWidth(
                          child: navItems[_selectedIndex].screen,
                        ),
                      ),
                    ],
                  )
                : navItems[_selectedIndex].screen,
          ),
        ],
      ),
      bottomNavigationBar: (isDesktop || navItems.length < 2)
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              selectedItemColor: const Color(0xFF1F4E79),
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              items: navItems
                  .map((item) => BottomNavigationBarItem(
                        icon: Icon(item.icon),
                        activeIcon: Icon(item.iconActivo),
                        label: item.label,
                      ))
                  .toList(),
            ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData iconActivo;
  final Widget screen;

  _NavItem({
    required this.label,
    required this.icon,
    required this.iconActivo,
    required this.screen,
  });
}