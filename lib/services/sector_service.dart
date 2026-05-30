import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sector.dart';

class SectorService {
  final _supabase = Supabase.instance.client;

  Future<List<Sector>> obtenerSectores() async {
    final data = await _supabase
        .from('sectores')
        .select()
        .order('nombre');
    return (data as List).map((e) => Sector.fromMap(e)).toList();
  }
}
