import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/repuesto.dart';
import 'ingreso_repuesto_screen.dart';
import 'salida_repuesto_screen.dart';

class RepuestoDetailScreen extends StatefulWidget {
  final Repuesto repuesto;

  const RepuestoDetailScreen({super.key, required this.repuesto});

  @override
  State<RepuestoDetailScreen> createState() => _RepuestoDetailScreenState();
}

class _RepuestoDetailScreenState extends State<RepuestoDetailScreen> {
  final _supabase = Supabase.instance.client;
  late Repuesto _repuesto;

  @override
  void initState() {
    super.initState();
    _repuesto = widget.repuesto;
  }

  Future<void> _recargarRepuesto() async {
    try {
      final data = await _supabase
          .from('repuestos')
          .select()
          .eq('id', _repuesto.id)
          .single();
      setState(() => _repuesto = Repuesto.fromMap(data));
    } catch (e) {
      // Si falla la recarga, mantiene los datos anteriores
    }
  }

  Future<void> _irAIngreso() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IngresoRepuestoScreen(repuesto: _repuesto),
      ),
    );
    if (resultado == true) await _recargarRepuesto();
  }

  Future<void> _irASalida() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalidaRepuestoScreen(repuesto: _repuesto),
      ),
    );
    if (resultado == true) await _recargarRepuesto();
  }

  @override
  Widget build(BuildContext context) {
    final stockBajo = _repuesto.stockBajo;

    return Scaffold(
      appBar: AppBar(
        title: Text(_repuesto.descripcion),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stock actual
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: stockBajo
                  ? Colors.orange.withOpacity(0.1)
                  : const Color(0xFF1F4E79).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: stockBajo
                    ? Colors.orange.withOpacity(0.3)
                    : const Color(0xFF1F4E79).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock actual', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    Text(
                      '${_repuesto.stockActual} ${_repuesto.unidadMedida}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: stockBajo ? Colors.orange : const Color(0xFF1F4E79),
                      ),
                    ),
                    if (stockBajo)
                      const Text(
                        '⚠ Stock bajo',
                        style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Mínimo', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    Text(
                      '${_repuesto.stockMinimo}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Acciones
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _irAIngreso,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Ingreso'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _irASalida,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Salida'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Info
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Información',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  _infoRow('Código', _repuesto.codigo),
                  if (_repuesto.ubicacion != null && _repuesto.ubicacion!.isNotEmpty)
                    _infoRow('Ubicación', _repuesto.ubicacion!),
                  if (_repuesto.notas != null && _repuesto.notas!.isNotEmpty)
                    _infoRow('Notas', _repuesto.notas!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}