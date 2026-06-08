class Ticket {
  final String id;
  final String empresaId;
  final String maquinaId;
  final String creadoPor;
  final String? tecnicoId;
  final String numero;
  final String estado;
  final String tipo;
  final String prioridad;
  final String descripcionDesperfecto;
  final String? observacionEncargado;
  final String? observacionTecnico;
  final String? fotoUrl;
  final DateTime? fechaProgramada;
  final DateTime? fechaCierre;
  final String? planId;
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
    required this.tipo,
    required this.prioridad,
    required this.descripcionDesperfecto,
    this.observacionEncargado,
    this.observacionTecnico,
    this.fotoUrl,
    this.fechaProgramada,
    this.fechaCierre,
    this.planId,
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
      tipo: map['tipo'] ?? 'correctivo',
      prioridad: map['prioridad'] ?? 'media',
      descripcionDesperfecto: map['descripcion_desperfecto'],
      observacionEncargado: map['observacion_encargado'],
      observacionTecnico: map['observacion_tecnico'],
      fotoUrl: map['foto_url'],
      fechaProgramada: map['fecha_programada'] != null
          ? DateTime.parse(map['fecha_programada'])
          : null,
      fechaCierre: map['fecha_cierre'] != null
          ? DateTime.parse(map['fecha_cierre'])
          : null,
      planId: map['plan_id'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}