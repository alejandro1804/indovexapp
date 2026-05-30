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
  bool _cargando = false;
  bool _cargandoMaquinas = true;

  @override
  void initState() { super.initState(); _cargarMaquinas(); }

  Future<void> _cargarMaquinas() async {
    try {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;

      List<Map<String, dynamic>> maquinas;

      if (usuario.esEncargado) {
        // Solo máquinas de sus sectores
        final sectoresData = await _supabase
            .from('encargado_sector')
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
      _mostrarError('Error al cargar máquinas: $e');
    } finally {
      setState(() => _cargandoMaquinas = false);
    }
  }

  Future<String> _generarNumero() async {
    final data = await _supabase
        .from('tickets')
        .select('numero')
        .order('created_at', ascending: false)
        .limit(1);
    if ((data as List).isEmpty) return 'TK-0001';
    final ultimo = data.first['numero'] as String;
    final numero = int.tryParse(ultimo.split('-').last) ?? 0;
    return 'TK-${(numero + 1).toString().padLeft(4, '0')}';
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

      final numero = await _generarNumero();

      // Crear ticket
      final ticketData = await _supabase.from('tickets').insert({
        'empresa_id': usuario.empresaId,
        'maquina_id': _maquinaSeleccionada,
        'creado_por': usuario.id,
        'numero': numero,
        'estado': 'abierto',
        'descripcion_desperfecto': _descripcionController.text.trim(),
      }).select().single();

      // Registrar en historial
      await _supabase.from('ticket_historial').insert({
        'ticket_id': ticketData['id'],
        'usuario_id': usuario.id,
        'estado_anterior': null,
        'estado_nuevo': 'abierto',
        'comentario': 'Ticket creado',
      });

      // Notificar a encargados del sector
      final maquina = await _supabase
          .from('maquinas')
          .select('sector_id')
          .eq('id', _maquinaSeleccionada!)
          .single();

      final encargados = await _supabase
          .from('encargado_sector')
          .select('usuario_id')
          .eq('sector_id', maquina['sector_id']);

      for (final enc in encargados as List) {
        if (enc['usuario_id'] != usuario.id) {
          await _supabase.from('notificaciones').insert({
            'tipo': 'ticket_nuevo',
            'mensaje': 'Nuevo ticket $numero creado por ${usuario.nombre}',
            'ticket_id': ticketData['id'],
            'para_usuario_id': enc['usuario_id'],
            'de_usuario_id': usuario.id,
          });
        }
      }

      // También notificar admins
      final admins = await _supabase
          .from('usuarios')
          .select('id, roles(nombre)')
          .eq('empresa_id', usuario.empresaId)
          .eq('estado', 'activo');

      for (final admin in admins as List) {
        final rolNombre = (admin['roles'] as Map?)?['nombre'];
        if (rolNombre == 'admin' && admin['id'] != usuario.id) {
          await _supabase.from('notificaciones').insert({
            'tipo': 'ticket_nuevo',
            'mensaje': 'Nuevo ticket $numero creado por ${usuario.nombre}',
            'ticket_id': ticketData['id'],
            'para_usuario_id': admin['id'],
            'de_usuario_id': usuario.id,
          });
        }
      }

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
                  Text('No hay máquinas disponibles', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Primero debés cargar máquinas en el sistema', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
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
                        Expanded(child: Text('El encargado del sector recibirá una notificación al crear el ticket.', style: TextStyle(fontSize: 12, color: Colors.blue[700]))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    // Máquina
                    DropdownButtonFormField<String>(
                      value: _maquinaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Máquina *',
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