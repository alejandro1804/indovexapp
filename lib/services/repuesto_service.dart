import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/repuesto.dart';

class RepuestoService {
  final _supabase = Supabase.instance.client;

  Future<List<Repuesto>> obtenerRepuestos() async {
    final data = await _supabase
        .from('repuestos')
        .select()
        .eq('activo', true)
        .order('descripcion');
    return (data as List).map((e) => Repuesto.fromMap(e)).toList();
  }

Future<List<Repuesto>> obtenerRepuestosBajoStock() async {
  final data = await _supabase
      .from('repuestos_bajo_stock')
      .select()
      .order('descripcion');
  return (data as List).map((e) => Repuesto.fromMap(e)).toList();
}

  Future<void> registrarIngreso({
    required String repuestoId,
    required int cantidad,
    String? proveedorId,
    String? descripcion,
  }) async {
    await _supabase.rpc('registrar_ingreso_stock', params: {
      'p_repuesto_id': repuestoId,
      'p_cantidad': cantidad,
      'p_proveedor_id': proveedorId,
      'p_descripcion': descripcion,
    });
  }

  Future<void> registrarSalida({
    required String repuestoId,
    required int cantidad,
    String? ticketId,
    String? observacion,
  }) async {
    await _supabase.rpc('registrar_salida_stock', params: {
      'p_repuesto_id': repuestoId,
      'p_cantidad': cantidad,
      'p_ticket_id': ticketId,
      'p_observacion': observacion,
    });
  }
}