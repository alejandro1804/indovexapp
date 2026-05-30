import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/proveedor.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';

class ProveedoresScreen extends StatefulWidget {
  const ProveedoresScreen({super.key});

  @override
  State<ProveedoresScreen> createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> {
  final _supabase = Supabase.instance.client;
  List<Proveedor> _proveedores = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargarProveedores(); }

  Future<void> _cargarProveedores() async {
    setState(() => _cargando = true);
    try {
      final data = await _supabase.from('proveedores').select().order('nombre');
      setState(() { _proveedores = (data as List).map((e) => Proveedor.fromMap(e)).toList(); });
    } catch (e) { _mostrarError('Error al cargar proveedores: $e'); }
    finally { setState(() => _cargando = false); }
  }

  Future<void> _mostrarFormulario({Proveedor? proveedor}) async {
    final nombreController = TextEditingController(text: proveedor?.nombre ?? '');
    final rutController = TextEditingController(text: proveedor?.rut ?? '');
    final contactoController = TextEditingController(text: proveedor?.contacto ?? '');
    final telefonoController = TextEditingController(text: proveedor?.telefono ?? '');
    final emailController = TextEditingController(text: proveedor?.email ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(proveedor == null ? 'Nuevo Proveedor' : 'Editar Proveedor'),
        content: SizedBox(
          width: Responsive.isDesktop(context) ? 480 : double.maxFinite,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder()), textCapitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              TextField(controller: rutController, decoration: const InputDecoration(labelText: 'RUT', border: OutlineInputBorder(), hintText: 'Ej: 21234567-8'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: contactoController, decoration: const InputDecoration(labelText: 'Contacto', border: OutlineInputBorder()), textCapitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              TextField(controller: telefonoController, decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.trim().isEmpty) return;
              Navigator.pop(context);
              if (proveedor == null) {
                await _crearProveedor(nombre: nombreController.text.trim(), rut: rutController.text.trim(), contacto: contactoController.text.trim(), telefono: telefonoController.text.trim(), email: emailController.text.trim());
              } else {
                await _editarProveedor(id: proveedor.id, nombre: nombreController.text.trim(), rut: rutController.text.trim(), contacto: contactoController.text.trim(), telefono: telefonoController.text.trim(), email: emailController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
            child: Text(proveedor == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _crearProveedor({required String nombre, required String rut, required String contacto, required String telefono, required String email}) async {
    try {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;
      await _supabase.from('proveedores').insert({'empresa_id': usuario.empresaId, 'nombre': nombre, 'rut': rut.isEmpty ? null : rut, 'contacto': contacto.isEmpty ? null : contacto, 'telefono': telefono.isEmpty ? null : telefono, 'email': email.isEmpty ? null : email});
      await _cargarProveedores();
      _mostrarExito('Proveedor creado correctamente');
    } catch (e) { _mostrarError('Error al crear proveedor: $e'); }
  }

  Future<void> _editarProveedor({required String id, required String nombre, required String rut, required String contacto, required String telefono, required String email}) async {
    try {
      await _supabase.from('proveedores').update({'nombre': nombre, 'rut': rut.isEmpty ? null : rut, 'contacto': contacto.isEmpty ? null : contacto, 'telefono': telefono.isEmpty ? null : telefono, 'email': email.isEmpty ? null : email}).eq('id', id);
      await _cargarProveedores();
      _mostrarExito('Proveedor actualizado correctamente');
    } catch (e) { _mostrarError('Error al actualizar proveedor: $e'); }
  }

  Future<void> _eliminarProveedor(Proveedor proveedor) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Proveedor'),
        content: Text('¿Estás seguro que querés eliminar "${proveedor.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await _supabase.from('proveedores').delete().eq('id', proveedor.id);
        await _cargarProveedores();
        _mostrarExito('Proveedor eliminado');
      } catch (e) { _mostrarError('No se puede eliminar. Tiene ingresos asociados.'); }
    }
  }

  void _mostrarExito(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)); }
  void _mostrarError(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating)); }

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.gridColumns(context);
    final padding = Responsive.pagePadding(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores'), backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _proveedores.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.local_shipping_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No hay proveedores cargados', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Tocá el botón + para agregar uno', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                ]))
              : RefreshIndicator(
                  onRefresh: _cargarProveedores,
                  child: columns == 1
                      ? ListView.separated(padding: padding, itemCount: _proveedores.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) => _buildCard(_proveedores[index]))
                      : GridView.builder(padding: padding, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5), itemCount: _proveedores.length, itemBuilder: (context, index) => _buildCard(_proveedores[index])),
                ),
      floatingActionButton: FloatingActionButton(onPressed: () => _mostrarFormulario(), backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white, child: const Icon(Icons.add)),
    );
  }

  Widget _buildCard(Proveedor proveedor) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFF1F4E79).withOpacity(0.1), child: Text(proveedor.nombre[0].toUpperCase(), style: const TextStyle(color: Color(0xFF1F4E79), fontWeight: FontWeight.bold))),
        title: Text(proveedor.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (proveedor.rut != null && proveedor.rut!.isNotEmpty) Text('RUT: ${proveedor.rut}'),
          if (proveedor.contacto != null && proveedor.contacto!.isNotEmpty) Text(proveedor.contacto!),
          if (proveedor.telefono != null && proveedor.telefono!.isNotEmpty)
            Row(children: [const Icon(Icons.phone_outlined, size: 12, color: Colors.grey), const SizedBox(width: 4), Text(proveedor.telefono!, style: const TextStyle(fontSize: 12))]),
        ]),
        isThreeLine: true,
        trailing: PopupMenuButton(
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Editar')])),
            const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
          ],
          onSelected: (value) {
            if (value == 'editar') _mostrarFormulario(proveedor: proveedor);
            if (value == 'eliminar') _eliminarProveedor(proveedor);
          },
        ),
      ),
    );
  }
}
