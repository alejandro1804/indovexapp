import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';

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
      final usuariosData = await _supabase.from('usuarios').select('*, roles(nombre)').order('nombre');
      final rolesData = await _supabase.from('roles').select().order('nombre');
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

  Future<void> _mostrarFormularioNuevo() async {
    final emailController = TextEditingController();
    final nombreController = TextEditingController();
    final passwordController = TextEditingController();
    String? rolSeleccionado = _roles.isNotEmpty ? _roles.first['id'] : null;
    bool verPassword = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuevo Usuario'),
          content: SizedBox(
            width: Responsive.isDesktop(context) ? 480 : double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreController,
                    decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder()),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder()),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: !verPassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña temporal *',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey),
                        onPressed: () => setDialogState(() => verPassword = !verPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: rolSeleccionado,
                    decoration: const InputDecoration(labelText: 'Rol *', border: OutlineInputBorder()),
                    items: _roles.map((r) => DropdownMenuItem(value: r['id'] as String, child: Text(r['nombre'] as String))).toList(),
                    onChanged: (v) => setDialogState(() => rolSeleccionado = v),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue[200]!)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text('El usuario deberá cambiar su contraseña al primer ingreso.', style: TextStyle(fontSize: 12, color: Colors.blue[700]))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (emailController.text.trim().isEmpty || nombreController.text.trim().isEmpty || passwordController.text.trim().isEmpty || rolSeleccionado == null) return;
                Navigator.pop(context);
                await _crearUsuario(email: emailController.text.trim(), nombre: nombreController.text.trim(), password: passwordController.text.trim(), rolId: rolSeleccionado!);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearUsuario({required String email, required String nombre, required String password, required String rolId}) async {
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
        _mostrarExito('Usuario creado correctamente');
        await _cargarDatos();
      } else {
        final mensaje = data?['error'] ?? 'Error desconocido al crear usuario';
        _mostrarError(mensaje.toString());
      }
    } catch (e) {
      _mostrarError('Error al crear usuario: $e');
    }
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
            child: DropdownButtonFormField<String>(
              value: rolSeleccionado,
              decoration: const InputDecoration(labelText: 'Rol', border: OutlineInputBorder()),
              items: _roles.map((r) => DropdownMenuItem(value: r['id'] as String, child: Text(r['nombre'] as String))).toList(),
              onChanged: (v) => setDialogState(() => rolSeleccionado = v!),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _supabase.from('usuarios').update({'rol_id': rolSeleccionado}).eq('id', usuario['id']);
                  await _cargarDatos();
                  _mostrarExito('Rol actualizado correctamente');
                } catch (e) {
                  _mostrarError('Error al cambiar rol: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetearPassword(Map<String, dynamic> usuario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetear contraseña'),
        content: Text('Se generará una contraseña temporal para "${usuario['nombre']}". El usuario deberá cambiarla la próxima vez que ingrese. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
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
                Text('Entregá esta contraseña a ${usuario['nombre']}. La deberá cambiar al ingresar.'),
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
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Tocá y mantené para copiar.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
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
        title: Text('${accion[0].toUpperCase()}${accion.substring(1)} usuario'),
        content: Text('¿Estás seguro que querés $accion a "${usuario['nombre']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: nuevoEstado == 'activo' ? Colors.green : Colors.orange, foregroundColor: Colors.white),
            child: Text(accion[0].toUpperCase() + accion.substring(1)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await _supabase.from('usuarios').update({'estado': nuevoEstado}).eq('id', usuario['id']);
        await _cargarDatos();
        _mostrarExito('Usuario ${nuevoEstado == 'activo' ? 'activado' : 'desactivado'}');
      } catch (e) {
        _mostrarError('Error al cambiar estado: $e');
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final usuarioActual = context.read<AuthProvider>().usuario;
    final columns = Responsive.gridColumns(context);
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios'), backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _usuarios.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No hay usuarios', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: columns == 1
                      ? ListView.separated(
                          padding: padding,
                          itemCount: _usuarios.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _buildCard(_usuarios[index], usuarioActual?.id),
                        )
                      : GridView.builder(
                          padding: padding,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2),
                          itemCount: _usuarios.length,
                          itemBuilder: (context, index) => _buildCard(_usuarios[index], usuarioActual?.id),
                        ),
                ),
      floatingActionButton: FloatingActionButton(onPressed: _mostrarFormularioNuevo, backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white, child: const Icon(Icons.person_add_outlined)),
    );
  }

  Widget _buildCard(Map<String, dynamic> usuario, String? myId) {
    final rolNombre = usuario['roles']?['nombre'] ?? '';
    final esYo = myId == usuario['id'];
    final activo = usuario['estado'] == 'activo';
    final primerLogin = usuario['primer_login'] == true;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: esYo ? const BorderSide(color: Color(0xFF1F4E79), width: 1.5) : BorderSide.none),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: activo ? _colorRol(rolNombre).withOpacity(0.15) : Colors.grey[200],
          child: Text(usuario['nombre'][0].toUpperCase(), style: TextStyle(color: activo ? _colorRol(rolNombre) : Colors.grey, fontWeight: FontWeight.bold)),
        ),
        title: Row(
          children: [
            Text(usuario['nombre'], style: TextStyle(fontWeight: FontWeight.w600, color: activo ? null : Colors.grey)),
            if (esYo) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF1F4E79).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('Yo', style: TextStyle(fontSize: 10, color: Color(0xFF1F4E79))),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(usuario['email'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: activo ? _colorRol(rolNombre).withOpacity(0.1) : Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                  child: Text(rolNombre, style: TextStyle(fontSize: 11, color: activo ? _colorRol(rolNombre) : Colors.grey, fontWeight: FontWeight.w600)),
                ),
                if (!activo) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                    child: const Text('Inactivo', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ],
                if (primerLogin && activo) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10)),
                    child: const Text('Pendiente', style: TextStyle(fontSize: 11, color: Colors.orange)),
                  ),
                ],
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: esYo
            ? null
            : PopupMenuButton(
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'cambiar_rol',
                    child: Row(children: [Icon(Icons.manage_accounts_outlined, size: 18), SizedBox(width: 8), Text('Cambiar rol')]),
                  ),
                  const PopupMenuItem(
                    value: 'resetear_pass',
                    child: Row(children: [Icon(Icons.lock_reset_outlined, size: 18), SizedBox(width: 8), Text('Resetear contraseña')]),
                  ),
                  PopupMenuItem(
                    value: 'toggle_estado',
                    child: Row(
                      children: [
                        Icon(activo ? Icons.person_off_outlined : Icons.person_outlined, size: 18, color: activo ? Colors.orange : Colors.green),
                        const SizedBox(width: 8),
                        Text(activo ? 'Desactivar' : 'Activar', style: TextStyle(color: activo ? Colors.orange : Colors.green)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'cambiar_rol') _cambiarRol(usuario);
                  if (value == 'resetear_pass') _resetearPassword(usuario);
                  if (value == 'toggle_estado') _toggleEstado(usuario);
                },
              ),
      ),
    );
  }
}