class Ticket {
  final String id;
  final String empresaId;
  final String maquinaId;
  final String creadoPor;
  final String? tecnicoId;
  final String numero;
  final String estado;
  final String descripcionDesperfecto;
  final String? observacionEncargado;
  final String? observacionTecnico;
  final String? fotoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ticket({
    required this.id,
    required this.empresaId,
    required this.maquinaId,
    required this.creadoPor,
    this.tecnicoId,
    required this.numero,
    required this.estado,
    required this.descripcionDesperfecto,
    this.observacionEncargado,
    this.observacionTecnico,
    this.fotoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Ticket.fromMap(Map<String, dynamic> map) {
    return Ticket(
      id: map['id'],
      empresaId: map['empresa_id'],
      maquinaId: map['maquina_id'],
      creadoPor: map['creado_por'],
      tecnicoId: map['tecnico_id'],
      numero: map['numero'],
      estado: map['estado'],
      descripcionDesperfecto: map['descripcion_desperfecto'],
      observacionEncargado: map['observacion_encargado'],
      observacionTecnico: map['observacion_tecnico'],
      fotoUrl: map['foto_url'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}
