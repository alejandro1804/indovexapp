class Usuario {
  final String id;
  final String empresaId;
  final String rolId;
  final String nombre;
  final String email;
  final String? telefono;
  final String estado;
  final String rolNombre;
  final bool primerLogin;
  final bool esSuperAdmin;
  final bool restringePorSector;
  final List<String> permisos;

  Usuario({
    required this.id,
    required this.empresaId,
    required this.rolId,
    required this.nombre,
    required this.email,
    this.telefono,
    required this.estado,
    required this.rolNombre,
    required this.primerLogin,
    required this.esSuperAdmin,
    this.restringePorSector = false,
    this.permisos = const [],
  });

  factory Usuario.fromMap(Map<String, dynamic> map, {List<String> permisos = const []}) {
    return Usuario(
      id: map['id'],
      empresaId: map['empresa_id'],
      rolId: map['rol_id'] ?? '',
      nombre: map['nombre'],
      email: map['email'],
      telefono: map['telefono'],
      estado: map['estado'],
      rolNombre: map['roles']?['nombre'] ?? '',
      primerLogin: map['primer_login'] ?? false,
      esSuperAdmin: map['es_super_admin'] ?? false,
      restringePorSector: map['roles']?['restringe_por_sector'] ?? false,
      permisos: permisos,
    );
  }

  /// Verifica si el usuario tiene un permiso específico.
  /// El super admin siempre tiene todos los permisos.
  bool tienePermiso(String codigo) {
    if (esSuperAdmin) return true;
    return permisos.contains(codigo);
  }

  // Getters de rol: se usan para lógica de filtrado por identidad
  // (ej: el técnico ve solo sus tickets, el encargado los de su sector).
  // NO usar para permisos de acción — para eso está tienePermiso().
  bool get esAdmin => rolNombre == 'admin';
  bool get esEncargado => rolNombre == 'encargado';
  bool get esTecnico => rolNombre == 'tecnico';
  bool get esOperario => rolNombre == 'operario';
  bool get esShopper => rolNombre == 'shopper';
  bool get esSupervisor => rolNombre == 'supervisor';

  /// true si el usuario puede obligar contractualmente a su empresa
  /// (T&C cl. 1: el Cliente es la persona jurídica).
  ///
  /// Espeja es_admin_empresa() en DB. A diferencia del resto de los
  /// chequeos, NO usa tienePermiso() a propósito: el super admin tiene
  /// todos los permisos, pero no acepta documentos legales en nombre
  /// de un cliente.
  bool get esAdminEmpresa {
    if (esSuperAdmin) return false;
    return permisos.contains('gestionar_usuarios') &&
           permisos.contains('gestionar_roles');
  }
}