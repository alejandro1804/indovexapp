import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/repuesto.dart';
import '../../providers/auth_provider.dart';

class SalidaRepuestoScreen extends StatefulWidget {
  final Repuesto repuesto;

  const SalidaRepuestoScreen({super.key, required this.repuesto});

  @override
  State<SalidaRepuestoScreen> createState() => _SalidaRepuestoScreenState();
}

class _SalidaRepuestoScreenState extends State<SalidaRepuestoScreen> {
  final _supabase = Supabase.instance.client;
  final _cantidadController = TextEditingController(text: '1');
  final _quienRetiraController = TextEditingController();
  final _observacionController = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    _cantidadController.dispose();
    _quienRetiraController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  String _traducirError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('Stock insuficiente')) {
      final detalle = msg.split('Stock insuficiente.').last.trim();
      return 'Stock insuficiente. $detalle';
    }
    if (msg.contains('network') || msg.contains('SocketException')) return 'Sin conexión a internet';
    if (msg.contains('permission') || msg.contains('RLS')) return 'No tenés permiso para realizar esta acción';
    return 'Error al registrar salida. Intentá de nuevo.';
  }

  Future<void> _registrarSalida() async {
    final cantidad = int.tryParse(_cantidadController.text) ?? 0;
    if (cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad debe ser mayor a 0'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _cargando = true);
    try {
      await _supabase.rpc('registrar_salida_stock', params: {
        'p_repuesto_id': widget.repuesto.id,
        'p_cantidad': cantidad,
        'p_observacion': _observacionController.text.trim().isEmpty
            ? null
            : _observacionController.text.trim(),
        'p_registrado_por': _supabase.auth.currentUser!.id,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salida registrada correctamente'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_traducirError(e)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salida de Repuesto'),
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, color: Color(0xFF1F4E79)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.repuesto.descripcion,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('Código: ${widget.repuesto.codigo}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        Text(
                          'Stock disponible: ${widget.repuesto.stockActual} ${widget.repuesto.unidadMedida}',
                          style: TextStyle(
                            color: widget.repuesto.stockBajo ? Colors.orange : const Color(0xFF1F4E79),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cantidadController,
            decoration: InputDecoration(
              labelText: 'Cantidad *',
              border: const OutlineInputBorder(),
              suffixText: widget.repuesto.unidadMedida,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quienRetiraController,
            decoration: const InputDecoration(
              labelText: 'Quién retira (opcional)',
              border: OutlineInputBorder(),
              hintText: 'Nombre de quien retira el repuesto',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _observacionController,
            decoration: const InputDecoration(
              labelText: 'Observaciones (opcional)',
              border: OutlineInputBorder(),
              hintText: 'Para qué se usa, en qué máquina, etc.',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _cargando ? null : _registrarSalida,
              icon: _cargando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.remove_circle_outline),
              label: const Text('Registrar Salida', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}