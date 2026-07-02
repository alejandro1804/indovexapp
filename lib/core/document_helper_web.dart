// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

// Límites de compresión para ADJUNTOS en web (equivalentes a los de mobile).
const int _adjImgMaxLado = 1600;      // px máximo del lado mayor
const double _adjImgQuality = 0.85;   // calidad WebP inicial (0..1)
const int _adjImgMaxBytes = 800000;   // ~800 KB; si supera, recomprime
const double _adjImgQualityBaja = 0.65;

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

  // Leer bytes originales
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;

  Uint8List bytes = Uint8List.fromList(reader.result as List<int>);
  String nombreArchivo = file.name;
  final mimeDetectado = lookupMimeType(nombreArchivo);
  String mime = mimeDetectado ??
      (file.type.isNotEmpty ? file.type : 'application/octet-stream');

  // Si es imagen, comprimir a WebP con canvas antes de subir.
  // Otros tipos (PDF, doc, planilla) se suben tal cual.
  if (mime.startsWith('image/')) {
    final comprimido = await _comprimirImagenWeb(bytes, mime);
    if (comprimido != null && comprimido.length < bytes.length) {
      bytes = comprimido;
      mime = 'image/webp';
      final sinExt = p.basenameWithoutExtension(nombreArchivo);
      nombreArchivo = '$sinExt.webp';
    }
    // Si falla o no reduce, se sube el original intacto.
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

/// Comprime una imagen usando el <canvas> del navegador.
/// Redimensiona al lado máximo y exporta a WebP con calidad reducida.
/// Devuelve null si algo falla, para que el caller suba el original.
Future<Uint8List?> _comprimirImagenWeb(Uint8List original, String mimeOriginal) async {
  String? objectUrl;
  try {
    // 1. Cargar la imagen desde un blob URL.
    final blob = html.Blob([original], mimeOriginal);
    objectUrl = html.Url.createObjectUrlFromBlob(blob);
    final img = html.ImageElement(src: objectUrl);
    await img.onLoad.first;

    final wOrig = img.naturalWidth;
    final hOrig = img.naturalHeight;
    if (wOrig == 0 || hOrig == 0) return null;

    // 2. Calcular dimensiones destino, respetando el lado máximo.
    double escala = 1.0;
    final ladoMayor = wOrig > hOrig ? wOrig : hOrig;
    if (ladoMayor > _adjImgMaxLado) {
      escala = _adjImgMaxLado / ladoMayor;
    }
    final wDest = (wOrig * escala).round();
    final hDest = (hOrig * escala).round();

    // 3. Dibujar en canvas redimensionado.
    final canvas = html.CanvasElement(width: wDest, height: hDest);
    final ctx = canvas.context2D;
    ctx.drawImageScaled(img, 0, 0, wDest, hDest);

    // 4. Exportar a WebP (primera pasada).
    Uint8List? result = await _canvasToWebp(canvas, _adjImgQuality);

    // 5. Si sigue muy grande, segunda pasada con menor calidad.
    if (result != null && result.length > _adjImgMaxBytes) {
      final result2 = await _canvasToWebp(canvas, _adjImgQualityBaja);
      if (result2 != null) result = result2;
    }

    return result;
  } catch (_) {
    return null;
  } finally {
    if (objectUrl != null) html.Url.revokeObjectUrl(objectUrl);
  }
}

/// Exporta el contenido de un canvas a bytes WebP con la calidad dada.
Future<Uint8List?> _canvasToWebp(html.CanvasElement canvas, double quality) async {
  try {
    final blob = await canvas.toBlob('image/webp', quality);
    // Si el navegador no soporta WebP en toBlob, devuelve PNG u otro; igual
    // lo aceptamos porque suele ser más chico que el original de cámara.
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoad.first;
    return Uint8List.fromList(reader.result as List<int>);
  } catch (_) {
    return null;
  }
}