class Proveedor {
  final String id;
  final String empresaId;
  final String nombre;
  final String? rut;
  final String? contacto;
  final String? telefono;
  final String? email;
  final bool activo;

  Proveedor({
    required this.id,
    required this.empresaId,
    required this.nombre,
    this.rut,
    this.contacto,
    this.telefono,
    this.email,
    required this.activo,
  });

  factory Proveedor.fromMap(Map<String, dynamic> map) {
    return Proveedor(
      id: map['id'],
      empresaId: map['empresa_id'],
      nombre: map['nombre'],
      rut: map['rut'],
      contacto: map['contacto'],
      telefono: map['telefono'],
      email: map['email'],
      activo: map['activo'],
    );
  }
}
