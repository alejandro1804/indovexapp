import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/legal_provider.dart';
import '../../models/usuario.dart';
import '../../core/responsive.dart';
import '../../widgets/legal_gate.dart';
import '../../widgets/notificaciones_bell.dart';
import '../tickets/tickets_screen.dart';
import '../repuestos/repuestos_screen.dart';
import '../maquinas/maquinas_screen.dart';
import '../reportes/reportes_screen.dart';
import '../configuracion/configuracion_screen.dart';
import '../configuracion/sectores_screen.dart';
import '../configuracion/usuarios_screen.dart';
import '../auth/login_screen.dart';
import '../planes/planes_screen.dart';
import '../planes_mantenimiento/planes_mantenimiento_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../admin/empresas_screen.dart';
import '../admin/gestion_planes_screen.dart';
import '../pagos/pagos_screen.dart';
import '../admin/legal_cobertura_screen.dart';
import '../../main.dart' show pendingTicketId;
import '../tickets/ticket_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _indexInicializado = false;

  String _version = '';

  @override
    void initState() {
      super.initState();
      _cargarVersion();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<LegalProvider>().cargar();
        _abrirTicketPendiente();
      });
    }

    // Si un push abrió la app (estaba cerrada), navegar al ticket ahora que
    // el home ya está montado. Se hace acá para no competir con la carga inicial.
    void _abrirTicketPendiente() {
      final id = pendingTicketId;
      if (id != null && id.isNotEmpty) {
        pendingTicketId = null; // consumir una sola vez
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: id)),
          );
        });
      }
    }

  Future<void> _cargarVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = 'v${info.version}');
      }
    } catch (_) {
      // Si falla, simplemente no se muestra la versión.
    }
  }

  /// Destinos siempre visibles en la barra inferior (mobile).
  /// Sectores y Usuarios salieron de Configuración: estaban demasiado
  /// enterrados para el alta inicial (sin sector no se crean máquinas).
  List<_NavItem> _buildNavItemsPrimarios(Usuario usuario) {
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
        label: 'Activos',
        icon: Icons.precision_manufacturing_outlined,
        iconActivo: Icons.precision_manufacturing,
        screen: const MaquinasScreen(),
      ));
    }

    if (usuario.esAdmin) {
      items.add(_NavItem(
        label: 'Ubicacion',
        icon: Icons.domain_outlined,
        iconActivo: Icons.domain,
        screen: const SectoresScreen(),
      ));
    }

    if (usuario.esAdmin) {
      items.add(_NavItem(
        label: 'Usuarios',
        icon: Icons.people_outline,
        iconActivo: Icons.people,
        screen: const UsuariosScreen(),
      ));
    }

    return items;
  }

  /// Destinos de uso ocasional: detrás del botón "Más" en mobile,
  /// planos en el menú lateral de desktop.
  List<_NavItem> _buildNavItemsSecundarios(Usuario usuario) {
    final items = <_NavItem>[];

    if (usuario.tienePermiso('ver_dashboard')) {
      items.add(_NavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        iconActivo: Icons.dashboard,
        screen: const DashboardScreen(),
      ));
    }

    if (usuario.tienePermiso('ver_planes_mantenimiento')) {
      items.add(_NavItem(
        label: 'Planes',
        icon: Icons.event_repeat_outlined,
        iconActivo: Icons.event_repeat,
        screen: const PlanesMantenimientoScreen(),
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

    return items;
  }

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
      _NavItem(
        label: 'Pagos',
        icon: Icons.receipt_long_outlined,
        iconActivo: Icons.receipt_long,
        screen: const PagosScreen(),
      ),
      _NavItem(
        label: 'Legal',
        icon: Icons.gavel_outlined,
        iconActivo: Icons.gavel,
        screen: const LegalCoberturaScreen(),
      ),
    ];
  }

  /// Devuelve el índice inicial según el rol del usuario.
  /// Admin de empresa → busca el tab Dashboard si tiene permiso.
  /// Resto → 0 (primer tab disponible).
  int _calcularIndexInicial(List<_NavItem> navItems, Usuario usuario) {
    if (usuario.esAdmin) {
      final idx = navItems.indexWhere((item) => item.label == 'Dashboard');
      if (idx != -1) return idx;
    }
    return 0;
  }

  /// Hoja inferior con los destinos ocasionales.
  /// El índice es absoluto sobre la lista completa de navItems.
  void _mostrarMenuMas(int offsetSecundarios, List<_NavItem> secundarios) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ...secundarios.asMap().entries.map((entry) {
                final indexAbsoluto = offsetSecundarios + entry.key;
                final item = entry.value;
                final seleccionado = _selectedIndex == indexAbsoluto;
                return ListTile(
                  leading: Icon(
                    seleccionado ? item.iconActivo : item.icon,
                    color: seleccionado ? const Color(0xFF1F4E79) : Colors.grey[700],
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      color: seleccionado ? const Color(0xFF1F4E79) : Colors.black87,
                      fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _selectedIndex = indexAbsoluto);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    context.read<LegalProvider>().limpiar();
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

  /// Banner discreto cuando no se pudo verificar el estado legal.
  /// No bloquea (fail-open), pero deja el error visible.
  Widget _buildBannerErrorLegal(String mensaje) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.grey[700],
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white54, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final legalProvider = context.watch<LegalProvider>();
    final usuario = authProvider.usuario;

    if (usuario == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authProvider.trialVencido && !usuario.esSuperAdmin) {
      return PlanesScreen(bloqueante: true);
    }

    // Documentos legales: esperamos la primera verificación antes de
    // renderizar, para no mostrar la app y taparla un instante después.
    if (!legalProvider.cargado && legalProvider.cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Vencido el preaviso, el admin debe aceptar antes de operar
    // (T&C cl. 13 / Priv. cl. 10).
    if (legalProvider.hayBloqueo) {
      return LegalBloqueoScreen(
        documentos: legalProvider.bloqueantes,
        onLogout: () => _logout(context),
      );
    }

    final modoAdmin = authProvider.modoAdmin && usuario.esSuperAdmin;
    final isDesktop = Responsive.isTabletOrDesktop(context);

    // Config: en mobile vive en la AppBar; en desktop, donde sobra
    // espacio, sigue siendo un destino más del menú lateral.
    final mostrarConfig = !modoAdmin && usuario.esAdmin;

    final primarios = modoAdmin ? _buildNavItemsAdmin() : _buildNavItemsPrimarios(usuario);
    final secundarios = modoAdmin ? <_NavItem>[] : _buildNavItemsSecundarios(usuario);

    // Lista completa. _selectedIndex es un índice absoluto sobre ésta.
    final navItems = <_NavItem>[
      ...primarios,
      ...secundarios,
      if (isDesktop && mostrarConfig)
        _NavItem(
          label: 'Config',
          icon: Icons.settings_outlined,
          iconActivo: Icons.settings,
          screen: const ConfiguracionScreen(),
        ),
    ];

    if (navItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1F4E79),
          foregroundColor: Colors.white,
          title: const Text('IndovexApp'),
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

    // Inicializar índice una sola vez por sesión
    if (!_indexInicializado) {
      _selectedIndex = _calcularIndexInicial(navItems, usuario);
      _indexInicializado = true;
    }

    if (_selectedIndex >= navItems.length) _selectedIndex = 0;

    // ¿La pantalla activa está dentro de "Más"? Sirve para resaltar el botón.
    final enSecundario = _selectedIndex >= primarios.length &&
        _selectedIndex < primarios.length + secundarios.length;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
              title: const Text('IndovexApp', style: TextStyle(fontWeight: FontWeight.bold)),
              actions: [
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
                        setState(() {
                          _selectedIndex = 0;
                          _indexInicializado = false;
                        });
                      },
                    ),
                  ),
                // Configuración: acción de AppBar, ya no ocupa lugar abajo.
                if (mostrarConfig)
                  Tooltip(
                    message: 'Configuración',
                    child: IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
                      ),
                    ),
                  ),
                // Campanita de notificaciones (no la ve el super admin en
                // modo plataforma, que no opera tickets de clientes).
                if (!modoAdmin) const NotificacionesBell(color: Colors.white),
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
          if (modoAdmin) _buildBannerModoAdmin(context),
          if (!modoAdmin && authProvider.mostrarBannerTrial && !usuario.esSuperAdmin)
            _buildBannerTrial(authProvider.diasRestantesTrial),
          // Avisos legales no bloqueantes: preaviso para el admin,
          // informativos para el resto.
          if (!modoAdmin)
            ...legalProvider.avisos.map(
              (doc) => LegalBannerAviso(
                documento: doc,
                puedeAceptar: usuario.esAdminEmpresa,
              ),
            ),
          if (legalProvider.error != null)
            _buildBannerErrorLegal(legalProvider.error!),
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
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'IndovexApp',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Gestión Industrial',
                                              style: TextStyle(color: Colors.white54, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Campanita también en el panel de escritorio.
                                      if (!modoAdmin)
                                        const NotificacionesBell(color: Colors.white),
                                    ],
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
                                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  if (usuario.esSuperAdmin) ...[
                                    const SizedBox(height: 12),
                                    GestureDetector(
                                      onTap: () {
                                        context.read<AuthProvider>().toggleModoAdmin();
                                        setState(() {
                                          _selectedIndex = 0;
                                          _indexInicializado = false;
                                        });
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
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: navItems.length,
                                itemBuilder: (context, index) {
                                  final item = navItems[index];
                                  final seleccionado = _selectedIndex == index;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      color: seleccionado
                                          ? Colors.white.withValues(alpha: 0.15)
                                          : Colors.transparent,
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
                                          fontWeight: seleccionado
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          fontSize: 14,
                                        ),
                                      ),
                                      onTap: () => setState(() => _selectedIndex = index),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8)),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: ListTile(
                                leading: const Icon(Icons.logout, color: Colors.white54, size: 22),
                                title: const Text('Cerrar sesión',
                                    style: TextStyle(color: Colors.white54, fontSize: 14)),
                                onTap: () => _logout(context),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            if (_version.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _version,
                                  style: const TextStyle(color: Colors.white38, fontSize: 11),
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
          // Versión en mobile: barra delgada al pie
          if (!isDesktop && _version.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.grey[100],
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                _version,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 10),
              ),
            ),
        ],
      ),
      bottomNavigationBar: (isDesktop || navItems.length < 2)
          ? null
          : BottomNavigationBar(
              // Si la pantalla activa está en "Más", se resalta ese botón.
              currentIndex: enSecundario ? primarios.length : _selectedIndex,
              onTap: (index) {
                if (secundarios.isNotEmpty && index == primarios.length) {
                  _mostrarMenuMas(primarios.length, secundarios);
                } else {
                  setState(() => _selectedIndex = index);
                }
              },
              selectedItemColor: const Color(0xFF1F4E79),
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              items: [
                ...primarios.map((item) => BottomNavigationBarItem(
                      icon: Icon(item.icon),
                      activeIcon: Icon(item.iconActivo),
                      label: item.label,
                    )),
                // "Más" sólo si hay algo detrás.
                if (secundarios.isNotEmpty)
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.more_horiz_outlined),
                    activeIcon: Icon(Icons.more_horiz),
                    label: 'Más',
                  ),
              ],
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