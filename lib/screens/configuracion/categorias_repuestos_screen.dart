import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/categoria_repuesto.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';

class CategoriasRepuestosScreen extends StatefulWidget {
  const CategoriasRepuestosScreen({super.key});

  @override
  State<CategoriasRepuestosScreen> createState() => _CategoriasRepuestosScreenState();
}

class _CategoriasRepuestosScreenState extends State<CategoriasRepuestosScreen> {
  final _supabase = Supabase.instance.client;
  List<CategoriaRepuesto> _categorias = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargarCategorias(); }

  Future<void> _cargarCategorias() async {
    setState(() => _cargando = true);
    try {
      final data = await _supabase.from('categorias_repuestos').select().order('nombre');
      setState(() { _categorias = (data as List).map((e) => CategoriaRepuesto.fromMap(e)).toList(); });
    } catch (e) { _mostrarError('Error al cargar categorías: $e'); }
    finally { setState(() => _cargando = false); }
  }

  Future<void> _mostrarFormulario({CategoriaRepuesto? categoria}) async {
    final nombreController = TextEditingController(text: categoria?.nombre ?? '');
    final descripcionController = TextEditingController(text: categoria?.descripcion ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(categoria == null ? 'Nueva Categoría' : 'Editar Categoría'),
        content: SizedBox(
          width: Responsive.isDesktop(context) ? 400 : double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder()), textCapitalization: TextCapitalization.words),
            const SizedBox(height: 16),
            TextField(controller: descripcionController, decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()), maxLines: 2),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nombreController.text.trim().isEmpty) return;
              Navigator.pop(context);
              if (categoria == null) { await _crearCategoria(nombreController.text.trim(), descripcionController.text.trim()); }
              else { await _editarCategoria(categoria.id, nombreController.text.trim(), descripcionController.text.trim()); }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
            child: Text(categoria == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _crearCategoria(String nombre, String descripcion) async {
    try {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;
      await _supabase.from('categorias_repuestos').insert({'empresa_id': usuario.empresaId, 'nombre': nombre, 'descripcion': descripcion.isEmpty ? null : descripcion});
      await _cargarCategorias();
      _mostrarExito('Categoría creada correctamente');
    } catch (e) { _mostrarError('Error al crear categoría: $e'); }
  }

  Future<void> _editarCategoria(String id, String nombre, String descripcion) async {
    try {
      await _supabase.from('categorias_repuestos').update({'nombre': nombre, 'descripcion': descripcion.isEmpty ? null : descripcion}).eq('id', id);
      await _cargarCategorias();
      _mostrarExito('Categoría actualizada correctamente');
    } catch (e) { _mostrarError('Error al actualizar categoría: $e'); }
  }

  Future<void> _eliminarCategoria(CategoriaRepuesto categoria) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text('¿Estás seguro que querés eliminar "${categoria.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await _supabase.from('categorias_repuestos').delete().eq('id', categoria.id);
        await _cargarCategorias();
        _mostrarExito('Categoría eliminada');
      } catch (e) { _mostrarError('No se puede eliminar. Tiene repuestos asociados.'); }
    }
  }

  void _mostrarExito(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)); }
  void _mostrarError(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating)); }

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.gridColumns(context);
    final padding = Responsive.pagePadding(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Categorías de Repuestos'), backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _categorias.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.category_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No hay categorías cargadas', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Tocá el botón + para agregar una', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                ]))
              : RefreshIndicator(
                  onRefresh: _cargarCategorias,
                  child: columns == 1
                      ? ListView.separated(padding: padding, itemCount: _categorias.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) => _buildCard(_categorias[index]))
                      : GridView.builder(padding: padding, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 3), itemCount: _categorias.length, itemBuilder: (context, index) => _buildCard(_categorias[index])),
                ),
      floatingActionButton: FloatingActionButton(onPressed: () => _mostrarFormulario(), backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white, child: const Icon(Icons.add)),
    );
  }

  Widget _buildCard(CategoriaRepuesto categoria) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFF2E75B6).withOpacity(0.1), child: Text(categoria.nombre[0].toUpperCase(), style: const TextStyle(color: Color(0xFF2E75B6), fontWeight: FontWeight.bold))),
        title: Text(categoria.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: categoria.descripcion != null && categoria.descripcion!.isNotEmpty ? Text(categoria.descripcion!) : null,
        trailing: PopupMenuButton(
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Editar')])),
            const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
          ],
          onSelected: (value) {
            if (value == 'editar') _mostrarFormulario(categoria: categoria);
            if (value == 'eliminar') _eliminarCategoria(categoria);
          },
        ),
      ),
    );
  }
}
