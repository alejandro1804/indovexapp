import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/maquina.dart';

class MaquinaService {
  final _supabase = Supabase.instance.client;

  Future<List<Maquina>> obtenerMaquinas() async {
    final data = await _supabase
        .from('maquinas')
        .select()
        .order('nombre');
    return (data as List).map((e) => Maquina.fromMap(e)).toList();
  }

  Future<List<Maquina>> obtenerMaquinasPorSector(String sectorId) async {
    final data = await _supabase
        .from('maquinas')
        .select()
        .eq('sector_id', sectorId)
        .order('nombre');
    return (data as List).map((e) => Maquina.fromMap(e)).toList();
  }
}
