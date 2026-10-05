import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/audit_log.dart';

class AuditLogService {
  final _client = Supabase.instance.client;

  Future<List<AuditLog>> obtenerLogs({
    String? tabla,
    String? operacion,
    DateTime? desde,
    DateTime? hasta,
    int limite = 1000,
  }) async {
    var query = _client.from('audit_log').select();

    if (tabla != null && tabla != 'todos') {
      query = query.eq('tabla', tabla);
    }
    if (operacion != null && operacion != 'todos') {
      query = query.eq('operacion', operacion);
    }
    if (desde != null) {
      query = query.gte('created_at', desde.toUtc().toIso8601String());
    }
    if (hasta != null) {
      final finDia = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59);
      query = query.lte('created_at', finDia.toUtc().toIso8601String());
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limite);

    final logs = List<Map<String, dynamic>>.from(response);

    // Traer nombres de usuarios por separado (no hay FK en audit_log)
    final usuariosIds = logs
        .map((e) => e['usuario_id'])
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();

    final nombres = await _obtenerNombres(usuariosIds);

    for (final log in logs) {
      final uid = log['usuario_id'];
      if (uid != null && nombres.containsKey(uid)) {
        log['usuarios'] = {'nombre': nombres[uid]};
      }
    }

    return logs.map((e) => AuditLog.fromMap(e)).toList();
  }

  Future<List<AuditLog>> obtenerPorRegistro({
    required String tabla,
    required String registroId,
  }) async {
    final response = await _client
        .from('audit_log')
        .select()
        .eq('tabla', tabla)
        .eq('registro_id', registroId)
        .order('created_at', ascending: false);

    final logs = List<Map<String, dynamic>>.from(response);

    final usuariosIds = logs
        .map((e) => e['usuario_id'])
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();

    final nombres = await _obtenerNombres(usuariosIds);

    for (final log in logs) {
      final uid = log['usuario_id'];
      if (uid != null && nombres.containsKey(uid)) {
        log['usuarios'] = {'nombre': nombres[uid]};
      }
    }

    return logs.map((e) => AuditLog.fromMap(e)).toList();
  }

  Future<Map<String, String>> _obtenerNombres(List<String> ids) async {
    if (ids.isEmpty) return {};
    final data = await _client
        .from('usuarios')
        .select('id, nombre')
        .inFilter('id', ids);
    final mapa = <String, String>{};
    for (final u in data as List) {
      mapa[u['id']] = u['nombre'];
    }

    // Los que no se pudieron leer son usuarios de otra empresa (RLS).
    // Solo el super admin los resuelve, con la RPC sa_nombres_usuarios;
    // para cualquier otro usuario la RPC devuelve vacío.
    final faltantes = ids.where((id) => !mapa.containsKey(id)).toList();
    if (faltantes.isNotEmpty) {
      try {
        final extra = await _client
            .rpc('sa_nombres_usuarios', params: {'p_ids': faltantes});
        for (final u in extra as List) {
          mapa[u['id']] = u['nombre'];
        }
      } catch (_) {
        // Si la RPC falla, esos registros quedan sin nombre: la pantalla
        // muestra "Usuario no disponible" en lugar de "Sistema".
      }
    }

    return mapa;
  }

  Future<List<String>> obtenerTablasDisponibles() async {
    final response = await _client
        .from('audit_log')
        .select('tabla')
        .order('tabla');
    return (response as List)
        .map((e) => e['tabla'] as String)
        .toSet()
        .toList();
  }
}