class LecturaMaquina {
  final String id;
  final String empresaId;
  final String maquinaId;
  final String tipo; // 'horas' | 'ciclos' | 'm3'
  final double valor;
  final DateTime fechaLectura;
  final String registradoPor;
  final String? observacion;
  final DateTime createdAt;

  LecturaMaquina({
    required this.id,
    required this.empresaId,
    required this.maquinaId,
    required this.tipo,
    required this.valor,
    required this.fechaLectura,
    required this.registradoPor,
    this.observacion,
    required this.createdAt,
  });

  factory LecturaMaquina.fromMap(Map<String, dynamic> map) {
    return LecturaMaquina(
      id: map['id'],
      empresaId: map['empresa_id'],
      maquinaId: map['maquina_id'],
      tipo: map['tipo'],
      valor: (map['valor'] as num).toDouble(),
      fechaLectura: DateTime.parse(map['fecha_lectura']),
      registradoPor: map['registrado_por'],
      observacion: map['observacion'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  String get unidad {
    switch (tipo) {
      case 'horas': return 'hs';
      case 'ciclos': return 'ciclos';
      case 'm3': return 'm³';
      default: return tipo;
    }
  }
}