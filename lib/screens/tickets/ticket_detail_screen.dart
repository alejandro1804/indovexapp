import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';
import '../../widgets/adjuntos_section.dart';
import '../../widgets/repuestos_ticket_section.dart';
import '../../services/ticket_detalle_pdf_service.dart';

class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _historial = [];
  List<Map<String, dynamic>> _tecnicos = [];
  String _nombreCreadoPor = '';
  String _nombreTecnico = '';
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargarTicket(); }

  Future<void> _cargarTicket() async {
    setState(() => _cargando = true);
    try {
      final ticket = await _supabase
          .from('tickets')
          .select('*, maquinas(nombre, codigo, sector_id, sectores(nombre))')
          .eq('id', widget.ticketId)
          .single();

      final idsABuscar = <String>[];
      if (ticket['creado_por'] != null) idsABuscar.add(ticket['creado_por']);
      if (ticket['tecnico_id'] != null) idsABuscar.add(ticket['tecnico_id']);

      String nombreCreadoPor = '';
      String nombreTecnico = '';

      if (idsABuscar.isNotEmpty) {
        final usuariosData = await _supabase
            .from('usuarios')
            .select('id, nombre')
            .inFilter('id', idsABuscar);
        for (final u in usuariosData as List) {
          if (u['id'] == ticket['creado_por']) nombreCreadoPor = u['nombre'];
          if (u['id'] == ticket['tecnico_id']) nombreTecnico = u['nombre'];
        }
      }

      final historialRaw = await _supabase
          .from('ticket_historial')
          .select('*, usuarios(nombre)')
          .eq('ticket_id', widget.ticketId)
          .order('fecha', ascending: false);

      final tecnicosRaw = await _supabase
          .from('usuarios')
          .select('id, nombre, roles(nombre)')
          .eq('empresa_id', context.read<AuthProvider>().usuario?.empresaId ?? '')
          .eq('estado', 'activo');

      setState(() {
        _ticket = Map<String, dynamic>.from(ticket);
        _nombreCreadoPor = nombreCreadoPor;
        _nombreTecnico = nombreTecnico;
        _historial = List<Map<String, dynamic>>.from(historialRaw);
        _tecnicos = (tecnicosRaw as List)
            .where((u) => (u['roles'] as Map?)?['nombre'] == 'tecnico')
            .map((u) => Map<String, dynamic>.from(u))
            .toList();
      });
    } catch (e) {
      _mostrarError('Error al cargar ticket: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarEstado(String nuevoEstado, {String? comentario, String? tecnicoId}) async {
    try {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;

      final estadoAnterior = _ticket!['estado'] as String;
      final updateData = <String, dynamic>{'estado': nuevoEstado};
      if (tecnicoId != null) updateData['tecnico_id'] = tecnicoId;
      if (nuevoEstado == 'cerrado') {
        updateData['fecha_cierre'] = DateTime.now().toUtc().toIso8601String();
      }

      await _supabase.from('tickets').update(updateData).eq('id', widget.ticketId);

      await _supabase.from('ticket_historial').insert({
        'ticket_id': widget.ticketId,
        'usuario_id': usuario.id,
        'estado_anterior': estadoAnterior,
        'estado_nuevo': nuevoEstado,
        'comentario': comentario,
      });

      await _enviarNotificacion(nuevoEstado, tecnicoId, usuario, comentario);
      await _cargarTicket();
      _mostrarExito('Estado actualizado correctamente');
    } catch (e) {
      _mostrarError('Error al cambiar estado: $e');
    }
  }

  Future<void> _enviarNotificacion(String nuevoEstado, String? tecnicoId, usuario, String? comentario) async {
    final numero = _ticket!['numero'];
    String mensaje = '';
    String? paraUsuarioId;

    switch (nuevoEstado) {
      case 'asignado':
        mensaje = 'Ticket $numero te fue asignado por ${usuario.nombre}';
        paraUsuarioId = tecnicoId;
        break;
      case 'en_proceso':
        mensaje = 'Ticket $numero está en proceso';
        paraUsuarioId = _ticket!['creado_por'];
        break;
      case 'pausado':
        mensaje = 'Ticket $numero fue pausado${comentario != null ? ': $comentario' : ''}';
        paraUsuarioId = _ticket!['creado_por'];
        break;
      case 'resuelto':
        mensaje = 'Ticket $numero fue resuelto por ${usuario.nombre}';
        paraUsuarioId = _ticket!['creado_por'];
        final maquina = _ticket!['maquinas'] as Map?;
        if (maquina != null) {
          final encargados = await _supabase
              .from('usuario_sector')
              .select('usuario_id')
              .eq('sector_id', maquina['sector_id']);
          for (final enc in encargados as List) {
            if (enc['usuario_id'] != usuario.id) {
              await _supabase.from('notificaciones').insert({
                'tipo': 'ticket_resuelto',
                'mensaje': mensaje,
                'ticket_id': widget.ticketId,
                'para_usuario_id': enc['usuario_id'],
                'de_usuario_id': usuario.id,
              });
            }
          }
        }
        break;
      case 'cerrado':
        mensaje = 'Ticket $numero fue cerrado';
        paraUsuarioId = _ticket!['creado_por'];
        break;
      case 'rechazado':
        mensaje = 'Ticket $numero fue rechazado${comentario != null ? ': $comentario' : ''}';
        paraUsuarioId = _ticket!['creado_por'];
        break;
      case 'abierto':
        mensaje = 'Ticket $numero fue reabierto';
        paraUsuarioId = _ticket!['tecnico_id'];
        break;
    }

    if (paraUsuarioId != null && paraUsuarioId != usuario.id) {
      await _supabase.from('notificaciones').insert({
        'tipo': 'ticket_$nuevoEstado',
        'mensaje': mensaje,
        'ticket_id': widget.ticketId,
        'para_usuario_id': paraUsuarioId,
        'de_usuario_id': usuario.id,
      });
    }
  }

  Future<void> _mostrarDialogoAccion(String titulo, String accion, String nuevoEstado,
      {bool comentarioObligatorio = false, bool seleccionarTecnico = false}) async {
    final comentarioController = TextEditingController();
    String? tecnicoSeleccionado = _tecnicos.isNotEmpty ? _tecnicos.first['id'] : null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(titulo),
          content: SizedBox(
            width: Responsive.isDesktop(context) ? 420 : double.maxFinite,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (seleccionarTecnico && _tecnicos.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: tecnicoSeleccionado,
                  decoration: const InputDecoration(labelText: 'Técnico *', border: OutlineInputBorder()),
                  items: _tecnicos.map((t) => DropdownMenuItem(value: t['id'] as String, child: Text(t['nombre'] as String))).toList(),
                  onChanged: (v) => setDialogState(() => tecnicoSeleccionado = v),
                ),
                const SizedBox(height: 12),
              ],
              if (seleccionarTecnico && _tecnicos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                  child: const Text('No hay técnicos disponibles. Primero creá un usuario con rol técnico.', style: TextStyle(color: Colors.orange)),
                ),
              TextField(
                controller: comentarioController,
                decoration: InputDecoration(
                  labelText: comentarioObligatorio ? 'Comentario *' : 'Comentario (opcional)',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (comentarioObligatorio && comentarioController.text.trim().isEmpty) return;
                if (seleccionarTecnico && _tecnicos.isEmpty) return;
                Navigator.pop(context);
                await _cambiarEstado(
                  nuevoEstado,
                  comentario: comentarioController.text.trim().isEmpty ? null : comentarioController.text.trim(),
                  tecnicoId: seleccionarTecnico ? tecnicoSeleccionado : null,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
              child: Text(accion),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportarPdf() async {
    if (_ticket == null) return;
    try {
      final usuario = context.read<AuthProvider>().usuario;
      String nombreEmpresa = '';
      if (usuario != null) {
        final empresa = await _supabase
            .from('empresas')
            .select('nombre')
            .eq('id', usuario.empresaId)
            .single();
        nombreEmpresa = empresa['nombre'] ?? '';
      }
      await TicketDetallePdfService.generarYCompartir(
        ticket: _ticket!,
        historial: _historial,
        nombreEmpresa: nombreEmpresa,
        nombreCreadoPor: _nombreCreadoPor,
        nombreTecnico: _nombreTecnico,
      );
    } catch (e) {
      _mostrarError('Error al exportar PDF: $e');
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'abierto': return Colors.blue;
      case 'asignado': return Colors.orange;
      case 'en_proceso': return Colors.purple;
      case 'pausado': return Colors.amber[700]!;
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
      case 'pausado': return 'Pausado';
      case 'resuelto': return 'Resuelto';
      case 'cerrado': return 'Cerrado';
      case 'rechazado': return 'Rechazado';
      default: return estado;
    }
  }

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'preventivo': return Colors.green;
      case 'correctivo': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _colorPrioridad(String p) {
    switch (p) {
      case 'baja': return Colors.green;
      case 'media': return Colors.orange;
      case 'alta': return Colors.deepOrange;
      case 'critica': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _formatoAuditoria(DateTime? fechaUtc) {
    if (fechaUtc == null) return '-';
    final local = fechaUtc.toLocal();
    final f = '${local.year}-${_dos(local.month)}-${_dos(local.day)}';
    final h = '${_dos(local.hour)}:${_dos(local.minute)}:${_dos(local.second)}';
    final offset = local.timeZoneOffset;
    final signo = offset.isNegative ? '-' : '+';
    final horasOffset = offset.inHours.abs();
    return '$f $h (UTC$signo$horasOffset)';
  }

  String _dos(int n) => n.toString().padLeft(2, '0');

  void _mostrarExito(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)); }
  void _mostrarError(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating)); }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_ticket == null) return const Scaffold(body: Center(child: Text('Ticket no encontrado')));

    final usuario = context.read<AuthProvider>().usuario;
    final estado = _ticket!['estado'] as String;
    final tipo = _ticket!['tipo'] as String? ?? 'correctivo';
    final prioridad = _ticket!['prioridad'] as String? ?? 'media';
    final maquina = _ticket!['maquinas'] as Map<String, dynamic>?;
    final fecha = DateTime.tryParse(_ticket!['created_at'] ?? '');
    final fechaCierre = _ticket!['fecha_cierre'] != null ? DateTime.tryParse(_ticket!['fecha_cierre']) : null;
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_ticket!['numero'] ?? 'Ticket'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          if (usuario?.tienePermiso('exportar_pdf_ticket') == true)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Exportar PDF',
              onPressed: _exportarPdf,
            ),
        ],
      ),
      body: ListView(
        padding: padding,
        children: [
          // Estado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _colorEstado(estado).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _colorEstado(estado).withOpacity(0.3)),
            ),
            child: Row(children: [
              Icon(Icons.circle, color: _colorEstado(estado), size: 12),
              const SizedBox(width: 8),
              Text(_labelEstado(estado), style: TextStyle(color: _colorEstado(estado), fontWeight: FontWeight.w600, fontSize: 16)),
            ]),
          ),
          const SizedBox(height: 8),

          // Badges tipo y prioridad
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _colorTipo(tipo).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _colorTipo(tipo).withOpacity(0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  tipo == 'preventivo' ? Icons.event_available_outlined : Icons.build_outlined,
                  size: 13,
                  color: _colorTipo(tipo),
                ),
                const SizedBox(width: 4),
                Text(
                  tipo == 'preventivo' ? 'Preventivo' : 'Correctivo',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _colorTipo(tipo)),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _colorPrioridad(prioridad).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _colorPrioridad(prioridad).withOpacity(0.4)),
              ),
              child: Text(
                prioridad[0].toUpperCase() + prioridad.substring(1),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _colorPrioridad(prioridad)),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Info
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Información', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(),
                _infoRow('Máquina', maquina?['nombre'] ?? '-'),
                _infoRow('Código', maquina?['codigo'] ?? '-'),
                _infoRow('Ubicacion', (maquina?['sectores'] as Map?)?['nombre'] ?? '-'),
                _infoRow('Creado por', _nombreCreadoPor.isNotEmpty ? _nombreCreadoPor : '-'),
                if (_nombreTecnico.isNotEmpty) _infoRow('Técnico', _nombreTecnico),
                if (fecha != null) _infoRow('Fecha', _formatoAuditoria(fecha)),
                if (fechaCierre != null) _infoRow('Cierre', _formatoAuditoria(fechaCierre)),
                const SizedBox(height: 8),
                const Text('Descripción', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text(_ticket!['descripcion_desperfecto'] ?? '', style: const TextStyle(fontSize: 15)),
                if (_ticket!['observacion_tecnico'] != null) ...[
                  const SizedBox(height: 12),
                  const Text('Observación del técnico', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(_ticket!['observacion_tecnico'], style: const TextStyle(fontSize: 15)),
                ],
                if (_ticket!['observacion_encargado'] != null) ...[
                  const SizedBox(height: 12),
                  const Text('Observación del encargado', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(_ticket!['observacion_encargado'], style: const TextStyle(fontSize: 15)),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Acciones
          _buildAcciones(usuario, estado),
          const SizedBox(height: 16),

          // Repuestos utilizados
          if (_ticket!['maquina_id'] != null)
            RepuestosTicketSection(
              ticketId: widget.ticketId,
              maquinaId: _ticket!['maquina_id'],
              editable: estado != 'cerrado' && estado != 'rechazado',
            ),
          const SizedBox(height: 16),

          // Historial
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Historial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(),
                if (_historial.isEmpty)
                  const Text('Sin historial', style: TextStyle(color: Colors.grey))
                else
                  ...(_historial.map((h) {
                    final fechaH = DateTime.tryParse(h['fecha'] ?? '');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(top: 6, right: 8),
                          decoration: const BoxDecoration(color: Color(0xFF1F4E79), shape: BoxShape.circle),
                        ),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            '${h['estado_anterior'] != null ? '${_labelEstado(h['estado_anterior'])} → ' : ''}${_labelEstado(h['estado_nuevo'])}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (h['comentario'] != null)
                            Text(h['comentario'], style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text(
                            '${(h['usuarios'] as Map?)?['nombre'] ?? ''} — ${_formatoAuditoria(fechaH)}',
                            style: TextStyle(color: Colors.grey[400], fontSize: 11),
                          ),
                        ])),
                      ]),
                    );
                  })),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Adjuntos
          AdjuntosSection(
            entidadTipo: 'ticket',
            entidadId: widget.ticketId,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAcciones(usuario, String estado) {
    if (usuario == null) return const SizedBox.shrink();
    if (estado == 'cerrado' || estado == 'rechazado') return const SizedBox.shrink();

    final esAdminOEncargado = usuario.esAdmin || usuario.esEncargado;
    final esTecnico = usuario.esTecnico;
    final botones = <Widget>[];

    if (esAdminOEncargado) {
      if (estado == 'abierto') {
        botones.add(_botonAccion(
          'Asignar técnico', Icons.assignment_ind_outlined, Colors.orange,
          () => _mostrarDialogoAccion('Asignar técnico', 'Asignar', 'asignado',
              seleccionarTecnico: true),
        ));
        botones.add(_botonAccion(
          'Rechazar', Icons.cancel_outlined, Colors.red,
          () => _mostrarDialogoAccion('Rechazar ticket', 'Rechazar', 'rechazado',
              comentarioObligatorio: true),
        ));
      }
      if (estado == 'resuelto') {
        botones.add(_botonAccion(
          'Cerrar ticket', Icons.lock_outline, Colors.grey,
          () => _mostrarDialogoAccion('Cerrar ticket', 'Cerrar', 'cerrado'),
        ));
        botones.add(_botonAccion(
          'Reabrir', Icons.restart_alt, Colors.blue,
          () => _mostrarDialogoAccion('Reabrir ticket', 'Reabrir', 'abierto',
              comentarioObligatorio: true),
        ));
      }
    }

    if (esTecnico) {
      if (estado == 'asignado') {
        botones.add(_botonAccion(
          'Iniciar trabajo', Icons.build_outlined, Colors.purple,
          () => _mostrarDialogoAccion('Iniciar trabajo', 'Iniciar', 'en_proceso'),
        ));
      }
      if (estado == 'en_proceso') {
        botones.add(_botonAccion(
          'Pausar', Icons.pause_circle_outline, Colors.amber[700]!,
          () => _mostrarDialogoAccion('Pausar trabajo', 'Pausar', 'pausado',
              comentarioObligatorio: true),
        ));
        botones.add(_botonAccion(
          'Marcar resuelto', Icons.check_circle_outline, Colors.green,
          () => _mostrarDialogoAccion('Marcar como resuelto', 'Resolver', 'resuelto',
              comentarioObligatorio: true),
        ));
      }
      if (estado == 'pausado') {
        botones.add(_botonAccion(
          'Reanudar', Icons.play_circle_outline, Colors.purple,
          () => _mostrarDialogoAccion('Reanudar trabajo', 'Reanudar', 'en_proceso'),
        ));
        botones.add(_botonAccion(
          'Marcar resuelto', Icons.check_circle_outline, Colors.green,
          () => _mostrarDialogoAccion('Marcar como resuelto', 'Resolver', 'resuelto',
              comentarioObligatorio: true),
        ));
      }
    }

    if (botones.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          Wrap(spacing: 8, runSpacing: 8, children: botones),
        ]),
      ),
    );
  }

  Widget _botonAccion(String label, IconData icono, Color color, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icono, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
    );
  }
}