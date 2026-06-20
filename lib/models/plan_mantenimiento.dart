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

  // Umbral para detectar epoch en milisegundos.
  // ~1e12 ms ≈ año 2001; cualquier "cantidad de días" real será mucho menor.
  static const double _umbralEpochMs = 1e11;

  // Formatea un número con separador de miles (punto) — convención es-UY.
  // Ej: 12500 -> "12.500", 12500.5 -> "12.500,5"
  static String _formatearNumero(double valor) {
    final esEntero = valor.truncateToDouble() == valor;
    final parteEntera = valor.truncate().abs();
    final decimales = esEntero ? '' : ',${(valor.abs() - parteEntera).toStringAsFixed(1).substring(2)}';

    final str = parteEntera.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    final signo = valor.isNegative ? '-' : '';
    return '$signo${buffer.toString()}$decimales';
  }

  static String _dos(int n) => n.toString().padLeft(2, '0');

  // Etiqueta legible del próximo mantenimiento, según el tipo de intervalo.
  // - dias: si el valor parece epoch en ms, lo muestra como fecha dd/mm/aaaa.
  //         si es un número chico, lo muestra como cantidad de días.
  // - horas/ciclos/m3/km: número con separador de miles + unidad.
  // Devuelve null si no hay próximo valor cargado.
  String? get proximoLabel {
    final v = proximoValor;
    if (v == null) return null;

    if (tipoIntervalo == 'dias') {
      if (v >= _umbralEpochMs) {
        final fecha = DateTime.fromMillisecondsSinceEpoch(v.toInt()).toLocal();
        return '${_dos(fecha.day)}/${_dos(fecha.month)}/${fecha.year}';
      }
      return '${_formatearNumero(v)} $unidadIntervalo';
    }

    return '${_formatearNumero(v)} $unidadIntervalo';
  }

  // Etiqueta de la frecuencia: "Cada X <unidad>".
  String get frecuenciaLabel => 'Cada ${_formatearNumero(intervaloValor)} $unidadIntervalo';
}