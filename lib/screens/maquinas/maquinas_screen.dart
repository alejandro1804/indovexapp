import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/maquina.dart';
import '../../models/sector.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';
import '../../core/db_error_helper.dart';
import '../../services/maquinas_pdf_service.dart';
import '../../widgets/foto_principal_widget.dart';
import 'maquina_detail_screen.dart';
import 'escanear_qr_screen.dart';

class MaquinasScreen extends StatefulWidget {
  const MaquinasScreen({super.key});
  @override
  State<MaquinasScreen> createState() => _MaquinasScreenState();
}

class _MaquinasScreenState extends State<MaquinasScreen> {
  final _supabase = Supabase.instance.client;
  final _busquedaController = TextEditingController();
  List<Maquina> _maquinas = [];
  List<Sector> _sectores = [];
  bool _cargando = true;
  bool _exportando = false;
  String _filtroEstado = 'todos';
  String _filtroSector = 'todos';
  String _busqueda = '';

  @override
  void initState() { super.initState(); _cargarDatos(); }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final maquinasData = await _supabase.from('maquinas').select().order('nombre', ascending: true);
      final sectoresData = await _supabase.from('sectores').select().order('nombre', ascending: true);
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

  bool get _puedeGestionar {
    final usuario = context.read<AuthProvider>().usuario;
    return usuario?.tienePermiso('gestionar_maquinas') ?? false;
  }

  bool get _puedeExportarPdf {
    final usuario = context.read<AuthProvider>().usuario;
    return usuario?.tienePermiso('exportar_pdf_maquinas') ?? false;
  }

  List<Maquina> get _maquinasFiltradas {
    final q = _busqueda.trim().toLowerCase();
    final resultado = _maquinas.where((m) {
      if (_filtroEstado != 'todos' && m.estado != _filtroEstado) return false;
      if (_filtroSector != 'todos' && m.sectorId != _filtroSector) return false;
      if (q.isNotEmpty) {
        final enNombre = m.nombre.toLowerCase().contains(q);
        final enCodigo = m.codigo.toLowerCase().contains(q);
        if (!enNombre && !enCodigo) return false;
      }
      return true;
    }).toList();
    resultado.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return resultado;
  }

  bool get _hayFiltrosActivos =>
      _filtroEstado != 'todos' || _filtroSector != 'todos' || _busqueda.trim().isNotEmpty;

  void _limpiarFiltros() {
    setState(() {
      _filtroEstado = 'todos';
      _filtroSector = 'todos';
      _busqueda = '';
      _busquedaController.clear();
    });
  }

  String _nombreSector(String sectorId) {
    return _sectores.firstWhere(
      (s) => s.id == sectorId,
      orElse: () => Sector(id: '', empresaId: '', nombre: 'Sin sector'),
    ).nombre;
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

    Future<void> _exportarPdf() async {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;
      setState(() => _exportando = true);
      try {
        final empresa = await _supabase
            .from('empresas')
            .select('nombre')
            .eq('id', usuario.empresaId)
            .single();
        final nombreEmpresa = empresa['nombre'] as String? ?? '';
        final sectoresMap = { for (final s in _sectores) s.id: s.nombre };
        await MaquinasPdfService.generarYCompartir(
          maquinas: _maquinasFiltradas,
          nombreEmpresa: nombreEmpresa,
          sectores: sectoresMap,
          filtroEstado: _filtroEstado,
          filtroSector: _filtroSector,
          busqueda: _busqueda,
        );
      } catch (e) {
        _mostrarError('Error al generar PDF: $e');
      } finally {
        if (mounted) setState(() => _exportando = false);
      }
    }

  Future<void> _escanearQr() async {
    final maquinaId = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const EscanearQrScreen()),
    );
    if (maquinaId == null || !mounted) return;

    Maquina? maquina;
    for (final m in _maquinas) {
      if (m.id == maquinaId) {
        maquina = m;
        break;
      }
    }

    if (maquina == null) {
      try {
        final data =
            await _supabase.from('maquinas').select().eq('id', maquinaId).single();
        maquina = Maquina.fromMap(data);
      } catch (e) {
        _mostrarError('Máquina no encontrada o sin acceso');
        return;
      }
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MaquinaDetailScreen(maquina: maquina!)),
    ).then((_) => _cargarDatos());
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
                TextField(controller: nombreController, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder()), textCapitalization: TextCapitalization.words, maxLength: 100),
                const SizedBox(height: 12),
                TextField(controller: codigoController, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(labelText: 'Código *', border: OutlineInputBorder(), hintText: 'Ej: MAQ-001'), textCapitalization: TextCapitalization.characters, maxLength: 30),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: sectorSeleccionado,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  decoration: const InputDecoration(labelText: 'Sector *', border: OutlineInputBorder()),
                  items: _sectores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nombre, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setDialogState(() => sectorSeleccionado = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: estadoSeleccionado,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  decoration: const InputDecoration(labelText: 'Estado *', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'operativa', child: Text('Operativa', style: TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'en_mantenimiento', child: Text('En mantenimiento', style: TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'fuera_de_servicio', child: Text('Fuera de servicio', style: TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setDialogState(() => estadoSeleccionado = v!),
                ),
                const SizedBox(height: 12),
                TextField(controller: descripcionController, style: const TextStyle(fontSize: 14), decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()), maxLines: 2, maxLength: 500),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final nombre = normalizarTexto(nombreController.text);
                final codigo = normalizarTexto(codigoController.text);
                final descripcion = normalizarTexto(descripcionController.text);
                if (nombre.isEmpty || codigo.isEmpty) return;
                Navigator.pop(context);
                if (maquina == null) {
                  await _crearMaquina(nombre: nombre, codigo: codigo, sectorId: sectorSeleccionado, estado: estadoSeleccionado, descripcion: descripcion);
                } else {
                  await _editarMaquina(id: maquina.id, nombre: nombre, codigo: codigo, sectorId: sectorSeleccionado, estado: estadoSeleccionado, descripcion: descripcion);
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
    } catch (e) { _mostrarError(mensajeAmigableDb(e, entidad: 'máquina', campos: 'nombre o código')); }
  }

  Future<void> _editarMaquina({required String id, required String nombre, required String codigo, required String sectorId, required String estado, required String descripcion}) async {
    try {
      await _supabase.from('maquinas').update({'sector_id': sectorId, 'nombre': nombre, 'codigo': codigo, 'estado': estado, 'descripcion': descripcion.isEmpty ? null : descripcion}).eq('id', id);
      await _cargarDatos();
      _mostrarExito('Máquina actualizada correctamente');
    } catch (e) { _mostrarError(mensajeAmigableDb(e, entidad: 'máquina', campos: 'nombre o código')); }
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
    final puedeGestionar = _puedeGestionar;
    final thumbSize = avatarRadius * 2;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MaquinaDetailScreen(maquina: maquina)),
        ).then((_) => _cargarDatos()),
        child: Padding(
          padding: cardPadding,
          child: Row(
            children: [
              FotoPrincipalWidget(
                storagePath: maquina.imagenUrl,
                tipo: 'maquina',
                empresaId: maquina.empresaId,
                entidadId: maquina.id,
                size: thumbSize,
                puedeEditar: false,
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
                  if (puedeGestionar)
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

  Widget _buildDropdown({
    required String value,
    required String contexto,
    required IconData icono,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String> onChanged,
  }) {
    final activo = value != 'todos';
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      isDense: true,
      style: const TextStyle(fontSize: 12, color: Colors.black87),
      icon: const Icon(Icons.arrow_drop_down, size: 20),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(icono, size: 18, color: activo ? const Color(0xFF1F4E79) : Colors.grey[600]),
        prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: activo ? const Color(0xFF1F4E79) : Colors.grey.shade300),
        ),
      ),
      selectedItemBuilder: (context) => items.map((item) {
        final esTodos = item.value == 'todos';
        final texto = esTodos ? contexto : _labelDeItem(item);
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(texto, style: TextStyle(fontSize: 12, color: esTodos ? Colors.grey[600] : Colors.black87), overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      items: items,
      onChanged: (v) => onChanged(v ?? 'todos'),
    );
  }

  String _labelDeItem(DropdownMenuItem<String> item) {
    final child = item.child;
    if (child is Text) return child.data ?? '';
    return '';
  }

  DropdownMenuItem<String> _item(String value, String label) => DropdownMenuItem(
    value: value,
    child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
  );

  @override
  Widget build(BuildContext context) {
    final maquinasFiltradas = _maquinasFiltradas;
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Máquinas', style: TextStyle(fontSize: 18)),
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Escanear QR',
              onPressed: _escanearQr,
            ),
          if (_puedeExportarPdf)
            _exportando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  )
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Exportar PDF',
                    onPressed: _maquinas.isEmpty ? null : _exportarPdf,
                  ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: TextField(
                  controller: _busquedaController,
                  onChanged: (v) => setState(() => _busqueda = v),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o código...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    suffixIcon: _busqueda.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => setState(() { _busqueda = ''; _busquedaController.clear(); }),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  ),
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Row(children: [
                  Expanded(
                    child: _buildDropdown(
                      value: _filtroSector,
                      contexto: 'Sector',
                      icono: Icons.apartment_outlined,
                      items: [
                        _item('todos', 'Todos los sectores'),
                        ..._sectores.map((s) => _item(s.id, s.nombre)),
                      ],
                      onChanged: (v) => setState(() => _filtroSector = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDropdown(
                      value: _filtroEstado,
                      contexto: 'Estado',
                      icono: Icons.tune,
                      items: [
                        _item('todos', 'Todos los estados'),
                        _item('operativa', 'Operativas'),
                        _item('en_mantenimiento', 'En mantenimiento'),
                        _item('fuera_de_servicio', 'Fuera de servicio'),
                      ],
                      onChanged: (v) => setState(() => _filtroEstado = v),
                    ),
                  ),
                ]),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Colors.grey[100],
                child: Row(children: [
                  Text('${maquinasFiltradas.length} máquina${maquinasFiltradas.length != 1 ? 's' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const Spacer(),
                  if (_hayFiltrosActivos)
                    GestureDetector(
                      onTap: _limpiarFiltros,
                      child: Row(children: [
                        Icon(Icons.filter_alt_off_outlined, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('Limpiar filtros', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ]),
                    ),
                ]),
              ),
              Expanded(
                child: maquinasFiltradas.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.precision_manufacturing_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(_maquinas.isEmpty ? 'No hay máquinas cargadas' : 'No hay máquinas con ese filtro', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        if (_maquinas.isNotEmpty && _hayFiltrosActivos) ...[
                          const SizedBox(height: 8),
                          TextButton(onPressed: _limpiarFiltros, child: const Text('Limpiar filtros')),
                        ],
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
      floatingActionButton: _puedeGestionar
          ? FloatingActionButton(
              onPressed: () => _mostrarFormulario(),
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}