import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<Map<String, dynamic>?> pickAndUpload({
  required String entidadTipo,
  required String entidadId,
  required String empresaId,
  required String subidoPor,
}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    withData: false,
    withReadStream: false,
  );
  if (result == null || result.files.isEmpty) return null;

  final picked = result.files.first;
  if (picked.path == null) return null;

  final bytes = await File(picked.path!).readAsBytes();
  final nombreArchivo = picked.name;
  final mime = lookupMimeType(picked.path!) ?? 'application/octet-stream';
  final tamanio = bytes.length;
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final storagePath = '$empresaId/$entidadTipo/$entidadId/${timestamp}_$nombreArchivo';

  await Supabase.instance.client.storage
      .from('documentos')
      .uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(contentType: mime, upsert: false),
      );

  final inserted = await Supabase.instance.client
      .from('adjuntos')
      .insert({
        'empresa_id': empresaId,
        'entidad_tipo': entidadTipo,
        'entidad_id': entidadId,
        'nombre_archivo': nombreArchivo,
        'tipo_mime': mime,
        'tamanio_bytes': tamanio,
        'storage_path': storagePath,
        'subido_por': subidoPor,
      })
      .select()
      .single();

  return inserted;
}