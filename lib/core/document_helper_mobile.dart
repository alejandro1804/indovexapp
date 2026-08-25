import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

// Límites de compresión para ADJUNTOS (más generosos que las portadas:
// un adjunto puede ser una foto de detalle que el técnico necesita leer,
// no un simple thumbnail).
//
// Se usa JPEG (no WebP) a propósito: el encoder WebP nativo de Android se
// cuelga con imágenes grandes de galería. JPEG comprime casi igual de bien
// para fotos y su encoder es rápido y estable.
const int _adjImgMaxLado = 1600;    // px máximo del lado mayor
const int _adjImgQuality = 85;      // calidad JPEG inicial
const int _adjImgMaxBytes = 800000; // ~800 KB; si supera, recomprime a menor calidad
const int _adjImgQualityBaja = 65;  // segunda pasada si sigue muy grande

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

  Uint8List bytes = await File(picked.path!).readAsBytes();
  String nombreArchivo = picked.name;
  String mime = lookupMimeType(picked.path!) ?? 'application/octet-stream';

  // Si es imagen, comprimir a JPEG antes de subir. Otros tipos (PDF, doc,
  // planilla) se suben tal cual, sin tocarlos.
  if (mime.startsWith('image/')) {
    final comprimido = await _comprimirImagen(bytes);
    if (comprimido != null) {
      bytes = comprimido;
      mime = 'image/jpeg';
      // Cambiar la extensión del nombre visible a .jpg, conservando el resto.
      final sinExt = p.basenameWithoutExtension(nombreArchivo);
      nombreArchivo = '$sinExt.jpg';
    }
    // Si la compresión falla (comprimido == null), se sube el original intacto.
  }

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

/// Comprime una imagen a JPEG. Devuelve null si la compresión falla o tarda
/// demasiado, para que el caller suba el original sin romperse ni colgarse.
Future<Uint8List?> _comprimirImagen(Uint8List original) async {
  try {
    Uint8List? result = await FlutterImageCompress.compressWithList(
      original,
      minWidth: _adjImgMaxLado,
      minHeight: _adjImgMaxLado,
      quality: _adjImgQuality,
      format: CompressFormat.jpeg,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => original, // si se cuelga, seguimos con el original
    );

    if (result.length > _adjImgMaxBytes) {
      final previa = result; // no-nullable para el onTimeout de abajo
      result = await FlutterImageCompress.compressWithList(
        previa,
        minWidth: _adjImgMaxLado,
        minHeight: _adjImgMaxLado,
        quality: _adjImgQualityBaja,
        format: CompressFormat.jpeg,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => previa,
      );
    }

    // Seguridad: si por lo que sea el "comprimido" salió más grande que el
    // original (imágenes ya muy optimizadas), quedarse con el original.
    if (result.length < original.length) {
      return result;
    }
    return null;
  } catch (_) {
    return null;
  }
}