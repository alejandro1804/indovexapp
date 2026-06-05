// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<Map<String, dynamic>?> pickAndUpload({
  required String entidadTipo,
  required String entidadId,
  required String empresaId,
  required String subidoPor,
}) async {
  // Input file HTML nativo — funciona en todos los browsers
  final input = html.FileUploadInputElement();
  input.accept = '*/*';
  input.click();

  final completer = Completer<html.File?>();
  input.onChange.listen((event) {
    final files = input.files;
    if (files != null && files.isNotEmpty) {
      completer.complete(files.first);
    } else {
      completer.complete(null);
    }
  });

  final file = await completer.future;
  if (file == null) return null;

  // Leer bytes
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;

  final bytes = Uint8List.fromList(reader.result as List<int>);
  final nombreArchivo = file.name;
  final mimeDetectado = lookupMimeType(nombreArchivo);
  final mime = mimeDetectado ?? (file.type.isNotEmpty ? file.type : 'application/octet-stream');
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