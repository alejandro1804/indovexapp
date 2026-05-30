class Repuesto {
  final String id;
  final String empresaId;
  final String? categoriaId;
  final String codigo;
  final String descripcion;
  final int stockActual;
  final int stockMinimo;
  final String? ubicacion;
  final String unidadMedida;
  final String? notas;
  final String? imagenUrl;
  final bool activo;

  Repuesto({
    required this.id,
    required this.empresaId,
    this.categoriaId,
    required this.codigo,
    required this.descripcion,
    required this.stockActual,
    required this.stockMinimo,
    this.ubicacion,
    required this.unidadMedida,
    this.notas,
    this.imagenUrl,
    required this.activo,
  });

  bool get stockBajo => stockActual <= stockMinimo;

  factory Repuesto.fromMap(Map<String, dynamic> map) {
    return Repuesto(
      id: map['id'],
      empresaId: map['empresa_id'],
      categoriaId: map['categoria_id'],
      codigo: map['codigo'],
      descripcion: map['descripcion'],
      stockActual: map['stock_actual'],
      stockMinimo: map['stock_minimo'],
      ubicacion: map['ubicacion'],
      unidadMedida: map['unidad_medida'],
      notas: map['notas'],
      imagenUrl: map['imagen_url'],
      activo: map['activo'],
    );
  }
}
