import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RepuestosTicketSection extends StatefulWidget {
  final String ticketId;
  final String maquinaId;
  final bool editable;

  const RepuestosTicketSection({
    super.key,
    required this.ticketId,
    required this.maquinaId,
    this.editable = true,
  });

  @override
  State<RepuestosTicketSection> createState() => _RepuestosTicketSectionState();
}

class _RepuestosTicketSectionState extends State<RepuestosTicketSection> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _consumos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarConsumos();
  }

  Future<void> _cargarConsumos() async {
    setState(() => _cargando = true);
    try {
      final data = await _supabase
          .from('salida_repuestos')
          .select('*, repuestos(codigo, descripcion, unidad_medida)')
          .eq('ticket_id', widget.ticketId)
          .order('created_at', ascending: false);
      setState(() => _consumos = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      // silencioso
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Carga repuestos: primero los asociados a la máquina, después el resto
  Future<List<Map<String, dynamic>>> _cargarRepuestosDisponibles() async {
    // Repuestos asociados a esta máquina
    final asociadosRaw = await _supabase
        .from('repuestos_maquinas')
        .select('repuesto_id')
        .eq('maquina_id', widget.maquinaId);
    final idsAsociados = (asociadosRaw as List).map((e) => e['repuesto_id'] as String).toSet();

    // Todos los repuestos activos
    final todos = await _supabase
        .from('repuestos')
        .select('id, codigo, descripcion, stock_actual, unidad_medida')
        .eq('activo', true)
        .order('descripcion');

    final lista = List<Map<String, dynamic>>.from(todos);
    // Marcar los asociados y ordenarlos primero
    for (final r in lista) {
      r['_asociado'] = idsAsociados.contains(r['id']);
    }
    lista.sort((a, b) {
      if (a['_asociado'] == b['_asociado']) return 0;
      return a['_asociado'] == true ? -1 : 1;
    });
    return lista;
  }

  Future<void> _mostrarFormularioConsumo() async {
    final cantidadController = TextEditingController(text: '1');
    final observacionController = TextEditingController();
    final repuestos = await _cargarRepuestosDisponibles();

    if (repuestos.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay repuestos disponibles'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
      );
      return;
    }

    String? repuestoSeleccionado = repuestos.first['id'] as String;

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Registrar consumo de repuesto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: repuestoSeleccionado,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Repuesto *', border: OutlineInputBorder()),
                items: repuestos.map((r) {
                  final asociado = r['_asociado'] == true;
                  return DropdownMenuItem(
                    value: r['id'] as String,
                    child: Row(children: [
                      if (asociado)
                        const Padding(
                          padding: EdgeInsets.only(right: 6),
                          child: Icon(Icons.link, size: 14, color: Color(0xFF1F4E79)),
                        ),
                      Expanded(
                        child: Text(
                          '${r['descripcion']} (stock: ${r['stock_actual']})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  );
                }).toList(),
                onChanged: (v) => setSheetState(() => repuestoSeleccionado = v),
              ),
              const SizedBox(height: 8),
              Text(
                'Los repuestos con 🔗 están asociados a esta máquina.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cantidadController,
                decoration: const InputDecoration(
                  labelText: 'Cantidad *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: observacionController,
                decoration: const InputDecoration(
                  labelText: 'Observación',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final cantidad = int.tryParse(cantidadController.text.trim());
                    if (cantidad == null || cantidad <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ingresá una cantidad válida'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    await _registrarConsumo(
                      repuestoSeleccionado!,
                      cantidad,
                      observacionController.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
                  child: const Text('Registrar consumo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _registrarConsumo(String repuestoId, int cantidad, String observacion) async {
    try {
      await _supabase.rpc('registrar_salida_stock', params: {
        'p_repuesto_id': repuestoId,
        'p_cantidad': cantidad,
        'p_ticket_id': widget.ticketId,
        'p_observacion': observacion.isEmpty ? null : observacion,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consumo registrado'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
      );
      await _cargarConsumos();
    } catch (e) {
      if (!mounted) return;
      String msg = 'Error al registrar consumo';
      if (e.toString().contains('Stock insuficiente')) {
        msg = 'Stock insuficiente para este repuesto';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF1F4E79)),
              const SizedBox(width: 8),
              const Text('Repuestos utilizados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (widget.editable)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1F4E79)),
                  onPressed: _mostrarFormularioConsumo,
                ),
            ]),
            const Divider(),
            if (_cargando)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
            else if (_consumos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No se registraron repuestos en este ticket.', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              )
            else
              ..._consumos.map((c) {
                final rep = c['repuestos'] as Map?;
                final unidad = rep?['unidad_medida'] ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '-${c['cantidad']} $unidad',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          '${rep?['descripcion'] ?? ''} (${rep?['codigo'] ?? ''})',
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                        if (c['observacion'] != null && (c['observacion'] as String).isNotEmpty)
                          Text(c['observacion'], style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                      ]),
                    ),
                  ]),
                );
              }),
          ],
        ),
      ),
    );
  }
}