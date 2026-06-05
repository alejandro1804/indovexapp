import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';
import 'ticket_nuevo_screen.dart';
import 'ticket_detail_screen.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tickets = [];
  bool _cargando = true;
  String _filtroEstado = 'todos';

  @override
  void initState() { super.initState(); _cargarTickets(); }

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

      } else if (usuario.esEncargado) {
        final sectoresData = await _supabase
            .from('encargado_sector')
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

      // Enriquecer con nombres de usuarios por separado
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

      // Agregar nombres a cada ticket
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

  List<Map<String, dynamic>> get _ticketsFiltrados {
    if (_filtroEstado == 'todos') return _tickets;
    return _tickets.where((t) => t['estado'] == _filtroEstado).toList();
  }

  // Formato auditoría: convierte UTC a hora local y muestra la zona.
  // Ej: 2026-06-04 20:00:20 (UTC-3)
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
      case 'abierto': return Colors.blue;
      case 'asignado': return Colors.orange;
      case 'en_proceso': return Colors.purple;
      case 'resuelto': return Colors.green;
      case 'cerrado': return Colors.grey;
      case 'rechazado': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _labelEstado(String estado) {
    switch (estado) {
      case 'abierto': return 'Abierto';
      case 'asignado': return 'Asignado';
      case 'en_proceso': return 'En proceso';
      case 'resuelto': return 'Resuelto';
      case 'cerrado': return 'Cerrado';
      case 'rechazado': return 'Rechazado';
      default: return estado;
    }
  }

  IconData _iconoEstado(String estado) {
    switch (estado) {
      case 'abierto': return Icons.fiber_new_outlined;
      case 'asignado': return Icons.assignment_ind_outlined;
      case 'en_proceso': return Icons.build_outlined;
      case 'resuelto': return Icons.check_circle_outline;
      case 'cerrado': return Icons.lock_outline;
      case 'rechazado': return Icons.cancel_outlined;
      default: return Icons.help_outline;
    }
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthProvider>().usuario;
    final puedeCrear = usuario?.tienePermiso('crear_ticket') ?? false;
    final ticketsFiltrados = _ticketsFiltrados;
    final padding = Responsive.pagePadding(context);
    final titleSize = Responsive.cardTitleSize(context);
    final subtitleSize = Responsive.cardSubtitleSize(context);
    final chipSize = Responsive.chipFontSize(context);

    final abiertos = _tickets.where((t) => t['estado'] == 'abierto').length;
    final asignados = _tickets.where((t) => t['estado'] == 'asignado').length;
    final enProceso = _tickets.where((t) => t['estado'] == 'en_proceso').length;
    final resueltos = _tickets.where((t) => t['estado'] == 'resuelto').length;
    final cerrados = _tickets.where((t) => t['estado'] == 'cerrado').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarTickets),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _buildContadorChip('todos', 'Todos', _tickets.length, Colors.grey),
                    const SizedBox(width: 8),
                    _buildContadorChip('abierto', 'Abiertos', abiertos, Colors.blue),
                    const SizedBox(width: 8),
                    _buildContadorChip('asignado', 'Asignados', asignados, Colors.orange),
                    const SizedBox(width: 8),
                    _buildContadorChip('en_proceso', 'En proceso', enProceso, Colors.purple),
                    const SizedBox(width: 8),
                    _buildContadorChip('resuelto', 'Resueltos', resueltos, Colors.green),
                    const SizedBox(width: 8),
                    _buildContadorChip('cerrado', 'Cerrados', cerrados, Colors.grey),
                  ]),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Colors.grey[100],
                child: Text('${ticketsFiltrados.length} ticket${ticketsFiltrados.length != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ),
              Expanded(
                child: ticketsFiltrados.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.confirmation_number_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(_tickets.isEmpty ? 'No hay tickets' : 'No hay tickets con ese estado',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        if (_tickets.isEmpty && puedeCrear) ...[
                          const SizedBox(height: 8),
                          Text('Tocá el botón + para crear uno', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                        ]
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
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(maquina?['nombre'] ?? 'Sin máquina',
                                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: titleSize), overflow: TextOverflow.ellipsis)),
                                        ]),
                                        const SizedBox(height: 2),
                                        Text(ticket['descripcion_desperfecto'] ?? '',
                                            style: TextStyle(fontSize: subtitleSize, color: Colors.grey[700]),
                                            maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          if (nombreTecnico != null && nombreTecnico.isNotEmpty) ...[
                                            Icon(Icons.engineering_outlined, size: subtitleSize, color: Colors.grey[500]),
                                            const SizedBox(width: 3),
                                            Text(nombreTecnico, style: TextStyle(fontSize: subtitleSize, color: Colors.grey[500])),
                                            const SizedBox(width: 8),
                                          ],
                                          Icon(Icons.calendar_today_outlined, size: subtitleSize, color: Colors.grey[400]),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(fechaStr,
                                                style: TextStyle(fontSize: subtitleSize, color: Colors.grey[400]),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                        ]),
                                      ]),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _colorEstado(estado).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(_labelEstado(estado),
                                          style: TextStyle(fontSize: chipSize, color: _colorEstado(estado), fontWeight: FontWeight.w600)),
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

  Widget _buildContadorChip(String valor, String label, int count, Color color) {
    final seleccionado = _filtroEstado == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = valor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: seleccionado ? color.withOpacity(0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: seleccionado ? color : Colors.grey[300]!, width: seleccionado ? 1.5 : 1),
        ),
        child: Row(children: [
          Text(label, style: TextStyle(fontSize: 12, color: seleccionado ? color : Colors.grey[600],
              fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: seleccionado ? color : Colors.grey[400], borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}