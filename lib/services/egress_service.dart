import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio central de instrumentación de egress (transferencia).
///
/// Registra, de forma best-effort, los bytes que la app sirve al usuario
/// desde Supabase, agrupados por origen. Alimenta el termómetro de egress
/// del panel super admin (RPC uso_egress_empresa).
///
/// Principios:
///  - **Fail-open / silencioso**: el egress es telemetría. Si el registro
///    falla (red, RLS, lo que sea), NUNCA debe romper ni degradar la acción
///    del usuario (compartir un PDF, ver una imagen, exportar). Mismo criterio
///    que verificarEspacio() y LegalProvider.
///  - **La empresa la resuelve el backend**: para usuarios normales, la RPC
///    registrar_egress deriva la empresa del usuario autenticado
///    (get_empresa_id) y NO se pasa desde acá.
///  - **Excepción export (super admin)**: sa_export_empresa lo dispara el
///    super admin sobre la data de un cliente específico. En ese caso SÍ se
///    pasa [empresaId] explícito, para imputar el egress al cliente exportado
///    y no descartarlo. La RPC solo respeta ese empresaId si el llamador es
///    super admin; para un usuario normal lo ignora.
///
/// Uso normal (usuario cliente):
/// ```dart
/// await EgressService.registrar(EgressOrigen.pdf, bytes.length);
/// ```
///
/// Uso export (super admin, empresa explícita):
/// ```dart
/// await EgressService.registrar(EgressOrigen.export, zipBytes.length,
///     empresaId: empresaId);
/// ```
class EgressService {
  static final _sb = Supabase.instance.client;

  /// Registra [bytes] de egress del [origen] indicado.
  ///
  /// [empresaId] solo se usa en el caso export disparado por super admin.
  /// En uso normal se omite y la empresa la resuelve el backend.
  /// No lanza nunca: cualquier error se traga silenciosamente.
  static Future<void> registrar(
    String origen,
    int bytes, {
    String? empresaId,
  }) async {
    // Guarda barata local: no molestar al backend con no-ops.
    if (bytes <= 0) return;

    try {
      final params = <String, dynamic>{
        'p_origen': origen,
        'p_bytes': bytes,
      };
      if (empresaId != null) {
        params['p_empresa_id'] = empresaId;
      }
      await _sb.rpc('registrar_egress', params: params);
    } catch (_) {
      // Telemetría best-effort: no propagar. La acción del usuario ya ocurrió.

    }
  }
}

/// Orígenes válidos de egress. Deben coincidir con el CHECK de la tabla
/// egress_mensual_agg y la validación de registrar_egress en la DB.
class EgressOrigen {
  static const imagen = 'imagen';
  static const pdf = 'pdf';
  static const export = 'export';
}