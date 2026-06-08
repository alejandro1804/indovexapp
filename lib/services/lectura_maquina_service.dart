import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lectura_maquina.dart';

class LecturaMaquinaService {
  final _client = Supabase.instance.client;

  Future<List<LecturaMaquina>> obtenerLecturas({
    required String maquinaId,
    String? tipo,
    int limite = 20,
  }) async {
    var query = _client
        .from('lecturas_maquina')
        .select()
        .eq('maquina_id', maquinaId);

    if (tipo != null) {
      query = query.eq('tipo', tipo);
    }

    final response = await query
        .order('fecha_lectura', ascending: false)
        .limit(limite);
    return response.map((e) => LecturaMaquina.fromMap(e)).toList();
  }

  Future<LecturaMaquina?> obtenerUltimaLectura({
    required String maquinaId,
    required String tipo,
  }) async {
    final response = await _client
        .from('lecturas_maquina')
        .select()
        .eq('maquina_id', maquinaId)
        .eq('tipo', tipo)
        .order('fecha_lectura', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return LecturaMaquina.fromMap(response);
  }

  Future<LecturaMaquina> registrarLectura({
    required String maquinaId,
    required String tipo,
    required double valor,
    DateTime? fechaLectura,
    String? observacion,
  }) async {
    final response = await _client
        .from('lecturas_maquina')
        .insert({
          'maquina_id': maquinaId,
          'tipo': tipo,
          'valor': valor,
          'fecha_lectura':
              (fechaLectura ?? DateTime.now()).toIso8601String().split('T')[0],
          if (observacion != null) 'observacion': observacion,
        })
        .select()
        .single();

    return LecturaMaquina.fromMap(response);
  }
}