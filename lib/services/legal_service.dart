import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/documento_legal.dart';

class LegalService {
  final _supabase = Supabase.instance.client;

  /// Documentos legales vigentes que la empresa aún no aceptó.
  /// Durante el preaviso devuelve enPreaviso=true y bloqueante=false.
  Future<List<DocumentoLegal>> estadoPendiente() async {
    final data = await _supabase.rpc('legal_estado_pendiente');
    return (data as List)
        .map((e) => DocumentoLegal.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Registra la aceptación. Solo el admin de la empresa.
  /// Idempotente: si ya estaba aceptado, devuelve la aceptación previa.
  Future<String> aceptar(String documentoLegalId, {String? userAgent}) async {
    final data = await _supabase.rpc('legal_aceptar', params: {
      'p_documento_legal_id': documentoLegalId,
      'p_user_agent': userAgent,
    });
    return data as String;
  }

  /// Cobertura de aceptación por empresa. Solo super admin.
  Future<List<Map<String, dynamic>>> cobertura() async {
    final data = await _supabase.rpc('sa_legal_cobertura');
    return (data as List).cast<Map<String, dynamic>>();
  }
}