import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/responsive.dart';

/// Ficha de un usuario: se abre al tocarlo en la lista de usuarios.
///
/// Es de solo lectura. Las acciones (editar nombre, cambiar rol, resetear
/// contraseña, etc.) son las mismas del menú de la lista: la lista las pasa
/// por [itemsMenu] y [onAccion], así los diálogos y las reglas quedan en un
/// solo lugar. Cuando una acción termina, la lista avisa por [cambios] y la
/// ficha vuelve a leer los datos.
class UsuarioDetailScreen extends StatefulWidget {
  final String usuarioId;

  /// Id del usuario que tiene la sesión abierta (para marcar "Yo").
  final String? miId;

  /// Avisa cuando la lista modificó algún usuario.
  final Listenable cambios;

  /// Color de cada rol, el mismo que usa la lista.
  final Color Function(String rol) colorRol;

  /// Opciones del menú para el usuario indicado.
  final List<PopupMenuEntry<String>> Function(Map<String, dynamic> usuario)
      itemsMenu;

  /// Ejecuta la opción elegida del menú.
  final void Function(String accion, Map<String, dynamic> usuario) onAccion;

  const UsuarioDetailScreen({
    super.key,
    required this.usuarioId,
    required this.miId,
    required this.cambios,
    required this.colorRol,
    required this.itemsMenu,
    required this.onAccion,
  });

  @override
  State<UsuarioDetailScreen> createState() => _UsuarioDetailScreenState();
}

class _UsuarioDetailScreenState extends State<UsuarioDetailScreen> {
  static const _azul = Color(0xFF1F4E79);

  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _usuario;
  List<String> _ubicaciones = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.cambios.addListener(_alCambiar);
    _cargar();
  }

  @override
  void dispose() {
    widget.cambios.removeListener(_alCambiar);
    super.dispose();
  }

  // La lista modificó algo: se releen los datos sin tapar la ficha.
  void _alCambiar() {
    if (mounted) _cargar(silencioso: true);
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final usuario = await _supabase
          .from('usuarios')
          .select('*, roles(nombre, restringe_por_sector)')
          .eq('id', widget.usuarioId)
          .maybeSingle();

      // Ubicaciones asignadas: solo importan si el rol restringe.
      final ubicaciones = <String>[];
      if (usuario != null && usuario['roles']?['restringe_por_sector'] == true) {
        final sectores =
            await _supabase.from('sectores').select('id, nombre').order('nombre');
        final asignados = await _supabase
            .from('usuario_sector')
            .select('sector_id')
            .eq('usuario_id', widget.usuarioId);
        final ids = {for (final a in asignados) a['sector_id']};
        for (final s in sectores) {
          if (ids.contains(s['id'])) ubicaciones.add(_texto(s['nombre']));
        }
      }

      if (!mounted) return;
      setState(() {
        _usuario = usuario;
        _ubicaciones = ubicaciones;
        _error = usuario == null ? 'No se encontró el usuario' : null;
      });
    } catch (e) {
      if (!mounted) return;
      if (_usuario == null) {
        setState(() => _error = 'Error al cargar el usuario: $e');
      } else {
        // Ya hay datos en pantalla: se avisa sin perder la ficha.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al actualizar la ficha: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _texto(dynamic v) => (v ?? '').toString();

  String _dos(int n) => n.toString().padLeft(2, '0');

  /// Fecha en hora local: 05/10/2026, y con hora si [conHora].
  String? _fecha(dynamic valor, {bool conHora = false}) {
    final f = DateTime.tryParse(_texto(valor))?.toLocal();
    if (f == null) return null;
    final dia = '${_dos(f.day)}/${_dos(f.month)}/${f.year}';
    return conHora ? '$dia ${_dos(f.hour)}:${_dos(f.minute)}' : dia;
  }

  @override
  Widget build(BuildContext context) {
    final usuario = _usuario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuario', style: TextStyle(fontSize: 17)),
        toolbarHeight: 48,
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        actions: [
          if (usuario != null)
            PopupMenuButton<String>(
              tooltip: 'Acciones',
              itemBuilder: (_) => widget.itemsMenu(usuario),
              onSelected: (accion) => widget.onAccion(accion, usuario),
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : usuario == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error ?? 'No se encontró el usuario',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _cargar(silencioso: true),
                  child: ListView(
                    padding: Responsive.pagePadding(context),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _encabezado(usuario),
                              _tituloSeccion('DATOS'),
                              _datos(usuario),
                              _tituloSeccion('UBICACIONES'),
                              _seccionUbicaciones(usuario),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // ---------------------------------------------------------------------
  // Encabezado: inicial, nombre, email y etiquetas
  // ---------------------------------------------------------------------

  Widget _encabezado(Map<String, dynamic> usuario) {
    final nombre = _texto(usuario['nombre']);
    final rolNombre = _texto(usuario['roles']?['nombre']);
    final activo = usuario['estado'] == 'activo';
    final esYo = widget.miId == usuario['id'];
    final primerLogin = usuario['primer_login'] == true;
    final color = activo ? widget.colorRol(rolNombre) : Colors.grey;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: esYo
              ? const BorderSide(color: _azul, width: 1.5)
              : BorderSide.none),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor:
                  activo ? color.withValues(alpha: 0.15) : Colors.grey[200],
              child: Text(
                nombre.isEmpty ? '?' : nombre[0].toUpperCase(),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: activo ? null : Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _texto(usuario['email']),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (rolNombre.isNotEmpty)
                        _etiqueta(rolNombre, color, negrita: true),
                      if (esYo) _etiqueta('Yo', _azul),
                      if (!activo) _etiqueta('Inactivo', Colors.grey),
                      if (primerLogin && activo)
                        _etiqueta('Pendiente', Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _etiqueta(String texto, Color color, {bool negrita = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Text(
        texto,
        style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: negrita ? FontWeight.w600 : FontWeight.normal),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Datos
  // ---------------------------------------------------------------------

  Widget _tituloSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4, left: 4),
      child: Text(
        titulo,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600]),
      ),
    );
  }

  Widget _tarjeta(List<Widget> filas) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(children: filas),
      ),
    );
  }

  Widget _datos(Map<String, dynamic> usuario) {
    final telefono = _texto(usuario['telefono']).trim();
    final rolNombre = _texto(usuario['roles']?['nombre']);
    final activo = usuario['estado'] == 'activo';
    final primerLogin = usuario['primer_login'] == true;
    final alta = _fecha(usuario['created_at']);
    final ultimoAcceso = _fecha(usuario['ultimo_acceso'], conHora: true);

    return _tarjeta([
      _fila(Icons.alternate_email, 'Email', _texto(usuario['email'])),
      _fila(Icons.phone_outlined, 'Teléfono',
          telefono.isEmpty ? 'Sin teléfono' : telefono,
          atenuado: telefono.isEmpty),
      _fila(Icons.manage_accounts_outlined, 'Rol',
          rolNombre.isEmpty ? 'Sin rol' : rolNombre,
          atenuado: rolNombre.isEmpty),
      _fila(
          activo ? Icons.person_outlined : Icons.person_off_outlined,
          'Estado',
          activo ? 'Activo' : 'Inactivo'),
      _fila(
          Icons.lock_outline,
          'Primer ingreso',
          primerLogin
              ? 'Pendiente: todavía no cambió la contraseña temporal'
              : 'Realizado'),
      if (alta != null) _fila(Icons.event_outlined, 'Alta', alta),
      if (ultimoAcceso != null)
        _fila(Icons.schedule_outlined, 'Último acceso', ultimoAcceso),
    ]);
  }

  Widget _fila(IconData icono, String etiqueta, String valor,
      {bool atenuado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(etiqueta,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(
                  fontSize: 12, color: atenuado ? Colors.grey : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Ubicaciones
  // ---------------------------------------------------------------------

  Widget _seccionUbicaciones(Map<String, dynamic> usuario) {
    final restringe = usuario['roles']?['restringe_por_sector'] == true;

    if (!restringe) {
      return _tarjeta([
        _fila(Icons.public, 'Alcance', 'Ve todas las ubicaciones'),
      ]);
    }

    return _tarjeta([
      _fila(Icons.location_on_outlined, 'Alcance',
          'Ve solo las ubicaciones asignadas'),
      Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 8),
        child: _ubicaciones.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!)),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        color: Colors.orange[700], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No tiene ubicaciones asignadas. Asignalas desde el menú de acciones.',
                        style:
                            TextStyle(fontSize: 10, color: Colors.orange[800]),
                      ),
                    ),
                  ],
                ),
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final nombre in _ubicaciones)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: _azul.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          nombre,
                          style: const TextStyle(
                              fontSize: 11,
                              color: _azul,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    ]);
  }
}