import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/egress_service.dart';

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

/// Resultado del chequeo de cuota de almacenamiento.
class EstadoCuota {
  final double usadoMb;
  final double limiteMb;
  final double porcentaje;
  final bool tieneEspacio;

  const EstadoCuota({
    required this.usadoMb,
    required this.limiteMb,
    required this.porcentaje,
    required this.tieneEspacio,
  });
}

/// Excepción lanzada cuando la empresa alcanzó el 100% de su cuota.
/// La UI puede atraparla para mostrar un mensaje amigable en lugar del
/// error crudo de RLS que devolvería el backend.
class StorageQuotaExcedidaException implements Exception {
  final EstadoCuota estado;
  StorageQuotaExcedidaException(this.estado);

  @override
  String toString() =>
      'Almacenamiento lleno (${estado.usadoMb.toStringAsFixed(0)} MB '
      'de ${estado.limiteMb.toStringAsFixed(0)} MB).';
}

class ImageUploadHelper {
  static final _supabase = Supabase.instance.client;
  static const _bucket = 'documentos';
  static final _picker = ImagePicker();

  // Paths cuyo egress ya se registró en esta sesión de la app. Evita contar
  // la misma imagen varias veces por rebuild del widget. Se reinicia al
  // reiniciar la app (dedup por sesión, no persistente).
  static final Set<String> _egressRegistrado = {};

  /// Consulta el uso de almacenamiento de la empresa vía RPC.
  ///
  /// Espejo de la lógica de backend (fn_empresa_tiene_espacio): compara
  /// usado vs límite directamente en vez de confiar en el campo 'porcentaje'
  /// (que puede venir null si el límite es 0). Si la consulta falla, asume
  /// que hay espacio (fail-safe) para no bloquear al usuario por un error
  /// de red; el backend sigue siendo la barrera real.
  static Future<EstadoCuota> verificarEspacio(String empresaId) async {
    try {
      final res = await _supabase.rpc(
        'uso_storage_empresa',
        params: {'p_empresa_id': empresaId},
      );

      final map = (res as Map).cast<String, dynamic>();
      final usado = (map['usado_mb'] as num?)?.toDouble() ?? 0;
      final limite = (map['limite_mb'] as num?)?.toDouble() ?? 0;
      final pctRaw = (map['porcentaje'] as num?)?.toDouble();
      // Recalcular el porcentaje localmente para no depender del backend
      final pct = limite > 0 ? (usado / limite) * 100 : (pctRaw ?? 100);
      final tieneEspacio = limite > 0 && usado < limite;

      return EstadoCuota(
        usadoMb: usado,
        limiteMb: limite,
        porcentaje: pct,
        tieneEspacio: tieneEspacio,
      );
    } catch (_) {
      // Fail-safe: no bloquear en el cliente ante un error de consulta.
      return const EstadoCuota(
        usadoMb: 0,
        limiteMb: 0,
        porcentaje: 0,
        tieneEspacio: true,
      );
    }
  }

  /// Abre el selector de imagen (cámara o galería) y sube al bucket.
  /// Devuelve un record con el path en Storage y el tamaño en bytes del
  /// .webp subido, o null si se canceló.
  ///
  /// El campo `bytes` es el tamaño real del archivo comprimido que se
  /// sube (compressed.length). Se persiste en la tabla vía guardarEnDb
  /// para instrumentar egress y calcular storage almacenado real.
  ///
  /// Lanza [StorageQuotaExcedidaException] si la empresa está al 100% de
  /// su cuota (chequeo previo, para no comprimir/subir en vano).
  static Future<({String path, int bytes})?> pickAndUpload({
    required String tipo,        // 'maquina' | 'repuesto' | 'avatar'
    required String empresaId,
    required String entidadId,   // para avatar: user_id
    ImageSource source = ImageSource.gallery,
  }) async {
    assert(_configs.containsKey(tipo), 'Tipo de imagen no soportado: $tipo');

    // 0. Chequeo de cuota ANTES de abrir el picker (UX: evitar trabajo en vano)
    final cuota = await verificarEspacio(empresaId);
    if (!cuota.tieneEspacio) {
      throw StorageQuotaExcedidaException(cuota);
    }

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

    return (path: path, bytes: compressed.length);
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
    if (result.length > config.maxBytes) {
      result = await FlutterImageCompress.compressWithList(
        result,
        minWidth: config.maxWidth,
        minHeight: config.maxHeight,
        quality: 60,
        format: CompressFormat.webp,
      );
    }

    return result;
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
  ///
  /// [tamanioBytes]: si se provee, registra egress de imagen (una sola vez
  /// por path en esta sesión de la app; dedup interno vía _egressRegistrado).
  /// Los llamadores que no lo pasan no registran nada (retrocompatible).
  static Future<String> signedUrl(String storagePath, {int? tamanioBytes}) async {
    final url = await _supabase.storage.from(_bucket).createSignedUrl(storagePath, 3600);

    // Instrumentación de egress con dedup por sesión: registrar solo la
    // primera vez que se sirve este path en esta ejecución de la app.
    if (tamanioBytes != null &&
        tamanioBytes > 0 &&
        !_egressRegistrado.contains(storagePath)) {
      _egressRegistrado.add(storagePath);
      await EgressService.registrar(EgressOrigen.imagen, tamanioBytes);
    }

    return url;
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
  ///
  /// [tamanioBytes]: tamaño del .webp subido. Solo se persiste para
  /// máquina/repuesto (que tienen columna tamanio_bytes); avatar lo ignora.
  /// Si es null (ej. al borrar), no se toca la columna de tamaño.
  static Future<void> guardarEnDb({
    required String tipo,
    required String entidadId,
    required String path,
    int? tamanioBytes,
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

    final datos = <String, dynamic>{campo: path};
    // Solo máquina/repuesto tienen columna tamanio_bytes; avatar no.
    if (tipo != 'avatar' && tamanioBytes != null) {
      datos['tamanio_bytes'] = tamanioBytes;
    }

    await _supabase.from(tabla).update(datos).eq('id', entidadId);
  }
}