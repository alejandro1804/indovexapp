import 'package:supabase_flutter/supabase_flutter.dart';

/// Datos del reporte "Historial de un activo".
///
/// Se trabaja con filas crudas (Map) a propósito: es un reporte de solo
/// lectura y así no depende de los constructores de cada modelo.
class HistorialMaquina {
  const HistorialMaquina({
    required this.maquina,
    required this.nombreEmpresa,
    required this.nombreSector,
    required this.desde,
    required this.hasta,
    required this.tickets,
    required this.planes,
    required this.lecturas,
    required this.adjuntos,
    required this.usuarios,
    required this.tiposIntervalo,
  });

  final Map<String, dynamic> maquina;
  final String nombreEmpresa;
  final String nombreSector;

  /// Período aplicado a tickets y lecturas. null = sin límite.
  final DateTime? desde;
  final DateTime? hasta;

  final List<Map<String, dynamic>> tickets;
  final List<Map<String, dynamic>> planes;
  final List<Map<String, dynamic>> lecturas;
  final List<Map<String, dynamic>> adjuntos;

  /// usuario_id -> nombre (para técnico, quién registró, quién subió).
  final Map<String, String> usuarios;

  /// codigo -> nombre de tipos_intervalo.
  final Map<String, String> tiposIntervalo;
}

class HistorialMaquinaService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Activos para el selector, incluidos los dados de baja (su historial
  /// se conserva y puede pedirse en una auditoría). La RLS ya limita a la
  /// empresa y, si corresponde, a las ubicaciones asignadas.
  ///
  /// Agrega 'sector_nombre' a cada fila. Se resuelve aparte y no con un
  /// embed porque la FK maquinas.sector_id todavía no está creada.
  static Future<List<Map<String, dynamic>>> listarMaquinas() async {
    final maquinas = List<Map<String, dynamic>>.from(
      await _db
          .from('maquinas')
          .select('id, nombre, codigo, estado, sector_id')
          .order('nombre'),
    );
    final sectores = await _nombresSectores();
    for (final m in maquinas) {
      m['sector_nombre'] = sectores[m['sector_id']] ?? '-';
    }
    return maquinas;
  }

  static Future<HistorialMaquina> cargar({
    required String maquinaId,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final maquina = await _db
        .from('maquinas')
        .select('id, empresa_id, nombre, codigo, estado, descripcion, sector_id')
        .eq('id', maquinaId)
        .single();

    // Límites del período: desde el inicio del día "desde" hasta el final
    // del día "hasta" (se usa < día siguiente).
    final inicio = desde == null ? null : DateTime(desde.year, desde.month, desde.day);
    final finExcl = hasta == null ? null : DateTime(hasta.year, hasta.month, hasta.day + 1);

    // ── Tickets ────────────────────────────────────────────────────────────
    var qTickets = _db
        .from('tickets')
        .select('id, numero, tipo, prioridad, estado, descripcion_desperfecto, '
            'observacion_tecnico, tecnico_id, creado_por, created_at, '
            'fecha_cierre, plan_id')
        .eq('maquina_id', maquinaId);
    if (inicio != null) qTickets = qTickets.gte('created_at', inicio.toUtc().toIso8601String());
    if (finExcl != null) qTickets = qTickets.lt('created_at', finExcl.toUtc().toIso8601String());
    final tickets = List<Map<String, dynamic>>.from(
      await qTickets.order('created_at', ascending: false),
    );

    // ── Planes (siempre todos: son la configuración vigente del activo) ───
    final planes = List<Map<String, dynamic>>.from(
      await _db
          .from('planes_mantenimiento')
          .select('id, descripcion_tarea, tipo_intervalo, intervalo_valor, '
              'ultimo_valor_ejecutado, proximo_valor, activo')
          .eq('maquina_id', maquinaId)
          .order('created_at'),
    );

    // ── Lecturas ───────────────────────────────────────────────────────────
    var qLecturas = _db
        .from('lecturas_maquina')
        .select('fecha_lectura, tipo, valor, observacion, registrado_por')
        .eq('maquina_id', maquinaId);
    if (inicio != null) qLecturas = qLecturas.gte('fecha_lectura', _soloFecha(inicio));
    if (finExcl != null) qLecturas = qLecturas.lt('fecha_lectura', _soloFecha(finExcl));
    final lecturas = List<Map<String, dynamic>>.from(
      await qLecturas.order('fecha_lectura', ascending: false),
    );

    // ── Adjuntos del activo ───────────────────────────────────────────────
    final adjuntos = List<Map<String, dynamic>>.from(
      await _db
          .from('adjuntos')
          .select('nombre_archivo, tipo_mime, tamanio_bytes, created_at, subido_por')
          .eq('entidad_tipo', 'maquina')
          .eq('entidad_id', maquinaId)
          .order('created_at', ascending: false),
    );

    // ── Datos de apoyo: fail-open, si fallan el reporte sale igual ────────
    final idsUsuarios = <String>{
      for (final t in tickets) ...[t['tecnico_id'], t['creado_por']],
      for (final l in lecturas) l['registrado_por'],
      for (final a in adjuntos) a['subido_por'],
    }.whereType<String>().toList();

    final sectores = await _nombresSectores();

    return HistorialMaquina(
      maquina: maquina,
      nombreEmpresa: await _nombreEmpresa(maquina['empresa_id'] as String?),
      nombreSector: sectores[maquina['sector_id']] ?? '-',
      desde: inicio,
      hasta: hasta == null ? null : DateTime(hasta.year, hasta.month, hasta.day),
      tickets: tickets,
      planes: planes,
      lecturas: lecturas,
      adjuntos: adjuntos,
      usuarios: await _nombresUsuarios(idsUsuarios),
      tiposIntervalo: await _tiposIntervalo(),
    );
  }

  static String _soloFecha(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${f.year}-${d(f.month)}-${d(f.day)}';
  }

  static Future<Map<String, String>> _nombresSectores() async {
    try {
      final rows = await _db.from('sectores').select('id, nombre');
      return {for (final s in rows) s['id'] as String: s['nombre'] as String};
    } catch (_) {
      return {};
    }
  }

  static Future<String> _nombreEmpresa(String? empresaId) async {
    if (empresaId == null) return 'IndovexApp';
    try {
      final row = await _db.from('empresas').select('nombre').eq('id', empresaId).maybeSingle();
      return (row?['nombre'] as String?) ?? 'IndovexApp';
    } catch (_) {
      return 'IndovexApp';
    }
  }

  static Future<Map<String, String>> _nombresUsuarios(List<String> ids) async {
    if (ids.isEmpty) return {};
    try {
      final rows = await _db.from('usuarios').select('id, nombre').inFilter('id', ids);
      return {
        for (final u in rows) u['id'] as String: (u['nombre'] as String?) ?? '-',
      };
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, String>> _tiposIntervalo() async {
    try {
      final rows = await _db.from('tipos_intervalo').select('codigo, nombre');
      return {for (final t in rows) t['codigo'] as String: t['nombre'] as String};
    } catch (_) {
      return {};
    }
  }
}