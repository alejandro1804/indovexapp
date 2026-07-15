class DocumentoLegal {
  final String id;
  final String documento;      // 'tyc' | 'privacidad'
  final String version;
  final DateTime fechaPublicacion;
  final DateTime fechaVigencia;
  final String url;
  final String? resumenCambios;
  final bool bloqueante;
  final bool enPreaviso;
  final int diasRestantes;

  DocumentoLegal({
    required this.id,
    required this.documento,
    required this.version,
    required this.fechaPublicacion,
    required this.fechaVigencia,
    required this.url,
    this.resumenCambios,
    required this.bloqueante,
    required this.enPreaviso,
    required this.diasRestantes,
  });

  factory DocumentoLegal.fromMap(Map<String, dynamic> map) {
    return DocumentoLegal(
      id: map['documento_legal_id'],
      documento: map['documento'],
      version: map['version'],
      fechaPublicacion: DateTime.parse(map['fecha_publicacion']),
      fechaVigencia: DateTime.parse(map['fecha_vigencia']),
      url: map['url'],
      resumenCambios: map['resumen_cambios'],
      bloqueante: map['bloqueante'] ?? false,
      enPreaviso: map['en_preaviso'] ?? false,
      diasRestantes: map['dias_restantes'] ?? 0,
    );
  }

  /// Nombre legible para mostrar al usuario.
  String get titulo => documento == 'tyc'
      ? 'Términos y Condiciones de Uso'
      : 'Política de Privacidad';

  String get tituloCorto => documento == 'tyc' ? 'T&C' : 'Privacidad';
}