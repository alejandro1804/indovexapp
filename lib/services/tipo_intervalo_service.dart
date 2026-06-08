import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tipo_intervalo.dart';

class TipoIntervaloService {
  final _client = Supabase.instance.client;

  Future<List<TipoIntervalo>> obtenerTipos() async {
    final response = await _client
        .from('tipos_intervalo')
        .select()
        .eq('activo', true)
        .order('es_default', ascending: false)
        .order('nombre');
    return response.map((e) => TipoIntervalo.fromMap(e)).toList();
  }

  Future<TipoIntervalo> crearTipo({
    required String nombre,
    required String codigo,
  }) async {
    final response = await _client
        .from('tipos_intervalo')
        .insert({
          'nombre': nombre,
          'codigo': codigo,
        })
        .select()
        .single();
    return TipoIntervalo.fromMap(response);
  }

  Future<TipoIntervalo> actualizarTipo({
    required String id,
    required String nombre,
    required String codigo,
  }) async {
    final response = await _client
        .from('tipos_intervalo')
        .update({
          'nombre': nombre,
          'codigo': codigo,
        })
        .eq('id', id)
        .select()
        .single();
    return TipoIntervalo.fromMap(response);
  }

  Future<void> desactivarTipo(String id) async {
    await _client
        .from('tipos_intervalo')
        .update({'activo': false})
        .eq('id', id);
  }
}