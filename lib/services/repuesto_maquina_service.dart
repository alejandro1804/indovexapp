import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/repuesto_maquina.dart';

class RepuestoMaquinaService {
  final _client = Supabase.instance.client;

  // Repuestos asociados a una máquina
  Future<List<RepuestoMaquina>> obtenerPorMaquina(String maquinaId) async {
    final response = await _client
        .from('repuestos_maquinas')
        .select('*, repuestos(codigo, descripcion)')
        .eq('maquina_id', maquinaId)
        .order('created_at', ascending: false);
    return response.map((e) => RepuestoMaquina.fromMap(e)).toList();
  }

  // Máquinas asociadas a un repuesto
  Future<List<RepuestoMaquina>> obtenerPorRepuesto(String repuestoId) async {
    final response = await _client
        .from('repuestos_maquinas')
        .select('*, maquinas(nombre, codigo)')
        .eq('repuesto_id', repuestoId)
        .order('created_at', ascending: false);
    return response.map((e) => RepuestoMaquina.fromMap(e)).toList();
  }

  Future<RepuestoMaquina> vincular({
    required String repuestoId,
    required String maquinaId,
    required int cantidad,
    String? ubicacionEnMaquina,
    String? observacion,
  }) async {
    final response = await _client
        .from('repuestos_maquinas')
        .insert({
          'repuesto_id': repuestoId,
          'maquina_id': maquinaId,
          'cantidad': cantidad,
          if (ubicacionEnMaquina != null && ubicacionEnMaquina.isNotEmpty)
            'ubicacion_en_maquina': ubicacionEnMaquina,
          if (observacion != null && observacion.isNotEmpty)
            'observacion': observacion,
        })
        .select('*, repuestos(codigo, descripcion), maquinas(nombre, codigo)')
        .single();
    return RepuestoMaquina.fromMap(response);
  }

  Future<RepuestoMaquina> actualizar({
    required String id,
    int? cantidad,
    String? ubicacionEnMaquina,
    String? observacion,
  }) async {
    final data = <String, dynamic>{};
    if (cantidad != null) data['cantidad'] = cantidad;
    if (ubicacionEnMaquina != null) {
      data['ubicacion_en_maquina'] = ubicacionEnMaquina.isEmpty ? null : ubicacionEnMaquina;
    }
    if (observacion != null) {
      data['observacion'] = observacion.isEmpty ? null : observacion;
    }

    final response = await _client
        .from('repuestos_maquinas')
        .update(data)
        .eq('id', id)
        .select('*, repuestos(codigo, descripcion), maquinas(nombre, codigo)')
        .single();
    return RepuestoMaquina.fromMap(response);
  }

  Future<void> desvincular(String id) async {
    await _client
        .from('repuestos_maquinas')
        .delete()
        .eq('id', id);
  }
}