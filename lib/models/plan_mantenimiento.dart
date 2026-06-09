class PlanMantenimiento {
  final String id;
  final String empresaId;
  final String maquinaId;
  final String descripcionTarea;
  final String tipoIntervalo;
  final double intervaloValor;
  final double? ultimoValorEjecutado;
  final double? proximoValor;
  final bool activo;
  final String? nombreMaquina;
  final String? codigoMaquina;
  final String? procedimiento;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlanMantenimiento({
    required this.id,
    required this.empresaId,
    required this.maquinaId,
    required this.descripcionTarea,
    required this.tipoIntervalo,
    required this.intervaloValor,
    this.ultimoValorEjecutado,
    this.proximoValor,
    required this.activo,
    this.nombreMaquina,
    this.codigoMaquina,
    this.procedimiento,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlanMantenimiento.fromMap(Map<String, dynamic> map) {
    return PlanMantenimiento(
      id: map['id'],
      empresaId: map['empresa_id'],
      maquinaId: map['maquina_id'],
      descripcionTarea: map['descripcion_tarea'],
      tipoIntervalo: map['tipo_intervalo'],
      intervaloValor: (map['intervalo_valor'] as num).toDouble(),
      ultimoValorEjecutado: map['ultimo_valor_ejecutado'] != null
          ? (map['ultimo_valor_ejecutado'] as num).toDouble()
          : null,
      proximoValor: map['proximo_valor'] != null
          ? (map['proximo_valor'] as num).toDouble()
          : null,
      activo: map['activo'] ?? true,
      nombreMaquina: (map['maquinas'] as Map?)?['nombre'] as String?,
      codigoMaquina: (map['maquinas'] as Map?)?['codigo'] as String?,
      procedimiento: map['procedimiento'] as String?,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  String get unidadIntervalo {
    switch (tipoIntervalo) {
      case 'dias': return 'días';
      case 'horas': return 'hs';
      case 'ciclos': return 'ciclos';
      case 'm3': return 'm³';
      default: return tipoIntervalo;
    }
  }
}