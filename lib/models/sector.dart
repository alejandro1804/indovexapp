class Sector {
  final String id;
  final String empresaId;
  final String nombre;
  final String? descripcion;

  Sector({
    required this.id,
    required this.empresaId,
    required this.nombre,
    this.descripcion,
  });

  factory Sector.fromMap(Map<String, dynamic> map) {
    return Sector(
      id: map['id'],
      empresaId: map['empresa_id'],
      nombre: map['nombre'],
      descripcion: map['descripcion'],
    );
  }
}
