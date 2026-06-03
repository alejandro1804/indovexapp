import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'permisos_rol_screen.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _roles = [];
  bool _cargando = true;

  // Roles del sistema: no se pueden renombrar ni eliminar (solo editar permisos)
  static const _rolesProtegidos = ['admin', 'encargado', 'tecnico'];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final roles = await _supabase.from('roles').select('id, nombre').order('nombre');
      final lista = <Map<String, dynamic>>[];
      for (final r in roles) {
        final permisos = await _supabase.from('rol_permisos').select('id').eq('rol_id', r['id']);
        final usuarios = await _supabase.from('usuarios').select('id').eq('rol_id', r['id']);
        lista.add({
          'id': r['id'],
          'nombre': r['nombre'],
          'permisos': (permisos as List).length,
          'usuarios': (usuarios as List).length,
        });
      }
      setState(() => _roles = lista);
    } catch (e) {
      _mostrarError('Error al cargar roles: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _crearRol() async {
    final controller = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo rol'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre del rol', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    try {
      await _supabase.rpc('crear_rol', params: {'p_nombre': nombre});
      _mostrarExito('Rol creado');
      await _cargar();
    } catch (e) {
      _mostrarError('Error al crear rol: $e');
    }
  }

  Future<void> _renombrarRol(Map<String, dynamic> rol) async {
    final controller = TextEditingController(text: rol['nombre']);
    final nombre = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renombrar rol'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre del rol', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    try {
      await _supabase.rpc('renombrar_rol', params: {'p_rol_id': rol['id'], 'p_nombre': nombre});
      _mostrarExito('Rol renombrado');
      await _cargar();
    } catch (e) {
      _mostrarError('Error al renombrar: $e');
    }
  }

  Future<void> _eliminarRol(Map<String, dynamic> rol) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar rol'),
        content: Text('¿Eliminar el rol "${rol['nombre']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _supabase.rpc('eliminar_rol', params: {'p_rol_id': rol['id']});
      _mostrarExito('Rol eliminado');
      await _cargar();
    } catch (e) {
      _mostrarError(e.toString().replaceAll('PostgrestException(message: ', '').split(',')[0]);
    }
  }

  void _mostrarExito(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roles y permisos'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _roles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final rol = _roles[index];
                  final esProtegido = _rolesProtegidos.contains(rol['nombre']);
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1F4E79).withOpacity(0.1),
                        child: Icon(esProtegido ? Icons.shield_outlined : Icons.badge_outlined, color: const Color(0xFF1F4E79)),
                      ),
                      title: Row(
                        children: [
                          Text(rol['nombre'], style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (esProtegido) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                              child: const Text('sistema', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text('${rol['permisos']} permisos · ${rol['usuarios']} usuarios'),
                      trailing: PopupMenuButton<String>(
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'permisos', child: Row(children: [Icon(Icons.tune, size: 18), SizedBox(width: 8), Text('Permisos')])),
                          if (!esProtegido) const PopupMenuItem(value: 'renombrar', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Renombrar')])),
                          if (!esProtegido) const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
                        ],
                        onSelected: (v) {
                          if (v == 'permisos') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => PermisosRolScreen(rolId: rol['id'], rolNombre: rol['nombre']))).then((_) => _cargar());
                          }
                          if (v == 'renombrar') _renombrarRol(rol);
                          if (v == 'eliminar') _eliminarRol(rol);
                        },
                      ),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PermisosRolScreen(rolId: rol['id'], rolNombre: rol['nombre']))).then((_) => _cargar());
                      },
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _crearRol,
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}