import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/plan_mantenimiento.dart';

class PlanMantenimientoService {
  final _client = Supabase.instance.client;

  Future<String> _getEmpresaId() async {
    final response = await _client
        .from('usuarios')
        .select('empresa_id')
        .eq('id', _client.auth.currentUser!.id)
        .single();
    return response['empresa_id'] as String;
  }

  Future<List<PlanMantenimiento>> obtenerPlanes({String? maquinaId}) async {
    var query = _client
        .from('planes_mantenimiento')
        .select('*, maquinas(nombre, codigo)')
        .eq('activo', true);

    if (maquinaId != null) {
      query = query.eq('maquina_id', maquinaId);
    }

    final response = await query.order('created_at', ascending: false);
    return response.map((e) => PlanMantenimiento.fromMap(e)).toList();
  }

  Future<PlanMantenimiento> crearPlan({
    required String maquinaId,
    required String descripcionTarea,
    required String tipoIntervalo,
    required double intervaloValor,
    String? procedimiento,
  }) async {
    final empresaId = await _getEmpresaId();
    final response = await _client
        .from('planes_mantenimiento')
        .insert({
          'empresa_id': empresaId,
          'maquina_id': maquinaId,
          'descripcion_tarea': descripcionTarea,
          'tipo_intervalo': tipoIntervalo,
          'intervalo_valor': intervaloValor,
          if (procedimiento != null && procedimiento.isNotEmpty)
            'procedimiento': procedimiento,
        })
        .select('*, maquinas(nombre, codigo)')
        .single();

    return PlanMantenimiento.fromMap(response);
  }

  Future<PlanMantenimiento> actualizarPlan({
    required String id,
    String? descripcionTarea,
    String? tipoIntervalo,
    double? intervaloValor,
    bool? activo,
    String? procedimiento,
  }) async {
    final data = <String, dynamic>{};
    if (descripcionTarea != null) data['descripcion_tarea'] = descripcionTarea;
    if (tipoIntervalo != null) data['tipo_intervalo'] = tipoIntervalo;
    if (intervaloValor != null) data['intervalo_valor'] = intervaloValor;
    if (activo != null) data['activo'] = activo;
    if (procedimiento != null) data['procedimiento'] = procedimiento.isEmpty ? null : procedimiento;

    final response = await _client
        .from('planes_mantenimiento')
        .update(data)
        .eq('id', id)
        .select('*, maquinas(nombre, codigo)')
        .single();

    return PlanMantenimiento.fromMap(response);
  }

  Future<void> eliminarPlan(String id) async {
    await _client
        .from('planes_mantenimiento')
        .update({'activo': false})
        .eq('id', id);
  }

  Future<void> registrarEjecucion({
    required String planId,
    required double valorEjecutado,
    required double proximoValor,
  }) async {
    await _client
        .from('planes_mantenimiento')
        .update({
          'ultimo_valor_ejecutado': valorEjecutado,
          'proximo_valor': proximoValor,
        })
        .eq('id', planId);
  }
}