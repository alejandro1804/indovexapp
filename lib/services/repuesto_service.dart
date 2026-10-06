import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/repuesto.dart';

class RepuestoService {
  final _supabase = Supabase.instance.client;

  /// Lista los repuestos de la empresa. Por defecto solo los activos;
  /// con [activos] en false trae los dados de baja.
  Future<List<Repuesto>> obtenerRepuestos({bool activos = true}) async {
    final data = await _supabase
        .from('repuestos')
        .select()
        .eq('activo', activos)
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

  /// Baja lógica: el repuesto deja de aparecer en listados y selectores y no
  /// admite movimientos, pero conserva su historial. No se borra nunca.
  /// La base exige el permiso dar_baja_repuestos (trg_proteger_baja_repuesto).
  Future<void> darDeBaja(String repuestoId) async {
    await _supabase
        .from('repuestos')
        .update({'activo': false})
        .eq('id', repuestoId);
  }

  /// Revierte la baja. Exige el mismo permiso que darDeBaja.
  Future<void> reactivar(String repuestoId) async {
    await _supabase
        .from('repuestos')
        .update({'activo': true})
        .eq('id', repuestoId);
  }
}