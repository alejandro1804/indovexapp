import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:functions_client/functions_client.dart' show FunctionException;
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';
import '../../core/db_error_helper.dart';
import 'destinatarios_whatsapp_screen.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _roles = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final usuariosData = await _supabase
          .from('usuarios')
          .select('*, roles(nombre, restringe_por_sector)')
          .order('nombre');
      final rolesData = await _supabase
          .from('roles')
          .select('id, nombre, restringe_por_sector')
          .order('nombre');
      setState(() {
        _usuarios = List<Map<String, dynamic>>.from(usuariosData);
        _roles = List<Map<String, dynamic>>.from(rolesData);
      });
    } catch (e) {
      _mostrarError('Error al cargar usuarios: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  /// Devuelve true si el rol indicado (por id) restringe por sector.
  bool _rolRestringe(String? rolId) {
    if (rolId == null) return false;
    final rol = _roles.firstWhere(
      (r) => r['id'] == rolId,
      orElse: () => const {},
    );
    return rol['restringe_por_sector'] == true;
  }

  Future<void> _mostrarFormularioNuevo() async {
    final emailController = TextEditingController();
    final nombreController = TextEditingController();
    final telefonoController = TextEditingController();
    final passwordController = TextEditingController();
    String? rolSeleccionado = _roles.isNotEmpty ? _roles.first['id'] : null;
    bool verPassword = false;

    // Sectores disponibles + selección para el alta.
    List<Map<String, dynamic>> sectores = [];
    final Set<String> sectoresElegidos = {};
    try {
      final sectoresData =
          await _supabase.from('sectores').select('id, nombre').order('nombre');
      sectores = List<Map<String, dynamic>>.from(sectoresData);
    } catch (_) {
      // Si falla la carga de sectores, seguimos: el selector solo aplica a roles
      // que restringen, y en ese caso el guard de "Crear" avisará.
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final rolRestringe = _rolRestringe(rolSeleccionado);
          return AlertDialog(
            title: const Text('Nuevo Usuario'),
            content: SizedBox(
              width: Responsive.isDesktop(context) ? 480 : double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                          labelText: 'Nombre *',
                          labelStyle: TextStyle(fontSize: 13),
                          border: OutlineInputBorder()),
                      textCapitalization: TextCapitalization.words,
                      maxLength: 100,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                          labelText: 'Email *',
                          labelStyle: TextStyle(fontSize: 13),
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 255,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: telefonoController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Teléfono (WhatsApp)',
                        labelStyle: TextStyle(fontSize: 13),
                        border: OutlineInputBorder(),
                        hintText: '+598XXXXXXXX',
                        hintStyle: TextStyle(fontSize: 12),
                      ),
                      keyboardType: TextInputType.phone,
                      maxLength: 20,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      style: const TextStyle(fontSize: 13),
                      obscureText: !verPassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña temporal *',
                        labelStyle: const TextStyle(fontSize: 13),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                              verPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey,
                              size: 20),
                          onPressed: () => setDialogState(
                              () => verPassword = !verPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: rolSeleccionado,
                      isExpanded: true,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87),
                      decoration: const InputDecoration(
                          labelText: 'Rol *',
                          labelStyle: TextStyle(fontSize: 13),
                          border: OutlineInputBorder()),
                      items: _roles
                          .map((r) => DropdownMenuItem(
                              value: r['id'] as String,
                              child: Text(r['nombre'] as String,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => rolSeleccionado = v),
                    ),
                    // Selector de sectores: solo si el rol elegido restringe.
                    if (rolRestringe) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Sectores asignados *',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800]),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Este rol solo verá los sectores que elijas.',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (sectores.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: Colors.orange[200]!)),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_outlined,
                                  color: Colors.orange[700], size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      'No hay sectores creados. Creá sectores antes de asignar este rol.',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange[800]))),
                            ],
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8)),
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: sectores.map((s) {
                                final id = s['id'] as String;
                                return CheckboxListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  title: Text(s['nombre'],
                                      style: const TextStyle(fontSize: 12)),
                                  value: sectoresElegidos.contains(id),
                                  activeColor: const Color(0xFF1F4E79),
                                  onChanged: (v) => setDialogState(() {
                                    if (v == true) {
                                      sectoresElegidos.add(id);
                                    } else {
                                      sectoresElegidos.remove(id);
                                    }
                                  }),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!)),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue[700], size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                                  'El usuario deberá cambiar su contraseña al primer ingreso.',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue[700]))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar')),
              ElevatedButton(
                // Bloqueado si el rol restringe y no hay sectores elegidos.
                onPressed: (rolRestringe && sectoresElegidos.isEmpty)
                    ? null
                    : () async {
                        final nombre =
                            normalizarTexto(nombreController.text);
                        final email = normalizarEmail(emailController.text);
                        final telefono = telefonoController.text.trim();
                        final password = passwordController.text.trim();
                        if (email.isEmpty ||
                            nombre.isEmpty ||
                            password.isEmpty ||
                            rolSeleccionado == null) {
                          return;
                        }
                        if (!esEmailValido(email)) {
                          _mostrarError(
                              'El email ingresado no tiene un formato válido.');
                          return;
                        }
                        if (telefono.isNotEmpty &&
                            !_esTelefonoValido(telefono)) {
                          _mostrarError(
                              'El teléfono debe tener formato internacional, ej: +59899668216');
                          return;
                        }
                        Navigator.pop(context);
                        await _crearUsuario(
                          email: email,
                          nombre: nombre,
                          password: password,
                          rolId: rolSeleccionado!,
                          telefono: telefono.isEmpty ? null : telefono,
                          sectores: rolRestringe
                              ? sectoresElegidos.toList()
                              : const [],
                        );
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F4E79),
                    foregroundColor: Colors.white),
                child: const Text('Crear'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Valida formato internacional básico: + seguido de 8 a 15 dígitos.
  bool _esTelefonoValido(String telefono) {
    final regex = RegExp(r'^\+\d{8,15}$');
    return regex.hasMatch(telefono);
  }

  Future<void> _crearUsuario({
    required String email,
    required String nombre,
    required String password,
    required String rolId,
    String? telefono,
    List<String> sectores = const [],
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'crear_usuario',
        body: {
          'email': email,
          'password': password,
          'nombre': nombre,
          'rol_id': rolId,
        },
      );

      final data = response.data;
      if (data != null && data['success'] == true) {
        final nuevoId = data['usuario_id'] ?? data['id'];

        // Teléfono (si se cargó).
        if (telefono != null && nuevoId != null) {
          try {
            await _supabase
                .from('usuarios')
                .update({'telefono': telefono}).eq('id', nuevoId);
          } catch (_) {
            // Si falla solo el teléfono, no bloqueamos la creación.
          }
        }

        // Sectores asignados (solo si el rol restringe y se eligieron).
        if (sectores.isNotEmpty && nuevoId != null) {
          try {
            final filas = sectores
                .map((sectorId) => {
                      'usuario_id': nuevoId,
                      'sector_id': sectorId,
                    })
                .toList();
            await _supabase.from('usuario_sector').insert(filas);
          } catch (_) {
            // Usuario creado pero falló la asignación: avisamos para que el
            // admin la complete desde el menú "Asignar sectores".
            _mostrarError(
                'Usuario creado, pero no se pudieron asignar los sectores. Asignalos desde el menú del usuario.');
          }
        }

        _mostrarExito('Usuario creado correctamente');
        await _cargarDatos();
      } else {
        final mensaje =
            (data?['error'] ?? 'Error desconocido al crear usuario')
                .toString();
        _mostrarError(
            mensajeAmigableDesdeTexto(mensaje, entidad: 'usuario'));
      }
    } catch (e) {
      String mensaje = 'Error al crear usuario';
      if (e is FunctionException) {
        final details = e.details;
        if (details is Map && details['error'] != null) {
          mensaje = details['error'].toString();
        } else {
          mensaje = e.toString();
        }
      } else {
        mensaje = e.toString();
      }
      _mostrarError(mensajeAmigableDesdeTexto(mensaje, entidad: 'usuario'));
    }
  }

  Future<void> _editarNombre(Map<String, dynamic> usuario) async {
    final nombreController = TextEditingController(text: usuario['nombre']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar nombre'),
        content: SizedBox(
          width: Responsive.isDesktop(context) ? 400 : double.maxFinite,
          child: TextField(
            controller: nombreController,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
                labelText: 'Nombre *',
                labelStyle: TextStyle(fontSize: 13),
                border: OutlineInputBorder()),
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final nombre = normalizarTexto(nombreController.text);
              if (nombre.isEmpty) return;
              Navigator.pop(context);
              try {
                await _supabase
                    .from('usuarios')
                    .update({'nombre': nombre}).eq('id', usuario['id']);
                await _cargarDatos();
                _mostrarExito('Nombre actualizado correctamente');
              } catch (e) {
                _mostrarError(mensajeAmigableDb(e, entidad: 'usuario'));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F4E79),
                foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _editarTelefono(Map<String, dynamic> usuario) async {
    final telefonoController =
        TextEditingController(text: usuario['telefono'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar teléfono'),
        content: SizedBox(
          width: Responsive.isDesktop(context) ? 400 : double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: telefonoController,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Teléfono (WhatsApp)',
                  labelStyle: TextStyle(fontSize: 13),
                  border: OutlineInputBorder(),
                  hintText: '+598XXXXXXXX',
                  hintStyle: TextStyle(fontSize: 12),
                ),
                keyboardType: TextInputType.phone,
                maxLength: 20,
                autofocus: true,
              ),
              const SizedBox(height: 4),
              Text(
                  'Dejá el campo vacío para quitar el teléfono. Necesario para recibir alertas por WhatsApp.',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              final telefono = telefonoController.text.trim();
              if (telefono.isNotEmpty && !_esTelefonoValido(telefono)) {
                _mostrarError(
                    'El teléfono debe tener formato internacional, ej: +59899668216');
                return;
              }
              Navigator.pop(context);
              try {
                await _supabase.from('usuarios').update(
                    {'telefono': telefono.isEmpty ? null : telefono}).eq(
                    'id', usuario['id']);
                await _cargarDatos();
                _mostrarExito('Teléfono actualizado correctamente');
              } catch (e) {
                _mostrarError(mensajeAmigableDb(e, entidad: 'usuario'));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F4E79),
                foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cambiarRol(Map<String, dynamic> usuario) async {
    String rolSeleccionado = usuario['rol_id'] as String;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Cambiar rol de ${usuario['nombre']}'),
          content: SizedBox(
            width: Responsive.isDesktop(context) ? 400 : double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: rolSeleccionado,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  decoration: const InputDecoration(
                      labelText: 'Rol',
                      labelStyle: TextStyle(fontSize: 13),
                      border: OutlineInputBorder()),
                  items: _roles
                      .map((r) => DropdownMenuItem(
                          value: r['id'] as String,
                          child: Text(r['nombre'] as String,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => rolSeleccionado = v!),
                ),
                // Aviso si el nuevo rol restringe por sector.
                if (_rolRestringe(rolSeleccionado)) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!)),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            color: Colors.blue[700], size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                'Este rol restringe por sector. Recordá asignar sectores desde el menú del usuario.',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.blue[700]))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _supabase.from('usuarios').update(
                      {'rol_id': rolSeleccionado}).eq('id', usuario['id']);
                  await _cargarDatos();
                  _mostrarExito('Rol actualizado correctamente');
                } catch (e) {
                  _mostrarError(mensajeAmigableDb(e, entidad: 'usuario'));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E79),
                  foregroundColor: Colors.white),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _asignarSectores(Map<String, dynamic> usuario) async {
    List<Map<String, dynamic>> sectores = [];
    Set<String> asignados = {};
    try {
      final sectoresData =
          await _supabase.from('sectores').select('id, nombre').order('nombre');
      sectores = List<Map<String, dynamic>>.from(sectoresData);
      final asignadosData = await _supabase
          .from('usuario_sector')
          .select('sector_id')
          .eq('usuario_id', usuario['id']);
      for (final a in asignadosData) {
        asignados.add(a['sector_id'] as String);
      }
    } catch (e) {
      _mostrarError('Error al cargar sectores: $e');
      return;
    }

    if (sectores.isEmpty) {
      _mostrarError('No hay sectores creados. Creá sectores primero.');
      return;
    }

    final seleccion = Set<String>.from(asignados);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Sectores de ${usuario['nombre']}'),
          content: SizedBox(
            width: Responsive.isDesktop(context) ? 400 : double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: sectores.map((s) {
                  final id = s['id'] as String;
                  return CheckboxListTile(
                    title:
                        Text(s['nombre'], style: const TextStyle(fontSize: 13)),
                    value: seleccion.contains(id),
                    activeColor: const Color(0xFF1F4E79),
                    onChanged: (v) => setDialogState(() {
                      if (v == true) {
                        seleccion.add(id);
                      } else {
                        seleccion.remove(id);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E79),
                  foregroundColor: Colors.white),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (confirmar != true) return;

    // Si el rol restringe por sector, evitamos dejarlo sin ninguno (fail-closed).
    final restringe = _rolRestringe(usuario['rol_id'] as String?);
    if (restringe && seleccion.isEmpty) {
      _mostrarError(
          'Este rol restringe por sector: asigná al menos un sector o cambiá el rol del usuario.');
      return;
    }

    try {
      await _supabase
          .from('usuario_sector')
          .delete()
          .eq('usuario_id', usuario['id']);
      if (seleccion.isNotEmpty) {
        final filas = seleccion
            .map((sectorId) => {
                  'usuario_id': usuario['id'],
                  'sector_id': sectorId,
                })
            .toList();
        await _supabase.from('usuario_sector').insert(filas);
      }
      _mostrarExito('Sectores actualizados');
    } catch (e) {
      _mostrarError(mensajeAmigableDb(e, entidad: 'asignación de sector'));
    }
  }

  Future<void> _resetearPassword(Map<String, dynamic> usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetear contraseña'),
        content: Text(
            'Se generará una contraseña temporal para "${usuario['nombre']}". El usuario deberá cambiarla la próxima vez que ingrese. ¿Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F4E79),
                foregroundColor: Colors.white),
            child: const Text('Resetear'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final response = await _supabase.functions.invoke(
        'resetear_password',
        body: {'usuario_id': usuario['id']},
      );

      final data = response.data;
      if (data != null && data['success'] == true) {
        final temporal = data['temporal'] as String;
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Contraseña temporal'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Entregá esta contraseña a ${usuario['nombre']}. La deberá cambiar al ingresar.',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SelectableText(
                    temporal,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Tocá y mantené para copiar.',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F4E79),
                    foregroundColor: Colors.white),
                child: const Text('Listo'),
              ),
            ],
          ),
        );
      } else {
        final mensaje = data?['error'] ?? 'Error desconocido al resetear';
        _mostrarError(mensaje.toString());
      }
    } catch (e) {
      _mostrarError('Error al resetear contraseña: $e');
    }
  }

  Future<void> _toggleEstado(Map<String, dynamic> usuario) async {
    final usuarioActual = context.read<AuthProvider>().usuario;
    if (usuarioActual?.id == usuario['id']) {
      _mostrarError('No podés desactivar tu propio usuario');
      return;
    }
    final nuevoEstado = usuario['estado'] == 'activo' ? 'inactivo' : 'activo';
    final accion = nuevoEstado == 'activo' ? 'activar' : 'desactivar';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            '${accion[0].toUpperCase()}${accion.substring(1)} usuario'),
        content: Text(
            '¿Estás seguro que querés $accion a "${usuario['nombre']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    nuevoEstado == 'activo' ? Colors.green : Colors.orange,
                foregroundColor: Colors.white),
            child: Text(accion[0].toUpperCase() + accion.substring(1)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await _supabase
            .from('usuarios')
            .update({'estado': nuevoEstado}).eq('id', usuario['id']);
        await _cargarDatos();
        _mostrarExito(
            'Usuario ${nuevoEstado == 'activo' ? 'activado' : 'desactivado'}');
      } catch (e) {
        _mostrarError(mensajeAmigableDb(e, entidad: 'usuario'));
      }
    }
  }

  Color _colorRol(String rol) {
    switch (rol) {
      case 'admin':
        return const Color(0xFF1F4E79);
      case 'encargado':
        return Colors.blue;
      case 'tecnico':
        return Colors.green;
      case 'operario':
        return Colors.grey;
      case 'shopper':
        return Colors.purple;
      case 'supervisor':
        return Colors.orange;
      default:
        return const Color(0xFF1F4E79);
    }
  }

  void _mostrarExito(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating));
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final usuarioActual = context.read<AuthProvider>().usuario;
    final columns = Responsive.gridColumns(context);
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios', style: TextStyle(fontSize: 17)),
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Destinatarios de alertas',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const DestinatariosWhatsappScreen()),
              );
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _usuarios.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No hay usuarios',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: columns == 1
                      ? ListView.separated(
                          padding: padding,
                          itemCount: _usuarios.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) => _buildCard(
                              _usuarios[index], usuarioActual?.id),
                        )
                      : GridView.builder(
                          padding: padding,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 2.2),
                          itemCount: _usuarios.length,
                          itemBuilder: (context, index) => _buildCard(
                              _usuarios[index], usuarioActual?.id),
                        ),
                ),
      floatingActionButton: FloatingActionButton(
          onPressed: _mostrarFormularioNuevo,
          backgroundColor: const Color(0xFF1F4E79),
          foregroundColor: Colors.white,
          child: const Icon(Icons.person_add_outlined)),
    );
  }

  Widget _buildCard(Map<String, dynamic> usuario, String? myId) {
    final rolNombre = usuario['roles']?['nombre'] ?? '';
    final rolRestringe = usuario['roles']?['restringe_por_sector'] == true;
    final esYo = myId == usuario['id'];
    final activo = usuario['estado'] == 'activo';
    final primerLogin = usuario['primer_login'] == true;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: esYo
              ? const BorderSide(color: Color(0xFF1F4E79), width: 1.5)
              : BorderSide.none),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: activo
              ? _colorRol(rolNombre).withOpacity(0.15)
              : Colors.grey[200],
          child: Text(usuario['nombre'][0].toUpperCase(),
              style: TextStyle(
                  color: activo ? _colorRol(rolNombre) : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                usuario['nombre'],
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: activo ? null : Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (esYo) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xFF1F4E79).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Yo',
                    style:
                        TextStyle(fontSize: 8, color: Color(0xFF1F4E79))),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(usuario['email'],
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis),
            if (usuario['telefono'] != null &&
                (usuario['telefono'] as String).trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 11, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(usuario['telefono'],
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: activo
                          ? _colorRol(rolNombre).withOpacity(0.1)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(rolNombre,
                      style: TextStyle(
                          fontSize: 9,
                          color: activo
                              ? _colorRol(rolNombre)
                              : Colors.grey,
                          fontWeight: FontWeight.w600)),
                ),
                if (rolRestringe && activo)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1F4E79).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 9, color: Color(0xFF1F4E79)),
                        const SizedBox(width: 2),
                        Text('por sector',
                            style: TextStyle(
                                fontSize: 8,
                                color: const Color(0xFF1F4E79),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                if (!activo)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10)),
                    child: const Text('Inactivo',
                        style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ),
                if (primerLogin && activo)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(10)),
                    child: const Text('Pendiente',
                        style:
                            TextStyle(fontSize: 9, color: Colors.orange)),
                  ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton(
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'editar_nombre',
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 18),
                SizedBox(width: 8),
                Text('Editar nombre')
              ]),
            ),
            const PopupMenuItem(
              value: 'editar_telefono',
              child: Row(children: [
                Icon(Icons.phone_outlined, size: 18),
                SizedBox(width: 8),
                Text('Editar teléfono')
              ]),
            ),
            if (!esYo)
              const PopupMenuItem(
                value: 'cambiar_rol',
                child: Row(children: [
                  Icon(Icons.manage_accounts_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Cambiar rol')
                ]),
              ),
            // "Asignar sectores" aparece si el rol del usuario restringe por sector.
            if (!esYo && rolRestringe)
              const PopupMenuItem(
                value: 'asignar_sectores',
                child: Row(children: [
                  Icon(Icons.domain_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Asignar sectores')
                ]),
              ),
            if (!esYo)
              const PopupMenuItem(
                value: 'resetear_pass',
                child: Row(children: [
                  Icon(Icons.lock_reset_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Resetear contraseña')
                ]),
              ),
            if (!esYo)
              PopupMenuItem(
                value: 'toggle_estado',
                child: Row(
                  children: [
                    Icon(
                        activo
                            ? Icons.person_off_outlined
                            : Icons.person_outlined,
                        size: 18,
                        color: activo ? Colors.orange : Colors.green),
                    const SizedBox(width: 8),
                    Text(activo ? 'Desactivar' : 'Activar',
                        style: TextStyle(
                            color: activo ? Colors.orange : Colors.green)),
                  ],
                ),
              ),
          ],
          onSelected: (value) {
            if (value == 'editar_nombre') _editarNombre(usuario);
            if (value == 'editar_telefono') _editarTelefono(usuario);
            if (value == 'cambiar_rol') _cambiarRol(usuario);
            if (value == 'asignar_sectores') _asignarSectores(usuario);
            if (value == 'resetear_pass') _resetearPassword(usuario);
            if (value == 'toggle_estado') _toggleEstado(usuario);
          },
        ),
      ),
    );
  }
}