import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Configuración de compresión por tipo de entidad
class _ImageConfig {
  final int maxWidth;
  final int maxHeight;
  final int quality;
  final int maxBytes;

  const _ImageConfig({
    required this.maxWidth,
    required this.maxHeight,
    required this.quality,
    required this.maxBytes,
  });
}

const _configs = {
  'maquina': _ImageConfig(maxWidth: 1200, maxHeight: 1200, quality: 82, maxBytes: 300000),
  'repuesto': _ImageConfig(maxWidth: 800, maxHeight: 800, quality: 80, maxBytes: 200000),
  'avatar': _ImageConfig(maxWidth: 400, maxHeight: 400, quality: 78, maxBytes: 80000),
};

class ImageUploadHelper {
  static final _supabase = Supabase.instance.client;
  static const _bucket = 'documentos';
  static final _picker = ImagePicker();

  /// Abre el selector de imagen (cámara o galería) y sube al bucket.
  /// Devuelve el path en Storage si tuvo éxito, null si se canceló.
  static Future<String?> pickAndUpload({
    required String tipo,        // 'maquina' | 'repuesto' | 'avatar'
    required String empresaId,
    required String entidadId,   // para avatar: user_id
    ImageSource source = ImageSource.gallery,
  }) async {
    assert(_configs.containsKey(tipo), 'Tipo de imagen no soportado: $tipo');

    // 1. Seleccionar imagen
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 90, // pre-reducción antes de comprimir
    );
    if (picked == null) return null;

    // 2. Leer bytes
    final Uint8List originalBytes = await picked.readAsBytes();

    // 3. Comprimir
    final Uint8List compressed = await _comprimir(originalBytes, tipo);

    // 4. Construir path y subir
    final path = _buildPath(tipo, empresaId, entidadId);
    await _supabase.storage.from(_bucket).uploadBinary(
      path,
      compressed,
      fileOptions: const FileOptions(
        contentType: 'image/webp',
        upsert: true, // reemplaza si ya existe
      ),
    );

    return path;
  }

  /// Comprime a WebP respetando los límites de la config.
  static Future<Uint8List> _comprimir(Uint8List bytes, String tipo) async {
    final config = _configs[tipo]!;

    if (kIsWeb) {
      // flutter_image_compress no soporta Web — devolver bytes originales.
      // En web la compresión es responsabilidad del navegador vía image_picker.
      return bytes;
    }

    Uint8List? result = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: config.maxWidth,
      minHeight: config.maxHeight,
      quality: config.quality,
      format: CompressFormat.webp,
    );

    // Si sigue por encima del límite, re-comprimir con calidad menor
    if (result != null && result.length > config.maxBytes) {
      result = await FlutterImageCompress.compressWithList(
        result,
        minWidth: config.maxWidth,
        minHeight: config.maxHeight,
        quality: 60,
        format: CompressFormat.webp,
      );
    }

    return result ?? bytes;
  }

    /// Path determinista: siempre el mismo por entidad → upsert reemplaza sin acumular huérfanos.
      ///
      /// Patrón unificado (empresa_id siempre primer segmento, igual que adjuntos):
      ///   {empresaId}/{maquina|repuesto|usuario}/{entidadId}/portada/{entidadId}.webp
      static String _buildPath(String tipo, String empresaId, String entidadId) {
        return switch (tipo) {
          'maquina'  => '$empresaId/maquina/$entidadId/portada/$entidadId.webp',
          'repuesto' => '$empresaId/repuesto/$entidadId/portada/$entidadId.webp',
          'avatar'   => '$empresaId/usuario/$entidadId/portada/$entidadId.webp',
          _          => throw ArgumentError('tipo inválido: $tipo'),
        };
      }

  /// Genera una signed URL con 1 hora de vigencia.
  static Future<String> signedUrl(String storagePath) async {
    return await _supabase.storage.from(_bucket).createSignedUrl(storagePath, 3600);
  }

  /// Elimina la foto del bucket (no falla si no existe).
  static Future<void> eliminar(String storagePath) async {
    try {
      await _supabase.storage.from(_bucket).remove([storagePath]);
    } catch (_) {
      // Ignorar si no existía
    }
  }

  /// Guarda el path en la tabla correspondiente.
  static Future<void> guardarEnDb({
    required String tipo,
    required String entidadId,
    required String path,
  }) async {
    final tabla = switch (tipo) {
      'maquina'  => 'maquinas',
      'repuesto' => 'repuestos',
      'avatar'   => 'usuarios',
      _          => throw ArgumentError('tipo inválido: $tipo'),
    };
    final campo = switch (tipo) {
      'maquina'  => 'imagen_url',
      'repuesto' => 'imagen_url',
      'avatar'   => 'avatar_path',
      _          => throw ArgumentError('tipo inválido: $tipo'),
    };

    await _supabase.from(tabla).update({campo: path}).eq('id', entidadId);
  }
}