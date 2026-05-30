class CategoriaRepuesto {
  final String id;
  final String empresaId;
  final String nombre;
  final String? descripcion;

  CategoriaRepuesto({
    required this.id,
    required this.empresaId,
    required this.nombre,
    this.descripcion,
  });

  factory CategoriaRepuesto.fromMap(Map<String, dynamic> map) {
    return CategoriaRepuesto(
      id: map['id'],
      empresaId: map['empresa_id'],
      nombre: map['nombre'],
      descripcion: map['descripcion'],
    );
  }
}
