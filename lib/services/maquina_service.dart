import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/maquina.dart';

class MaquinaService {
  final _supabase = Supabase.instance.client;

  /// Activos vigentes de la empresa. No incluye los dados de baja.
  Future<List<Maquina>> obtenerMaquinas() async {
    final data = await _supabase
        .from('maquinas')
        .select()
        .neq('estado', Maquina.estadoDadaDeBaja)
        .order('nombre');
    return (data as List).map((e) => Maquina.fromMap(e)).toList();
  }

  /// Activos vigentes de una ubicación. No incluye los dados de baja.
  Future<List<Maquina>> obtenerMaquinasPorSector(String sectorId) async {
    final data = await _supabase
        .from('maquinas')
        .select()
        .eq('sector_id', sectorId)
        .neq('estado', Maquina.estadoDadaDeBaja)
        .order('nombre');
    return (data as List).map((e) => Maquina.fromMap(e)).toList();
  }

  /// Baja lógica: el activo no se borra. Conserva su historial, deja de
  /// aparecer en listados y selectores, no admite tickets nuevos y no ocupa
  /// lugar del plan. La base exige el permiso dar_baja_maquinas y rechaza la
  /// baja si quedan tickets sin cerrar (trg_proteger_baja_maquina).
  Future<void> darDeBaja(String maquinaId) async {
    await _supabase
        .from('maquinas')
        .update({'estado': Maquina.estadoDadaDeBaja})
        .eq('id', maquinaId);
  }

  /// Revierte la baja dejando el activo en [estado]. Exige el mismo permiso
  /// que darDeBaja; la base valida además el límite de activos del plan.
  Future<void> reactivar(String maquinaId, {String estado = 'operativa'}) async {
    await _supabase
        .from('maquinas')
        .update({'estado': estado})
        .eq('id', maquinaId);
  }
}