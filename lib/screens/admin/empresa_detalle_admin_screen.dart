import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmpresaDetalleAdminScreen extends StatelessWidget {
  final String empresaId;
  final String empresaNombre;

  const EmpresaDetalleAdminScreen({
    super.key,
    required this.empresaId,
    required this.empresaNombre,
  });

  @override
  Widget build(BuildContext context) {
    // DefaultTabController provee el controller a TabBar y TabBarView
    // automáticamente, evitando el error "No TabController for TabBar".
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1F4E79),
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(empresaNombre,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const Text('Vista de soporte — solo lectura',
                  style: TextStyle(fontSize: 10, color: Colors.white60)),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.confirmation_number_outlined, size: 20), text: 'Tickets'),
              Tab(icon: Icon(Icons.precision_manufacturing_outlined, size: 20), text: 'Activos'),
              Tab(icon: Icon(Icons.inventory_2_outlined, size: 20), text: 'Repuestos'),
              Tab(icon: Icon(Icons.people_outline, size: 20), text: 'Usuarios'),
              Tab(icon: Icon(Icons.storage_outlined, size: 20), text: 'Storage'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _TabTickets(empresaId: empresaId),
            _TabMaquinas(empresaId: empresaId),
            _TabRepuestos(empresaId: empresaId),
            _TabUsuarios(empresaId: empresaId),
            _TabAlmacenamiento(empresaId: empresaId),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB TICKETS
// ─────────────────────────────────────────────
class _TabTickets extends StatefulWidget {
  final String empresaId;
  const _TabTickets({required this.empresaId});

  @override
  State<_TabTickets> createState() => _TabTicketsState();
}

class _TabTicketsState extends State<_TabTickets> with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tickets = [];
  bool _cargando = true;
  String _filtro = 'todos';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final result = await _supabase
          .rpc('admin_tickets_empresa', params: {'p_empresa_id': widget.empresaId});
      if (!mounted) return;
      setState(() => _tickets = List<Map<String, dynamic>>.from(result));
    } catch (e) {
      _mostrarError('Error al cargar tickets: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_filtro == 'todos') return _tickets;
    return _tickets.where((t) => t['estado'] == _filtro).toList();
  }

  Color _colorEstado(String e) {
    switch (e) {
      case 'abierto': return Colors.blue;
      case 'asignado': return Colors.orange;
      case 'en_proceso': return Colors.purple;
      case 'resuelto': return Colors.green;
      case 'cerrado': return Colors.grey;
      case 'rechazado': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _labelEstado(String e) {
    switch (e) {
      case 'abierto': return 'Abierto';
      case 'asignado': return 'Asignado';
      case 'en_proceso': return 'En proceso';
      case 'resuelto': return 'Resuelto';
      case 'cerrado': return 'Cerrado';
      case 'rechazado': return 'Rechazado';
      default: return e;
    }
  }

  String _fechaCorta(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final filtrados = _filtrados;
    final estados = ['todos', 'abierto', 'asignado', 'en_proceso', 'resuelto', 'cerrado'];
    final labels = ['Todos', 'Abiertos', 'Asignados', 'En proceso', 'Resueltos', 'Cerrados'];

    return Column(
      children: [
        _bannerSoloLectura(),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(estados.length, (i) {
                final sel = _filtro == estados[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(labels[i], style: const TextStyle(fontSize: 11)),
                    selected: sel,
                    onSelected: (_) => setState(() => _filtro = estados[i]),
                    selectedColor: const Color(0xFF1F4E79),
                    labelStyle: TextStyle(color: sel ? Colors.white : Colors.black87),
                  ),
                );
              }),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          color: Colors.grey[100],
          child: Text('${filtrados.length} ticket${filtrados.length != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ),
        Expanded(
          child: filtrados.isEmpty
              ? _vacio(Icons.confirmation_number_outlined, 'No hay tickets')
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtrados.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final t = filtrados[i];
                      final estado = t['estado'] as String? ?? '';
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: _colorEstado(estado).withValues(alpha: 0.3)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(t['numero'] ?? '',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(t['maquina_nombre'] ?? 'Sin activo',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _colorEstado(estado).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_labelEstado(estado),
                                    style: TextStyle(fontSize: 10, color: _colorEstado(estado), fontWeight: FontWeight.w600)),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Text(t['descripcion_desperfecto'] ?? '',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.calendar_today_outlined, size: 11, color: Colors.grey[400]),
                              const SizedBox(width: 3),
                              Text(_fechaCorta(t['created_at']),
                                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                              if ((t['tecnico_nombre'] as String?)?.isNotEmpty == true) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.engineering_outlined, size: 11, color: Colors.grey[400]),
                                const SizedBox(width: 3),
                                Text(t['tecnico_nombre'],
                                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                              ],
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// TAB ACTIVOS
// ─────────────────────────────────────────────
class _TabMaquinas extends StatefulWidget {
  final String empresaId;
  const _TabMaquinas({required this.empresaId});

  @override
  State<_TabMaquinas> createState() => _TabMaquinasState();
}

class _TabMaquinasState extends State<_TabMaquinas> with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _maquinas = [];
  Map<String, String> _sectores = {};
  bool _cargando = true;
  String _filtro = 'todos';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final maq = await _supabase
          .rpc('admin_maquinas_empresa', params: {'p_empresa_id': widget.empresaId});
      final sec = await _supabase
          .rpc('admin_sectores_empresa', params: {'p_empresa_id': widget.empresaId});
      if (!mounted) return;
      setState(() {
        _maquinas = List<Map<String, dynamic>>.from(maq);
        _sectores = {
          for (final s in sec as List) s['id'].toString(): s['nombre'].toString()
        };
      });
    } catch (e) {
      _mostrarError('Error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  List<Map<String, dynamic>> get _filtradas {
    if (_filtro == 'todos') return _maquinas;
    return _maquinas.where((m) => m['estado'] == _filtro).toList();
  }

  Color _colorEstado(String e) {
    switch (e) {
      case 'operativa': return Colors.green;
      case 'en_mantenimiento': return Colors.orange;
      case 'fuera_de_servicio': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _labelEstado(String e) {
    switch (e) {
      case 'operativa': return 'Operativa';
      case 'en_mantenimiento': return 'En mant.';
      case 'fuera_de_servicio': return 'Fuera serv.';
      default: return e;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final filtradas = _filtradas;

    return Column(
      children: [
        _bannerSoloLectura(),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final entry in {
                'todos': 'Todos',
                'operativa': 'Operativas',
                'en_mantenimiento': 'En mant.',
                'fuera_de_servicio': 'Fuera serv.',
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value, style: const TextStyle(fontSize: 11)),
                    selected: _filtro == entry.key,
                    onSelected: (_) => setState(() => _filtro = entry.key),
                    selectedColor: const Color(0xFF1F4E79),
                    labelStyle: TextStyle(
                        color: _filtro == entry.key ? Colors.white : Colors.black87),
                  ),
                ),
            ]),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          color: Colors.grey[100],
          child: Text('${filtradas.length} activo${filtradas.length != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ),
        Expanded(
          child: filtradas.isEmpty
              ? _vacio(Icons.precision_manufacturing_outlined, 'No hay activos')
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtradas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final m = filtradas[i];
                      final estado = m['estado'] as String? ?? '';
                      final color = _colorEstado(estado);
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: color.withValues(alpha: 0.1),
                              child: Icon(Icons.precision_manufacturing_outlined, color: color, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m['nombre'] ?? '',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis),
                                Text('Código: ${m['codigo'] ?? ''}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                Text(_sectores[m['sector_id']] ?? 'Sin sector',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(_labelEstado(estado),
                                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// TAB REPUESTOS
// ─────────────────────────────────────────────
class _TabRepuestos extends StatefulWidget {
  final String empresaId;
  const _TabRepuestos({required this.empresaId});

  @override
  State<_TabRepuestos> createState() => _TabRepuestosState();
}

class _TabRepuestosState extends State<_TabRepuestos> with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _repuestos = [];
  Map<String, String> _categorias = {};
  bool _cargando = true;
  final _busquedaController = TextEditingController();
  String _textoBusqueda = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final rep = await _supabase
          .rpc('admin_repuestos_empresa', params: {'p_empresa_id': widget.empresaId});
      final cat = await _supabase
          .rpc('admin_categorias_empresa', params: {'p_empresa_id': widget.empresaId});
      if (!mounted) return;
      setState(() {
        _repuestos = List<Map<String, dynamic>>.from(rep);
        _categorias = {
          for (final c in cat as List) c['id'].toString(): c['nombre'].toString()
        };
      });
    } catch (e) {
      _mostrarError('Error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_textoBusqueda.isEmpty) return _repuestos;
    final q = _textoBusqueda.toLowerCase();
    return _repuestos.where((r) =>
        (r['descripcion'] as String? ?? '').toLowerCase().contains(q) ||
        (r['codigo'] as String? ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final filtrados = _filtrados;
    final stockBajo = _repuestos.where((r) =>
        (r['stock_actual'] as int? ?? 0) <= (r['stock_minimo'] as int? ?? 0)).length;

    return Column(
      children: [
        _bannerSoloLectura(),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _busquedaController,
            decoration: InputDecoration(
              hintText: 'Buscar repuesto...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _textoBusqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _busquedaController.clear();
                        setState(() => _textoBusqueda = '');
                      })
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _textoBusqueda = v),
          ),
        ),
        if (stockBajo > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.orange[50],
            child: Row(children: [
              const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 14),
              const SizedBox(width: 6),
              Text('$stockBajo repuesto${stockBajo != 1 ? 's' : ''} con stock bajo',
                  style: const TextStyle(fontSize: 11, color: Colors.orange)),
            ]),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          color: Colors.grey[100],
          child: Text('${filtrados.length} repuesto${filtrados.length != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ),
        Expanded(
          child: filtrados.isEmpty
              ? _vacio(Icons.inventory_2_outlined, 'No hay repuestos')
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtrados.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final r = filtrados[i];
                      final stockActual = r['stock_actual'] as int? ?? 0;
                      final stockMinimo = r['stock_minimo'] as int? ?? 0;
                      final bajo = stockActual <= stockMinimo;
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: bajo
                              ? const BorderSide(color: Colors.orange, width: 1.5)
                              : BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: bajo
                                  ? Colors.orange.withValues(alpha: 0.1)
                                  : const Color(0xFF1F4E79).withValues(alpha: 0.1),
                              child: Icon(
                                bajo ? Icons.warning_amber_outlined : Icons.inventory_2_outlined,
                                color: bajo ? Colors.orange : const Color(0xFF1F4E79),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(r['descripcion'] ?? '',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                Text('Código: ${r['codigo'] ?? ''}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                Text(_categorias[r['categoria_id']] ?? 'Sin categoría',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('$stockActual',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: bajo ? Colors.orange : const Color(0xFF1F4E79))),
                              Text(r['unidad_medida'] ?? 'unidad',
                                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                              if (bajo)
                                const Text('Stock bajo',
                                    style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.w600)),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// TAB USUARIOS
// ─────────────────────────────────────────────
class _TabUsuarios extends StatefulWidget {
  final String empresaId;
  const _TabUsuarios({required this.empresaId});

  @override
  State<_TabUsuarios> createState() => _TabUsuariosState();
}

class _TabUsuariosState extends State<_TabUsuarios> with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _usuarios = [];
  bool _cargando = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final data = await _supabase
          .rpc('admin_usuarios_empresa', params: {'p_empresa_id': widget.empresaId});
      if (!mounted) return;
      setState(() => _usuarios = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      _mostrarError('Error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        _bannerSoloLectura(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          color: Colors.grey[100],
          child: Text('${_usuarios.length} usuario${_usuarios.length != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ),
        Expanded(
          child: _usuarios.isEmpty
              ? _vacio(Icons.people_outline, 'No hay usuarios')
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _usuarios.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final u = _usuarios[i];
                      final rol = u['rol_nombre'] ?? 'Sin rol';
                      final estado = (u['estado'] as String? ?? '').toLowerCase();
                      final activo = estado == 'activo';
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF1F4E79).withValues(alpha: 0.1),
                              child: Text(
                                (u['nombre'] as String? ?? '?')[0].toUpperCase(),
                                style: const TextStyle(
                                    color: Color(0xFF1F4E79), fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(u['nombre'] ?? '',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                Text(u['email'] ?? '',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                Text(rol,
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: activo
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                u['estado'] ?? '—',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: activo ? Colors.green : Colors.grey,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// TAB ALMACENAMIENTO
// ─────────────────────────────────────────────
// Usa el mismo RPC que el listado de empresas (uso_storage_empresa),
// de modo que el uso y el porcentaje mostrados acá coinciden exactamente
// con los del listado. La cuota sale de empresas.storage_mb_limit.

class _TabAlmacenamiento extends StatefulWidget {
  final String empresaId;
  const _TabAlmacenamiento({required this.empresaId});

  @override
  State<_TabAlmacenamiento> createState() => _TabAlmacenamientoState();
}

class _TabAlmacenamientoState extends State<_TabAlmacenamiento>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _datos;
  bool _cargando = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() { _cargando = true; _error = null; });
    try {
      final data = await _supabase.rpc('uso_storage_empresa',
          params: {'p_empresa_id': widget.empresaId});
      if (!mounted) return;
      setState(() => _datos = Map<String, dynamic>.from(data));
    } catch (e) {
      if (mounted) setState(() => _error = 'Error al cargar storage: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _formatMb(num mb) {
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(2)} GB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  IconData _iconoCategoria(String categoria) {
    switch (categoria) {
      case 'maquina': return Icons.precision_manufacturing_outlined;
      case 'repuesto': return Icons.inventory_2_outlined;
      case 'ticket': return Icons.confirmation_number_outlined;
      case 'usuario': return Icons.person_outline;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  String _labelCategoria(String categoria) {
    switch (categoria) {
      case 'maquina': return 'Activos';
      case 'repuesto': return 'Repuestos';
      case 'ticket': return 'Tickets';
      case 'usuario': return 'Usuarios (avatares)';
      default: return categoria;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_cargando) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 12),
            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
          ]),
        ),
      );
    }

    final datos = _datos ?? {};
    final usadoMb = (datos['usado_mb'] as num? ?? 0).toDouble();
    final limiteMb = (datos['limite_mb'] as num? ?? 0).toDouble();
    final porcentaje = (datos['porcentaje'] as num? ?? 0).toDouble();
    final desglose = (datos['desglose'] as Map?)?.cast<String, dynamic>() ?? {};

    final progreso = (porcentaje / 100).clamp(0.0, 1.0);
    final colorBarra = porcentaje >= 90
        ? Colors.red
        : porcentaje >= 70
            ? Colors.orange
            : const Color(0xFF1F4E79);

    // Ordenar el desglose de mayor a menor uso.
    final categorias = desglose.entries.toList()
      ..sort((a, b) =>
          (b.value as num? ?? 0).compareTo(a.value as num? ?? 0));

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _bannerSoloLectura(),
          const SizedBox(height: 16),

          // ── Resumen + barra de cuota ──────────────────────────────────
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                                Icon(Icons.storage_outlined, color: colorBarra, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text('Uso de almacenamiento',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ]),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    color: colorBarra,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${_formatMb(usadoMb)} de ${_formatMb(limiteMb)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${porcentaje.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12, color: colorBarra, fontWeight: FontWeight.bold)),
                  ],
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // ── Desglose por categoría ──────────────────────────────────────
          Text('Desglose por tipo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700])),
          const SizedBox(height: 8),

          if (categorias.isEmpty || usadoMb == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Sin archivos en Storage',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ),
            )
          else
            ...categorias.map((entry) {
              final categoria = entry.key;
              final mb = (entry.value as num? ?? 0).toDouble();
              final pctCategoria = usadoMb == 0 ? 0.0 : mb / usadoMb;

              return Card(
                elevation: 0,
                color: Colors.grey[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1F4E79).withValues(alpha: 0.1),
                      child: Icon(_iconoCategoria(categoria),
                          color: const Color(0xFF1F4E79), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_labelCategoria(categoria),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_formatMb(mb),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('${(pctCategoria * 100).toStringAsFixed(0)}% del total',
                          style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ]),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widgets compartidos
// ─────────────────────────────────────────────
Widget _bannerSoloLectura() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    color: const Color(0xFFFFF8E1),
    child: Row(children: [
      const Icon(Icons.visibility_outlined, size: 13, color: Color(0xFF8D6E00)),
      const SizedBox(width: 6),
      const Text('Solo lectura — modo soporte',
          style: TextStyle(fontSize: 11, color: Color(0xFF8D6E00), fontWeight: FontWeight.w500)),
    ]),
  );
}

Widget _vacio(IconData icono, String texto) {
  return Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icono, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text(texto, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
    ]),
  );
}