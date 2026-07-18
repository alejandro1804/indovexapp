import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/sector.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';
import '../../core/db_error_helper.dart';
import '../tickets/tickets_screen.dart';

class SectoresScreen extends StatefulWidget {
  const SectoresScreen({super.key});

  @override
  State<SectoresScreen> createState() => _SectoresScreenState();
}

class _SectoresScreenState extends State<SectoresScreen> {
  final _supabase = Supabase.instance.client;
  List<Sector> _sectores = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarSectores();
  }

  Future<void> _cargarSectores() async {
    setState(() => _cargando = true);
    try {
      final data = await _supabase.from('sectores').select().order('nombre');
      setState(() {
        _sectores = (data as List).map((e) => Sector.fromMap(e)).toList();
      });
    } catch (e) {
      _mostrarError('Error al cargar sectores: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _mostrarFormulario({Sector? sector}) async {
    final nombreController = TextEditingController(text: sector?.nombre ?? '');
    final descripcionController = TextEditingController(text: sector?.descripcion ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sector == null ? 'Nuevo Sector' : 'Editar Sector'),
        content: SizedBox(
          width: Responsive.isDesktop(context) ? 400 : double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(labelText: 'Nombre *', labelStyle: TextStyle(fontSize: 13), border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descripcionController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(labelText: 'Descripción', labelStyle: TextStyle(fontSize: 13), border: OutlineInputBorder()),
                maxLines: 2,
                maxLength: 500,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (normalizarTexto(nombreController.text).isEmpty) return;
              Navigator.pop(context);
              final nombre = normalizarTexto(nombreController.text);
              final descripcion = normalizarTexto(descripcionController.text);
              if (sector == null) {
                await _crearSector(nombre, descripcion);
              } else {
                await _editarSector(sector.id, nombre, descripcion);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
            child: Text(sector == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _crearSector(String nombre, String descripcion) async {
    try {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;
      await _supabase.from('sectores').insert({
        'empresa_id': usuario.empresaId,
        'nombre': nombre,
        'descripcion': descripcion.isEmpty ? null : descripcion,
      });
      await _cargarSectores();
      _mostrarExito('Sector creado correctamente');
    } catch (e) {
      _mostrarError(mensajeAmigableDb(e, entidad: 'sector'));
    }
  }

  Future<void> _editarSector(String id, String nombre, String descripcion) async {
    try {
      await _supabase.from('sectores').update({
        'nombre': nombre,
        'descripcion': descripcion.isEmpty ? null : descripcion,
      }).eq('id', id);
      await _cargarSectores();
      _mostrarExito('Sector actualizado correctamente');
    } catch (e) {
      _mostrarError(mensajeAmigableDb(e, entidad: 'sector'));
    }
  }

  Future<void> _eliminarSector(Sector sector) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Sector'),
        content: Text('¿Estás seguro que querés eliminar "${sector.nombre}"?\n\nEsto también eliminará las máquinas asociadas.'),
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
    if (confirmar == true) {
      try {
        await _supabase.from('sectores').delete().eq('id', sector.id);
        await _cargarSectores();
        _mostrarExito('Sector eliminado');
      } catch (e) {
        _mostrarError('No se puede eliminar. Verificá que no tenga máquinas asociadas.');
      }
    }
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.gridColumns(context);
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sectores', style: TextStyle(fontSize: 17)),
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _sectores.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.domain_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No hay sectores cargados', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text('Tocá el botón + para agregar uno', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarSectores,
                  child: columns == 1
                      ? ListView.separated(
                          padding: padding,
                          itemCount: _sectores.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _buildCard(_sectores[index]),
                        )
                      : GridView.builder(
                          padding: padding,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 3,
                          ),
                          itemCount: _sectores.length,
                          itemBuilder: (context, index) => _buildCard(_sectores[index]),
                        ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCard(Sector sector) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF1F4E79).withOpacity(0.1),
          child: Text(
            sector.nombre[0].toUpperCase(),
            style: const TextStyle(color: Color(0xFF1F4E79), fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        title: Text(
          sector.nombre,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: sector.descripcion != null && sector.descripcion!.isNotEmpty
            ? Text(sector.descripcion!, style: const TextStyle(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
        trailing: PopupMenuButton(
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Editar')])),
            const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
          ],
          onSelected: (value) {
            if (value == 'editar') _mostrarFormulario(sector: sector);
            if (value == 'eliminar') _eliminarSector(sector);
          },
        ),
        // Tocar el sector abre los tickets ya filtrados por él.
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicketsScreen(sectorInicial: sector.id),
          ),
        ),
      ),
    );
  }
}