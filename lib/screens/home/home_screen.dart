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
import '../admin/empresas_pendientes_screen.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<_NavItem> _buildNavItems(Usuario usuario) {
    final items = <_NavItem>[];

    if (!usuario.esShopper) {
      items.add(_NavItem(
        label: 'Tickets',
        icon: Icons.confirmation_number_outlined,
        iconActivo: Icons.confirmation_number,
        screen: const TicketsScreen(),
      ));
    }

    if (usuario.puedeVerStock) {
      items.add(_NavItem(
        label: 'Repuestos',
        icon: Icons.inventory_2_outlined,
        iconActivo: Icons.inventory_2,
        screen: const RepuestosScreen(),
      ));
    }

    if (!usuario.esOperario && !usuario.esShopper) {
      items.add(_NavItem(
        label: 'Máquinas',
        icon: Icons.precision_manufacturing_outlined,
        iconActivo: Icons.precision_manufacturing,
        screen: const MaquinasScreen(),
      ));
    }

    if (usuario.esAdmin || usuario.esEncargado || usuario.esShopper || usuario.esSupervisor) {
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

    if (usuario.esSuperAdmin) {
      items.add(_NavItem(
        label: 'Empresas',
        icon: Icons.domain_outlined,
        iconActivo: Icons.domain,
        screen: const EmpresasPendientesScreen(),
      ));
    }

    return items;
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final usuario = authProvider.usuario;

    if (usuario == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final navItems = _buildNavItems(usuario);
    if (_selectedIndex >= navItems.length) _selectedIndex = 0;

    final isDesktop = Responsive.isTabletOrDesktop(context);

    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        title: const Text('Indovex', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(usuario.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(usuario.rolNombre.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white70)),
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
      body: isDesktop
          ? Row(
              children: [
                // Sidebar
                Container(
                  width: 240,
                  color: const Color(0xFF1F4E79),
                  child: Column(
                    children: [
                      // Header sidebar
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
                            // Info usuario
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white24,
                                  child: Text(
                                    usuario.nombre[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        usuario.nombre,
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        usuario.rolNombre.toUpperCase(),
                                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Nav items
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: navItems.length,
                          itemBuilder: (context, index) {
                            final item = navItems[index];
                            final seleccionado = _selectedIndex == index;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: seleccionado ? Colors.white.withOpacity(0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  seleccionado ? item.iconActivo : item.icon,
                                  color: seleccionado ? Colors.white : Colors.white60,
                                  size: 22,
                                ),
                                title: Text(
                                  item.label,
                                  style: TextStyle(
                                    color: seleccionado ? Colors.white : Colors.white60,
                                    fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () => setState(() => _selectedIndex = index),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            );
                          },
                        ),
                      ),
                      // Logout
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: ListTile(
                          leading: const Icon(Icons.logout, color: Colors.white54, size: 22),
                          title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white54, fontSize: 14)),
                          onTap: () => _logout(context),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenido principal
                Expanded(
                  child: Responsive.maxWidth(
                    child: navItems[_selectedIndex].screen,
                  ),
                ),
              ],
            )
          : navItems[_selectedIndex].screen,
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              selectedItemColor: const Color(0xFF1F4E79),
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              items: navItems.map((item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                activeIcon: Icon(item.iconActivo),
                label: item.label,
              )).toList(),
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