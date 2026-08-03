import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';

class TicketNuevoScreen extends StatefulWidget {
  const TicketNuevoScreen({super.key});

  @override
  State<TicketNuevoScreen> createState() => _TicketNuevoScreenState();
}

class _TicketNuevoScreenState extends State<TicketNuevoScreen> {
  final _supabase = Supabase.instance.client;
  final _descripcionController = TextEditingController();
  List<Map<String, dynamic>> _maquinas = [];
  String? _maquinaSeleccionada;
  String _tipo = 'correctivo';
  String _prioridad = 'media';
  bool _cargando = false;
  bool _cargandoMaquinas = true;

  @override
  void initState() { super.initState(); _cargarMaquinas(); }

  Future<void> _cargarMaquinas() async {
    try {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;

      List<Map<String, dynamic>> maquinas;

      // Roles restringidos por ubicación solo ven los activos de sus
      // ubicaciones asignadas (usuario_sector). El resto ve todos.
      if (usuario.restringePorSector) {
        final sectoresData = await _supabase
            .from('usuario_sector')
            .select('sector_id')
            .eq('usuario_id', usuario.id);
        final sectorIds = (sectoresData as List).map((e) => e['sector_id'] as String).toList();
        if (sectorIds.isEmpty) {
          setState(() { _cargandoMaquinas = false; });
          return;
        }
        final data = await _supabase
            .from('maquinas')
            .select('id, nombre, codigo, sectores(nombre)')
            .inFilter('sector_id', sectorIds)
            .order('nombre');
        maquinas = List<Map<String, dynamic>>.from(data);
      } else {
        final data = await _supabase
            .from('maquinas')
            .select('id, nombre, codigo, sectores(nombre)')
            .order('nombre');
        maquinas = List<Map<String, dynamic>>.from(data);
      }

      setState(() {
        _maquinas = maquinas;
        if (_maquinas.isNotEmpty) _maquinaSeleccionada = _maquinas.first['id'];
      });
    } catch (e) {
      _mostrarError('Error al cargar activos: $e');
    } finally {
      setState(() => _cargandoMaquinas = false);
    }
  }

  Future<void> _crearTicket() async {
    if (_maquinaSeleccionada == null || _descripcionController.text.trim().isEmpty) {
      _mostrarError('Completá todos los campos obligatorios');
      return;
    }

    setState(() => _cargando = true);
    try {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;

      // El número de ticket lo asigna la base (trigger trg_asignar_numero_ticket),
      // correlativo por empresa. NO se genera ni se envía desde el cliente:
      // hacerlo con un SELECT sujeto a RLS provocaba números duplicados entre
      // ubicaciones. Se lee del registro devuelto por el insert.
      final ticketData = await _supabase.from('tickets').insert({
        'empresa_id': usuario.empresaId,
        'maquina_id': _maquinaSeleccionada,
        'creado_por': usuario.id,
        'estado': 'abierto',
        'tipo': _tipo,
        'prioridad': _prioridad,
        'descripcion_desperfecto': _descripcionController.text.trim(),
      }).select().single();

      final numero = ticketData['numero'] as String? ?? '';

      await _supabase.from('ticket_historial').insert({
        'ticket_id': ticketData['id'],
        'usuario_id': usuario.id,
        'estado_anterior': null,
        'estado_nuevo': 'abierto',
        'comentario': 'Ticket creado',
      });

      // Las notificaciones a los involucrados (creador, ejecutor y roles con
      // permiso 'recibir_notificaciones_tickets') las genera el trigger
      // trg_notificar_involucrados_ticket en la base. No se generan acá para
      // no duplicarlas.

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket $numero creado correctamente'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
      );
      Navigator.pop(context);
    } catch (e) {
      _mostrarError('Error al crear ticket: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
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

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Ticket'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: _cargandoMaquinas
          ? const Center(child: CircularProgressIndicator())
          : _maquinas.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.precision_manufacturing_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No hay activos disponibles', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Primero debés cargar activos en el sistema', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                ]))
              : ListView(
                  padding: padding,
                  children: [
                    // Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue[200]!)),
                      child: Row(children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text('El encargado de la ubicacion recibirá una notificación al crear el ticket.', style: TextStyle(fontSize: 12, color: Colors.blue[700]))),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // Tipo
                    const Text('Tipo de ticket', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tipo = 'correctivo'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _tipo == 'correctivo' ? Colors.red[50] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _tipo == 'correctivo' ? Colors.red : Colors.grey[300]!),
                            ),
                            child: Column(children: [
                              Icon(Icons.build_outlined, color: _tipo == 'correctivo' ? Colors.red : Colors.grey, size: 22),
                              const SizedBox(height: 4),
                              Text('Correctivo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _tipo == 'correctivo' ? Colors.red : Colors.grey)),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _tipo = 'preventivo'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _tipo == 'preventivo' ? Colors.green[50] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _tipo == 'preventivo' ? Colors.green : Colors.grey[300]!),
                            ),
                            child: Column(children: [
                              Icon(Icons.event_available_outlined, color: _tipo == 'preventivo' ? Colors.green : Colors.grey, size: 22),
                              const SizedBox(height: 4),
                              Text('Preventivo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _tipo == 'preventivo' ? Colors.green : Colors.grey)),
                            ]),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Prioridad
                    const Text('Prioridad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['baja', 'media', 'alta', 'critica'].map((p) {
                        final seleccionada = _prioridad == p;
                        final color = _colorPrioridad(p);
                        return ChoiceChip(
                          label: Text(p[0].toUpperCase() + p.substring(1)),
                          selected: seleccionada,
                          selectedColor: color.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: seleccionada ? color : Colors.grey[600],
                            fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                          ),
                          side: BorderSide(color: seleccionada ? color : Colors.grey[300]!),
                          onSelected: (_) => setState(() => _prioridad = p),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Activo
                    DropdownButtonFormField<String>(
                      value: _maquinaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Activo *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                      ),
                      items: _maquinas.map((m) {
                        final sector = (m['sectores'] as Map?)?['nombre'] ?? '';
                        return DropdownMenuItem(
                          value: m['id'] as String,
                          child: Text('${m['nombre']} (${m['codigo']}) — $sector', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _maquinaSeleccionada = v),
                    ),
                    const SizedBox(height: 16),

                    // Descripción
                    TextField(
                      controller: _descripcionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción del desperfecto *',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        hintText: 'Describí el problema con el mayor detalle posible...',
                      ),
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _cargando ? null : _crearTicket,
                        icon: _cargando
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_outlined),
                        label: const Text('Crear Ticket', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
    );
  }
}