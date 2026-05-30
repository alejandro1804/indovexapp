import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/repuesto.dart';
import '../../models/proveedor.dart';
import '../../providers/auth_provider.dart';

class IngresoRepuestoScreen extends StatefulWidget {
  final Repuesto repuesto;

  const IngresoRepuestoScreen({super.key, required this.repuesto});

  @override
  State<IngresoRepuestoScreen> createState() => _IngresoRepuestoScreenState();
}

class _IngresoRepuestoScreenState extends State<IngresoRepuestoScreen> {
  final _supabase = Supabase.instance.client;
  final _cantidadController = TextEditingController(text: '1');
  final _quienEntregaController = TextEditingController();
  final _descripcionController = TextEditingController();
  List<Proveedor> _proveedores = [];
  String? _proveedorSeleccionado;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarProveedores();
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _quienEntregaController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _cargarProveedores() async {
    try {
      final data = await _supabase
          .from('proveedores')
          .select()
          .eq('activo', true)
          .order('nombre');
      setState(() {
        _proveedores = (data as List).map((e) => Proveedor.fromMap(e)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar proveedores'), backgroundColor: Colors.orange),
      );
    }
  }

  String _traducirError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('Stock insuficiente')) return msg.split('Stock insuficiente').last.trim();
    if (msg.contains('network') || msg.contains('SocketException')) return 'Sin conexión a internet';
    if (msg.contains('permission') || msg.contains('RLS')) return 'No tenés permiso para realizar esta acción';
    return 'Error al registrar ingreso. Intentá de nuevo.';
  }

  Future<void> _registrarIngreso() async {
    final cantidad = int.tryParse(_cantidadController.text) ?? 0;
    if (cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad debe ser mayor a 0'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _cargando = true);
    try {
      await _supabase.rpc('registrar_ingreso_stock', params: {
        'p_repuesto_id': widget.repuesto.id,
        'p_cantidad': cantidad,
        'p_proveedor_id': _proveedorSeleccionado,
        'p_descripcion': _descripcionController.text.trim().isEmpty
            ? null
            : _descripcionController.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingreso registrado correctamente'), backgroundColor: Colors.green),
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
        title: const Text('Ingreso de Repuesto'),
        backgroundColor: Colors.green,
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
                          'Stock actual: ${widget.repuesto.stockActual} ${widget.repuesto.unidadMedida}',
                          style: const TextStyle(
                              color: Color(0xFF1F4E79), fontWeight: FontWeight.w500),
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
          DropdownButtonFormField<String?>(
            value: _proveedorSeleccionado,
            decoration: const InputDecoration(
              labelText: 'Proveedor (opcional)',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin proveedor')),
              ..._proveedores.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre))),
            ],
            onChanged: (v) => setState(() => _proveedorSeleccionado = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _quienEntregaController,
            decoration: const InputDecoration(
              labelText: 'Quién entrega (opcional)',
              border: OutlineInputBorder(),
              hintText: 'Nombre de la persona que trae el repuesto',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descripcionController,
            decoration: const InputDecoration(
              labelText: 'Observaciones (opcional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _cargando ? null : _registrarIngreso,
              icon: _cargando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.add_circle_outline),
              label: const Text('Registrar Ingreso', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}