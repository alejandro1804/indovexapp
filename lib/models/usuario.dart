class Usuario {
  final String id;
  final String empresaId;
  final String rolId;
  final String nombre;
  final String email;
  final String estado;
  final String rolNombre;
  final bool primerLogin;

  Usuario({
    required this.id,
    required this.empresaId,
    required this.rolId,
    required this.nombre,
    required this.email,
    required this.estado,
    required this.rolNombre,
    required this.primerLogin,
  });

  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'],
      empresaId: map['empresa_id'],
      rolId: map['rol_id'],
      nombre: map['nombre'],
      email: map['email'],
      estado: map['estado'],
      rolNombre: map['roles']?['nombre'] ?? '',
      primerLogin: map['primer_login'] ?? false,
    );
  }

  bool get esAdmin => rolNombre == 'admin';
  bool get esEncargado => rolNombre == 'encargado';
  bool get esTecnico => rolNombre == 'tecnico';
  bool get esOperario => rolNombre == 'operario';
  bool get esShopper => rolNombre == 'shopper';
  bool get esSupervisor => rolNombre == 'supervisor';

  bool get puedeVerStock => esAdmin || esEncargado || esTecnico || esShopper || esSupervisor;
  bool get puedeGestionarStock => esAdmin || esEncargado || esShopper;
  bool get puedeAsignarTickets => esAdmin || esEncargado;
  bool get puedeGestionarUsuarios => esAdmin;
}