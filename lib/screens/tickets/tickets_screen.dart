import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';
import '../../services/tickets_pdf_service.dart';
import 'ticket_nuevo_screen.dart';
import 'ticket_detail_screen.dart';

class TicketsScreen extends StatefulWidget {
  /// Precarga el filtro de sector. Se usa al entrar desde SectoresScreen;
  /// como tab del menú llega null y la pantalla arranca sin filtrar.
  final String? sectorInicial;

  const TicketsScreen({super.key, this.sectorInicial});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tickets = [];
  bool _cargando = true;
  bool _exportando = false;
  String _filtroEstado = 'todos';
  String _filtroTipo = 'todos';
  String _filtroPrioridad = 'todos';
  String _filtroSector = 'todos';
  final _busquedaController = TextEditingController();
  String _textoBusqueda = '';

  @override
  void initState() {
    super.initState();
    if (widget.sectorInicial != null) _filtroSector = widget.sectorInicial!;
    _cargarTickets();
  }

  @override
  void dispose() { _busquedaController.dispose(); super.dispose(); }

  Future<void> _cargarTickets() async {
    setState(() => _cargando = true);
    try {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;

      List<Map<String, dynamic>> tickets;

      if (usuario.esTecnico) {
        final result = await _supabase
            .from('tickets')
            .select('*, maquinas(nombre, codigo, sector_id, sectores(nombre))')
            .eq('tecnico_id', usuario.id)
            .order('created_at', ascending: false);
        tickets = List<Map<String, dynamic>>.from(result);
      } else if (usuario.restringePorSector) {
        // Roles restringidos por ubicación ven solo los tickets de los
        // activos de sus ubicaciones asignadas (usuario_sector).
        final sectoresData = await _supabase
            .from('usuario_sector')
            .select('sector_id')
            .eq('usuario_id', usuario.id);
        final sectorIds = (sectoresData as List).map((e) => e['sector_id'] as String).toList();
        if (sectorIds.isEmpty) {
          setState(() { _tickets = []; _cargando = false; });
          return;
        }
        final result = await _supabase
            .from('tickets')
            .select('*, maquinas(nombre, codigo, sector_id, sectores(nombre))')
            .order('created_at', ascending: false);
        tickets = (result as List)
            .where((t) => sectorIds.contains((t['maquinas'] as Map?)?['sector_id']))
            .map((t) => Map<String, dynamic>.from(t))
            .toList();
      } else {
        final result = await _supabase
            .from('tickets')
            .select('*, maquinas(nombre, codigo, sector_id, sectores(nombre))')
            .order('created_at', ascending: false);
        tickets = List<Map<String, dynamic>>.from(result);
      }

      final usuariosIds = <String>{};
      for (final t in tickets) {
        if (t['creado_por'] != null) usuariosIds.add(t['creado_por']);
        if (t['tecnico_id'] != null) usuariosIds.add(t['tecnico_id']);
      }

      Map<String, String> nombresUsuarios = {};
      if (usuariosIds.isNotEmpty) {
        final usuariosData = await _supabase
            .from('usuarios')
            .select('id, nombre')
            .inFilter('id', usuariosIds.toList());
        for (final u in usuariosData as List) {
          nombresUsuarios[u['id']] = u['nombre'];
        }
      }

      for (final t in tickets) {
        t['nombre_creado_por'] = nombresUsuarios[t['creado_por']] ?? '';
        t['nombre_tecnico'] = nombresUsuarios[t['tecnico_id']] ?? '';
      }

      setState(() { _tickets = tickets; });
    } catch (e) {
      _mostrarError('Error al cargar tickets: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  List<MapEntry<String, String>> get _sectoresDisponibles {
    final mapa = <String, String>{};
    for (final t in _tickets) {
      final maquina = t['maquinas'] as Map?;
      final sectorId = maquina?['sector_id'] as String?;
      final sectorNombre = (maquina?['sectores'] as Map?)?['nombre'] as String?;
      if (sectorId != null && sectorNombre != null) {
        mapa[sectorId] = sectorNombre;
      }
    }
    final lista = mapa.entries.toList();
    lista.sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return lista;
  }

  List<Map<String, dynamic>> get _ticketsFiltrados {
    final q = _textoBusqueda.trim().toLowerCase();
    return _tickets.where((t) {
      final coincideEstado = _filtroEstado == 'todos' || t['estado'] == _filtroEstado;
      final coincideTipo = _filtroTipo == 'todos' || (t['tipo'] ?? 'correctivo') == _filtroTipo;
      final coincidePrioridad = _filtroPrioridad == 'todos' || (t['prioridad'] ?? 'media') == _filtroPrioridad;
      final maquina = t['maquinas'] as Map?;
      final sectorId = maquina?['sector_id'] as String?;
      final coincideSector = _filtroSector == 'todos' || sectorId == _filtroSector;
      bool coincideBusqueda = true;
      if (q.isNotEmpty) {
        final numero = (t['numero'] ?? '').toString().toLowerCase();
        final desc = (t['descripcion_desperfecto'] ?? '').toString().toLowerCase();
        final maqNombre = (maquina?['nombre'] ?? '').toString().toLowerCase();
        final maqCodigo = (maquina?['codigo'] ?? '').toString().toLowerCase();
        final sectorNombre = ((maquina?['sectores'] as Map?)?['nombre'] ?? '').toString().toLowerCase();
        coincideBusqueda = numero.contains(q) || desc.contains(q) || maqNombre.contains(q) || maqCodigo.contains(q) || sectorNombre.contains(q);
      }
      return coincideEstado && coincideTipo && coincidePrioridad && coincideSector && coincideBusqueda;
    }).toList();
  }

  bool get _hayFiltrosActivos =>
      _filtroEstado != 'todos' || _filtroTipo != 'todos' || _filtroPrioridad != 'todos' || _filtroSector != 'todos' || _textoBusqueda.trim().isNotEmpty;

  void _limpiarFiltros() {
    setState(() {
      _filtroEstado = 'todos';
      _filtroTipo = 'todos';
      _filtroPrioridad = 'todos';
      _filtroSector = 'todos';
      _textoBusqueda = '';
      _busquedaController.clear();
    });
  }

  bool get _puedeExportarPdf {
    final usuario = context.read<AuthProvider>().usuario;
    return usuario?.tienePermiso('exportar_pdf_tickets') ?? false;
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

      // Para el PDF ordenamos descendente por número de ticket (más nuevo primero).
      // El formato TK-000N con padding permite ordenar como texto sin parsear.
      final ticketsOrdenados =
          List<Map<String, dynamic>>.from(_ticketsFiltrados)
            ..sort((a, b) => (b['numero'] ?? '')
                .toString()
                .compareTo((a['numero'] ?? '').toString()));

      await TicketsPdfService.generarYCompartir(
        tickets: ticketsOrdenados,
        nombreEmpresa: nombreEmpresa,
        filtroEstado: _filtroEstado,
        filtroTipo: _filtroTipo,
        filtroPrioridad: _filtroPrioridad,
        filtroSector: _filtroSector,
        busqueda: _textoBusqueda,
      );
    } catch (e) {
      _mostrarError('Error al generar PDF: $e');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  String _formatoAuditoria(DateTime? fechaUtc) {
    if (fechaUtc == null) return '';
    final local = fechaUtc.toLocal();
    final f = '${local.year}-${_dos(local.month)}-${_dos(local.day)}';
    final h = '${_dos(local.hour)}:${_dos(local.minute)}:${_dos(local.second)}';
    final offset = local.timeZoneOffset;
    final signo = offset.isNegative ? '-' : '+';
    final horasOffset = offset.inHours.abs();
    return '$f $h (UTC$signo$horasOffset)';
  }

  String _dos(int n) => n.toString().padLeft(2, '0');

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'abierto':    return Colors.blue;
      case 'asignado':   return Colors.orange;
      case 'en_proceso': return Colors.purple;
      case 'pausado':    return Colors.amber[700]!;
      case 'resuelto':   return Colors.green;
      case 'cerrado':    return Colors.grey;
      case 'rechazado':  return Colors.red;
      default:           return Colors.grey;
    }
  }

  String _labelEstado(String estado) {
    switch (estado) {
      case 'abierto':    return 'Abierto';
      case 'asignado':   return 'Asignado';
      case 'en_proceso': return 'En proceso';
      case 'pausado':    return 'Pausado';
      case 'resuelto':   return 'Resuelto';
      case 'cerrado':    return 'Cerrado';
      case 'rechazado':  return 'Rechazado';
      default:           return estado;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'abierto':    return Icons.fiber_new_outlined;
      case 'asignado':   return Icons.assignment_ind_outlined;
      case 'en_proceso': return Icons.build_outlined;
      case 'pausado':    return Icons.pause_circle_outline;
      case 'resuelto':   return Icons.check_circle_outline;
      case 'cerrado':    return Icons.lock_outline;
      case 'rechazado':  return Icons.cancel_outlined;
      default:           return Icons.help_outline;
    }
  }

  Color _colorPrioridad(String p) {
    switch (p) {
      case 'baja':    return Colors.green;
      case 'media':   return Colors.orange;
      case 'alta':    return Colors.deepOrange;
      case 'critica': return Colors.red;
      default:        return Colors.grey;
    }
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
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
      initialValue: value,
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
    final usuario = context.read<AuthProvider>().usuario;
    final puedeCrear = usuario?.tienePermiso('crear_ticket') ?? false;
    final ticketsFiltrados = _ticketsFiltrados;
    final padding = Responsive.pagePadding(context);
    final titleSize = Responsive.cardTitleSize(context);
    final subtitleSize = Responsive.cardSubtitleSize(context);
    final chipSize = Responsive.chipFontSize(context);
    final sectores = _sectoresDisponibles;

    // El dropdown se puebla desde los tickets cargados: si el sector no
    // tiene ninguno, su id no estaría entre los items y el Dropdown
    // reventaría por value inexistente. Se cae a 'todos' para evitarlo.
    final filtroSectorValido = _filtroSector == 'todos' ||
        sectores.any((s) => s.key == _filtroSector);
    final valueSector = filtroSectorValido ? _filtroSector : 'todos';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets', style: TextStyle(fontSize: 18)),
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          if (_puedeExportarPdf)
            _exportando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  )
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Exportar PDF',
                    onPressed: _tickets.isEmpty ? null : _exportarPdf,
                  ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarTickets),
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
                  onChanged: (v) => setState(() => _textoBusqueda = v),
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Buscar por ticket, activo o ubicación...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    suffixIcon: _textoBusqueda.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () { _busquedaController.clear(); setState(() => _textoBusqueda = ''); },
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
                      value: _filtroEstado,
                      contexto: 'Estado',
                      icono: Icons.flag_outlined,
                      items: [
                        _item('todos', 'Todos los estados'),
                        _item('abierto', 'Abierto'),
                        _item('asignado', 'Asignado'),
                        _item('en_proceso', 'En proceso'),
                        _item('pausado', 'Pausado'),
                        _item('resuelto', 'Resuelto'),
                        _item('cerrado', 'Cerrado'),
                        _item('rechazado', 'Rechazado'),
                      ],
                      onChanged: (v) => setState(() => _filtroEstado = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDropdown(
                      value: _filtroPrioridad,
                      contexto: 'Prioridad',
                      icono: Icons.priority_high_outlined,
                      items: [
                        _item('todos', 'Toda prioridad'),
                        _item('baja', 'Baja'),
                        _item('media', 'Media'),
                        _item('alta', 'Alta'),
                        _item('critica', 'Crítica'),
                      ],
                      onChanged: (v) => setState(() => _filtroPrioridad = v),
                    ),
                  ),
                ]),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Row(children: [
                  Expanded(
                    child: _buildDropdown(
                      value: _filtroTipo,
                      contexto: 'Tipo',
                      icono: Icons.build_outlined,
                      items: [
                        _item('todos', 'Todo tipo'),
                        _item('correctivo', 'Correctivo'),
                        _item('preventivo', 'Preventivo'),
                      ],
                      onChanged: (v) => setState(() => _filtroTipo = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDropdown(
                      value: valueSector,
                      contexto: 'Ubicacion',
                      icono: Icons.apartment_outlined,
                      items: [
                        _item('todos', 'Todas las ubicaciones'),
                        ...sectores.map((s) => _item(s.key, s.value)),
                      ],
                      onChanged: (v) => setState(() => _filtroSector = v),
                    ),
                  ),
                ]),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Colors.grey[100],
                child: Row(children: [
                  Text('${ticketsFiltrados.length} ticket${ticketsFiltrados.length != 1 ? 's' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
                child: ticketsFiltrados.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.confirmation_number_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(_tickets.isEmpty ? 'No hay tickets' : 'No hay tickets con esos filtros', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        if (_tickets.isEmpty && puedeCrear) ...[
                          const SizedBox(height: 8),
                          Text('Tocá el botón + para crear uno', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                        ],
                        if (_tickets.isNotEmpty && _hayFiltrosActivos) ...[
                          const SizedBox(height: 8),
                          TextButton(onPressed: _limpiarFiltros, child: const Text('Limpiar filtros')),
                        ],
                      ]))
                    : RefreshIndicator(
                        onRefresh: _cargarTickets,
                        child: ListView.separated(
                          padding: padding,
                          itemCount: ticketsFiltrados.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final ticket = ticketsFiltrados[index];
                            final estado = ticket['estado'] as String;
                            final tipo = ticket['tipo'] as String? ?? 'correctivo';
                            final prioridad = ticket['prioridad'] as String? ?? 'media';
                            final maquina = ticket['maquinas'] as Map<String, dynamic>?;
                            final nombreTecnico = ticket['nombre_tecnico'] as String?;
                            final fecha = DateTime.tryParse(ticket['created_at'] ?? '');
                            final fechaStr = _formatoAuditoria(fecha);

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: _colorEstado(estado).withOpacity(0.3), width: 1),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: ticket['id'])),
                                ).then((_) => _cargarTickets()),
                                child: Padding(
                                  padding: Responsive.cardPadding(context),
                                  child: Row(children: [
                                    CircleAvatar(
                                      radius: Responsive.avatarRadius(context),
                                      backgroundColor: _colorEstado(estado).withOpacity(0.1),
                                      child: Icon(_iconoEstado(estado), color: _colorEstado(estado), size: Responsive.avatarRadius(context)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Row(children: [
                                          Text(ticket['numero'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: subtitleSize, color: Colors.grey[600])),
                                          const SizedBox(width: 6),
                                          Icon(
                                            tipo == 'preventivo' ? Icons.event_available_outlined : Icons.build_outlined,
                                            size: subtitleSize + 1,
                                            color: tipo == 'preventivo' ? Colors.green : Colors.red,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text(maquina?['nombre'] ?? 'Sin activo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: titleSize), overflow: TextOverflow.ellipsis)),
                                        ]),
                                        const SizedBox(height: 2),
                                        Text(ticket['descripcion_desperfecto'] ?? '', style: TextStyle(fontSize: subtitleSize, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(color: _colorPrioridad(prioridad).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                            child: Text(
                                              prioridad[0].toUpperCase() + prioridad.substring(1),
                                              style: TextStyle(fontSize: chipSize, color: _colorPrioridad(prioridad), fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if (nombreTecnico != null && nombreTecnico.isNotEmpty) ...[
                                            Icon(Icons.engineering_outlined, size: subtitleSize, color: Colors.grey[500]),
                                            const SizedBox(width: 3),
                                            Flexible(child: Text(nombreTecnico, style: TextStyle(fontSize: subtitleSize, color: Colors.grey[500]), overflow: TextOverflow.ellipsis)),
                                            const SizedBox(width: 8),
                                          ],
                                          Icon(Icons.calendar_today_outlined, size: subtitleSize, color: Colors.grey[400]),
                                          const SizedBox(width: 3),
                                          Expanded(child: Text(fechaStr, style: TextStyle(fontSize: subtitleSize, color: Colors.grey[400]), overflow: TextOverflow.ellipsis)),
                                        ]),
                                      ]),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(color: _colorEstado(estado).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                      child: Text(_labelEstado(estado), style: TextStyle(fontSize: chipSize, color: _colorEstado(estado), fontWeight: FontWeight.w600)),
                                    ),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ]),
      floatingActionButton: puedeCrear
          ? FloatingActionButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketNuevoScreen()))
                  .then((_) => _cargarTickets()),
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}