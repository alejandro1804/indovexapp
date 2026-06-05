import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Conditional imports — Flutter elige el correcto según la plataforma
import 'document_helper_mobile.dart'
    if (dart.library.html) 'document_helper_web.dart' as platform;

class DocumentHelper {
  static final _supabase = Supabase.instance.client;
  static const _bucket = 'documentos';

  static Future<Map<String, dynamic>?> subirAdjunto({
    required String entidadTipo,
    required String entidadId,
    required String empresaId,
    required String subidoPor,
  }) async {
    return await platform.pickAndUpload(
      entidadTipo: entidadTipo,
      entidadId: entidadId,
      empresaId: empresaId,
      subidoPor: subidoPor,
    );
  }

  static Future<List<Map<String, dynamic>>> listarAdjuntos({
    required String entidadTipo,
    required String entidadId,
  }) async {
    final data = await _supabase
        .from('adjuntos')
        .select()
        .eq('entidad_tipo', entidadTipo)
        .eq('entidad_id', entidadId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<String> urlFirmada(String storagePath) async {
    final response = await _supabase.storage
        .from(_bucket)
        .createSignedUrl(storagePath, 3600);
    return response;
  }

  static Future<void> eliminarAdjunto(Map<String, dynamic> adjunto) async {
    await _supabase.storage
        .from(_bucket)
        .remove([adjunto['storage_path'] as String]);

    await _supabase
        .from('adjuntos')
        .delete()
        .eq('id', adjunto['id']);
  }

  static IconData iconoPorMime(String? mime) {
    if (mime == null) return Icons.insert_drive_file_outlined;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.contains('spreadsheet') || mime.contains('excel')) return Icons.table_chart_outlined;
    if (mime.contains('word') || mime.contains('document')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  static Color colorPorMime(String? mime) {
    if (mime == null) return Colors.grey;
    if (mime.startsWith('image/')) return Colors.blue;
    if (mime == 'application/pdf') return Colors.red;
    if (mime.contains('spreadsheet') || mime.contains('excel')) return Colors.green;
    if (mime.contains('word') || mime.contains('document')) return Colors.indigo;
    return Colors.grey;
  }

  static String formatearTamanio(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}