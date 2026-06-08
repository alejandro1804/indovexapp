class TipoIntervalo {
  final String id;
  final String empresaId;
  final String nombre;
  final String codigo;
  final bool activo;
  final bool esDefault;
  final DateTime createdAt;

  TipoIntervalo({
    required this.id,
    required this.empresaId,
    required this.nombre,
    required this.codigo,
    required this.activo,
    required this.esDefault,
    required this.createdAt,
  });

  factory TipoIntervalo.fromMap(Map<String, dynamic> map) {
    return TipoIntervalo(
      id: map['id'],
      empresaId: map['empresa_id'],
      nombre: map['nombre'],
      codigo: map['codigo'],
      activo: map['activo'] ?? true,
      esDefault: map['es_default'] ?? false,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}