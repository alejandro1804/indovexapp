// Excepciones del flujo de adjuntos.
//
// Viven en un archivo aparte (no en document_helper.dart) para que puedan
// importarlas tanto el router (document_helper.dart) como las
// implementaciones de plataforma (document_helper_mobile/web.dart) sin
// generar un ciclo de imports.

// Se lanza cuando un adjunto que NO es imagen supera el límite de tamaño.
// Las imágenes no la disparan: se comprimen sin importar su tamaño de entrada.
class AdjuntoTamanioExcedidoException implements Exception {
  // Tamaño del archivo rechazado, en bytes.
  final int bytes;

  // Límite máximo permitido, en bytes.
  final int limiteBytes;

  const AdjuntoTamanioExcedidoException(this.bytes, this.limiteBytes);

  double get _mb => bytes / (1024 * 1024);
  double get _limiteMb => limiteBytes / (1024 * 1024);

  @override
  String toString() =>
      'El archivo pesa ${_mb.toStringAsFixed(1)} MB y supera el límite de '
      '${_limiteMb.toStringAsFixed(0)} MB. Subí una versión más liviana.';
}