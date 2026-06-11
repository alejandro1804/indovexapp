class RepuestoMaquina {
  final String id;
  final String repuestoId;
  final String maquinaId;
  final int cantidad;
  final String? ubicacionEnMaquina;
  final String? observacion;
  final DateTime createdAt;

  // Datos del join (opcionales según desde dónde se consulte)
  final String? repuestoCodigo;
  final String? repuestoDescripcion;
  final String? maquinaNombre;
  final String? maquinaCodigo;

  RepuestoMaquina({
    required this.id,
    required this.repuestoId,
    required this.maquinaId,
    required this.cantidad,
    this.ubicacionEnMaquina,
    this.observacion,
    required this.createdAt,
    this.repuestoCodigo,
    this.repuestoDescripcion,
    this.maquinaNombre,
    this.maquinaCodigo,
  });

  factory RepuestoMaquina.fromMap(Map<String, dynamic> map) {
    return RepuestoMaquina(
      id: map['id'],
      repuestoId: map['repuesto_id'],
      maquinaId: map['maquina_id'],
      cantidad: map['cantidad'] ?? 1,
      ubicacionEnMaquina: map['ubicacion_en_maquina'],
      observacion: map['observacion'],
      createdAt: DateTime.parse(map['created_at']),
      repuestoCodigo: (map['repuestos'] as Map?)?['codigo'] as String?,
      repuestoDescripcion: (map['repuestos'] as Map?)?['descripcion'] as String?,
      maquinaNombre: (map['maquinas'] as Map?)?['nombre'] as String?,
      maquinaCodigo: (map['maquinas'] as Map?)?['codigo'] as String?,
    );
  }
}