class AuditLog {
  final int id;
  final String tabla;
  final String operacion; // INSERT | UPDATE | DELETE
  final String registroId;
  final String? empresaId;
  final String? usuarioId;
  final Map<String, dynamic>? datosAntes;
  final Map<String, dynamic>? datosDespues;
  final String? ip;
  final DateTime createdAt;

  // Join opcional
  final String? nombreUsuario;

  AuditLog({
    required this.id,
    required this.tabla,
    required this.operacion,
    required this.registroId,
    this.empresaId,
    this.usuarioId,
    this.datosAntes,
    this.datosDespues,
    this.ip,
    required this.createdAt,
    this.nombreUsuario,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'],
      tabla: map['tabla'],
      operacion: map['operacion'],
      registroId: map['registro_id'].toString(),
      empresaId: map['empresa_id'],
      usuarioId: map['usuario_id'],
      datosAntes: map['datos_antes'] != null
          ? Map<String, dynamic>.from(map['datos_antes'])
          : null,
      datosDespues: map['datos_despues'] != null
          ? Map<String, dynamic>.from(map['datos_despues'])
          : null,
      ip: map['ip'],
      createdAt: DateTime.parse(map['created_at']),
      nombreUsuario: (map['usuarios'] as Map?)?['nombre'] as String?,
    );
  }

  // Etiqueta legible de la tabla
  String get tablaLabel {
    switch (tabla) {
      case 'tickets': return 'Tickets';
      case 'ticket_historial': return 'Historial de tickets';
      case 'maquinas': return 'Máquinas';
      case 'repuestos': return 'Repuestos';
      case 'ingreso_repuestos': return 'Ingresos de stock';
      case 'salida_repuestos': return 'Salidas de stock';
      case 'planes_mantenimiento': return 'Planes de mantenimiento';
      case 'lecturas_maquina': return 'Lecturas de máquina';
      case 'tipos_intervalo': return 'Tipos de intervalo';
      case 'usuarios': return 'Usuarios';
      case 'roles': return 'Roles';
      case 'rol_permisos': return 'Permisos de roles';
      case 'sectores': return 'Ubicaciones';
      case 'categorias_repuestos': return 'Categorías de repuestos';
      case 'proveedores': return 'Proveedores';
      case 'repuestos_maquinas': return 'Vínculos repuesto-máquina';
      case 'usuario_sector': return 'Asignación de ubicaciones';
      case 'empresas': return 'Empresa';
      default: return tabla;
    }
  }

  String get operacionLabel {
    switch (operacion) {
      case 'INSERT': return 'Creación';
      case 'UPDATE': return 'Modificación';
      case 'DELETE': return 'Eliminación';
      default: return operacion;
    }
  }
}