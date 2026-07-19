class Maquina {
  final String id;
  final String empresaId;
  final String sectorId;
  final String nombre;
  final String codigo;
  final String estado;
  final String? descripcion;
  final String? imagenUrl;

  Maquina({
    required this.id,
    required this.empresaId,
    required this.sectorId,
    required this.nombre,
    required this.codigo,
    required this.estado,
    this.descripcion,
    this.imagenUrl,
  });

  factory Maquina.fromMap(Map<String, dynamic> map) {
    return Maquina(
      id: map['id'],
      empresaId: map['empresa_id'],
      sectorId: map['sector_id'],
      nombre: map['nombre'],
      // Código opcional: la DB puede devolver NULL. Lo normalizamos a '' para
      // que el resto de la app lo trate como "sin código" sin nullchecks.
      codigo: map['codigo'] ?? '',
      estado: map['estado'],
      descripcion: map['descripcion'],
      imagenUrl: map['imagen_url'],
    );
  }
}