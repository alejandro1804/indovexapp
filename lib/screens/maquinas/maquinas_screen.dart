import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/maquina.dart';
import '../../models/sector.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';
import 'maquina_detail_screen.dart';

class MaquinasScreen extends StatefulWidget {
  const MaquinasScreen({super.key});
  @override
  State<MaquinasScreen> createState() => _MaquinasScreenState();
}

class _MaquinasScreenState extends State<MaquinasScreen> {
  final _supabase = Supabase.instance.client;
  List<Maquina> _maquinas = [];
  List<Sector> _sectores = [];
  bool _cargando = true;
  String _filtroEstado = 'todos';

  @override
  void initState() { super.initState(); _cargarDatos(); }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final maquinasData = await _supabase.from('maquinas').select().order('nombre');
      final sectoresData = await _supabase.from('sectores').select().order('nombre');
      setState(() {
        _maquinas = (maquinasData as List).map((e) => Maquina.fromMap(e)).toList();
        _sectores = (sectoresData as List).map((e) => Sector.fromMap(e)).toList();
      });
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  List<Maquina> get _maquinasFiltradas {
    if (_filtroEstado == 'todos') return _maquinas;
    return _maquinas.where((m) => m.estado == _filtroEstado).toList();
  }

  String _nombreSector(String sectorId) {
    return _sectores.firstWhere((s) => s.id == sectorId,
        orElse: () => Sector(id: '', empresaId: '', nombre: 'Sin sector')).nombre;
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'operativa': return Colors.green;
      case 'en_mantenimiento': return Colors.orange;
      case 'fuera_de_servicio': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _labelEstado(String estado) {
    switch (estado) {
      case 'operativa': return 'Operativa';
      case 'en_mantenimiento': return 'En mant.';
      case 'fuera_de_servicio': return 'Fuera serv.';
      default: return estado;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'operativa': return Icons.check_circle_outline;
      case 'en_mantenimiento': return Icons.build_outlined;
      case 'fuera_de_servicio': return Icons.cancel_outlined;
      default: return Icons.help_outline;
    }
  }

  Future<void> _mostrarFormulario({Maquina? maquina}) async {
    if (_sectores.isEmpty) { _mostrarError('Primero debés crear al menos un sector'); return; }
    final nombreController = TextEditingController(text: maquina?.nombre ?? '');
    final codigoController = TextEditingController(text: maquina?.codigo ?? '');
    final descripcionController = TextEditingController(text: maquina?.descripcion ?? '');
    String sectorSeleccionado = maquina?.sectorId ?? _sectores.first.id;
    String estadoSeleccionado = maquina?.estado ?? 'operativa';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(maquina == null ? 'Nueva Máquina' : 'Editar Máquina'),
          content: SizedBox(
            width: Responsive.isDesktop(context) ? 480 : double.maxFinite,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder()), textCapitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                TextField(controller: codigoController, decoration: const InputDecoration(labelText: 'Código *', border: OutlineInputBorder(), hintText: 'Ej: MAQ-001'), textCapitalization: TextCapitalization.characters),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: sectorSeleccionado,
                  decoration: const InputDecoration(labelText: 'Sector *', border: OutlineInputBorder()),
                  items: _sectores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nombre))).toList(),
                  onChanged: (v) => setDialogState(() => sectorSeleccionado = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: estadoSeleccionado,
                  decoration: const InputDecoration(labelText: 'Estado *', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'operativa', child: Text('Operativa')),
                    DropdownMenuItem(value: 'en_mantenimiento', child: Text('En mantenimiento')),
                    DropdownMenuItem(value: 'fuera_de_servicio', child: Text('Fuera de servicio')),
                  ],
                  onChanged: (v) => setDialogState(() => estadoSeleccionado = v!),
                ),
                const SizedBox(height: 12),
                TextField(controller: descripcionController, decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()), maxLines: 2),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (nombreController.text.trim().isEmpty || codigoController.text.trim().isEmpty) return;
                Navigator.pop(context);
                if (maquina == null) {
                  await _crearMaquina(nombre: nombreController.text.trim(), codigo: codigoController.text.trim(), sectorId: sectorSeleccionado, estado: estadoSeleccionado, descripcion: descripcionController.text.trim());
                } else {
                  await _editarMaquina(id: maquina.id, nombre: nombreController.text.trim(), codigo: codigoController.text.trim(), sectorId: sectorSeleccionado, estado: estadoSeleccionado, descripcion: descripcionController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
              child: Text(maquina == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearMaquina({required String nombre, required String codigo, required String sectorId, required String estado, required String descripcion}) async {
    try {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;
      await _supabase.from('maquinas').insert({'empresa_id': usuario.empresaId, 'sector_id': sectorId, 'nombre': nombre, 'codigo': codigo, 'estado': estado, 'descripcion': descripcion.isEmpty ? null : descripcion});
      await _cargarDatos();
      _mostrarExito('Máquina creada correctamente');
    } catch (e) { _mostrarError('Error al crear máquina: $e'); }
  }

  Future<void> _editarMaquina({required String id, required String nombre, required String codigo, required String sectorId, required String estado, required String descripcion}) async {
    try {
      await _supabase.from('maquinas').update({'sector_id': sectorId, 'nombre': nombre, 'codigo': codigo, 'estado': estado, 'descripcion': descripcion.isEmpty ? null : descripcion}).eq('id', id);
      await _cargarDatos();
      _mostrarExito('Máquina actualizada correctamente');
    } catch (e) { _mostrarError('Error al actualizar máquina: $e'); }
  }

  Future<void> _eliminarMaquina(Maquina maquina) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Máquina'),
        content: Text('¿Estás seguro que querés eliminar "${maquina.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await _supabase.from('maquinas').delete().eq('id', maquina.id);
        await _cargarDatos();
        _mostrarExito('Máquina eliminada');
      } catch (e) { _mostrarError('No se puede eliminar. Tiene tickets o repuestos asociados.'); }
    }
  }

  void _mostrarExito(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)); }
  void _mostrarError(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating)); }

  Widget _buildCard(Maquina maquina) {
    final titleSize = Responsive.cardTitleSize(context);
    final subtitleSize = Responsive.cardSubtitleSize(context);
    final chipSize = Responsive.chipFontSize(context);
    final avatarRadius = Responsive.avatarRadius(context);
    final cardPadding = Responsive.cardPadding(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MaquinaDetailScreen(maquina: maquina))).then((_) => _cargarDatos()),
        child: Padding(
          padding: cardPadding,
          child: Row(
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: _colorEstado(maquina.estado).withOpacity(0.1),
                child: Icon(_iconoEstado(maquina.estado), color: _colorEstado(maquina.estado), size: avatarRadius),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(maquina.nombre, style: TextStyle(fontWeight: FontWeight.w600, fontSize: titleSize), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Código: ${maquina.codigo}', style: TextStyle(color: Colors.grey[600], fontSize: subtitleSize)),
                    Text(_nombreSector(maquina.sectorId), style: TextStyle(color: Colors.grey[500], fontSize: subtitleSize)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: _colorEstado(maquina.estado).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_labelEstado(maquina.estado), style: TextStyle(fontSize: chipSize, color: _colorEstado(maquina.estado), fontWeight: FontWeight.w600)),
                  ),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, size: avatarRadius),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'editar', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Editar')])),
                      const PopupMenuItem(value: 'eliminar', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
                    ],
                    onSelected: (value) {
                      if (value == 'editar') _mostrarFormulario(maquina: maquina);
                      if (value == 'eliminar') _eliminarMaquina(maquina);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltroChip(String valor, String label) {
    final seleccionado = _filtroEstado == valor;
    return FilterChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (_) => setState(() => _filtroEstado = valor),
      selectedColor: const Color(0xFF1F4E79).withOpacity(0.15),
      checkmarkColor: const Color(0xFF1F4E79),
      labelStyle: TextStyle(color: seleccionado ? const Color(0xFF1F4E79) : Colors.grey[700], fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maquinasFiltradas = _maquinasFiltradas;
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Máquinas'), backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _buildFiltroChip('todos', 'Todos'),
                    const SizedBox(width: 8),
                    _buildFiltroChip('operativa', 'Operativas'),
                    const SizedBox(width: 8),
                    _buildFiltroChip('en_mantenimiento', 'En mantenimiento'),
                    const SizedBox(width: 8),
                    _buildFiltroChip('fuera_de_servicio', 'Fuera de servicio'),
                  ]),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Colors.grey[100],
                child: Text('${maquinasFiltradas.length} máquina${maquinasFiltradas.length != 1 ? 's' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ),
              Expanded(
                child: maquinasFiltradas.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.precision_manufacturing_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(_maquinas.isEmpty ? 'No hay máquinas cargadas' : 'No hay máquinas con ese filtro', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _cargarDatos,
                        child: ListView.separated(
                          padding: padding,
                          itemCount: maquinasFiltradas.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _buildCard(maquinasFiltradas[index]),
                        ),
                      ),
              ),
            ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}