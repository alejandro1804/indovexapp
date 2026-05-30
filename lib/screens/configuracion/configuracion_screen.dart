import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'sectores_screen.dart';
import 'usuarios_screen.dart';
import 'proveedores_screen.dart';
import 'categorias_repuestos_screen.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthProvider>().usuario;

    final opciones = [
      _ConfigOpcion(
        icono: Icons.domain_outlined,
        titulo: 'Sectores',
        descripcion: 'Gestionar sectores de la planta',
        screen: const SectoresScreen(),
        visible: true,
      ),
      _ConfigOpcion(
        icono: Icons.category_outlined,
        titulo: 'Categorías de Repuestos',
        descripcion: 'Organizar repuestos por categoría',
        screen: const CategoriasRepuestosScreen(),
        visible: true,
      ),
      _ConfigOpcion(
        icono: Icons.local_shipping_outlined,
        titulo: 'Proveedores',
        descripcion: 'Gestionar proveedores de repuestos',
        screen: const ProveedoresScreen(),
        visible: true,
      ),
      _ConfigOpcion(
        icono: Icons.people_outline,
        titulo: 'Usuarios',
        descripcion: 'Gestionar usuarios y roles',
        screen: const UsuariosScreen(),
        visible: usuario?.esAdmin ?? false,
      ),
    ].where((o) => o.visible).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: opciones.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final opcion = opciones[index];
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF1F4E79).withOpacity(0.1),
                child: Icon(opcion.icono, color: const Color(0xFF1F4E79)),
              ),
              title: Text(opcion.titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(opcion.descripcion),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => opcion.screen),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConfigOpcion {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final Widget screen;
  final bool visible;

  _ConfigOpcion({
    required this.icono,
    required this.titulo,
    required this.descripcion,
    required this.screen,
    required this.visible,
  });
}
