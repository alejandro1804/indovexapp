import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/db_error_helper.dart';
import '../../providers/auth_provider.dart';
import '../../services/roles_permisos_excel_service.dart';
import '../../services/roles_permisos_pdf_service.dart';

/// Grilla de roles x permisos, estilo planilla.
///
/// Filas: permisos agrupados por módulo. Columnas: roles de la empresa, con
/// la cantidad de usuarios que tiene cada uno.
/// La primera fila es el alcance ("Ver todas las ubicaciones"): no es un
/// permiso de la tabla permisos, es la columna roles.restringe_por_sector
/// mostrada al revés (marcada = el rol NO está restringido). Las reglas de
/// la base siguen leyendo esa columna.
/// Se marcan y desmarcan casillas y se guarda todo junto; por cada rol
/// modificado se llama a la RPC establecer_permisos_rol, la misma que usa
/// la pantalla de permisos por rol (la base valida gestionar_roles).
/// Desde la barra superior se exporta a PDF o a planilla Excel.
class PermisosGrillaScreen extends StatefulWidget {
  const PermisosGrillaScreen({super.key});

  @override
  State<PermisosGrillaScreen> createState() => _PermisosGrillaScreenState();
}

class _PermisosGrillaScreenState extends State<PermisosGrillaScreen> {
  static const _azul = Color(0xFF1F4E79);
  static const _borde = Color(0xFFD0D7DE);
  static const _fondoEncabezado = Color(0xFFEAF1F8);
  static const _fondoModulo = Color(0xFFF3F4F6);
  static const _fondoCambio = Color(0xFFFFF3CD);
  static const _grisCasilla = Color(0xFFB0B8C1);
  static const _bordeCelda = Border(
    right: BorderSide(color: _borde),
    bottom: BorderSide(color: _borde),
  );

  // Roles del sistema: van primero en las columnas, en este orden.
  static const _rolesSistema = ['admin', 'encargado', 'tecnico'];

  // Permisos que el rol admin conserva siempre (los fuerza la base).
  static const _permisosFijosAdmin = ['gestionar_roles', 'gestionar_usuarios'];

  // Fila de alcance: se muestra arriba de los permisos, en un grupo propio.
  static const _grupoAlcance = 'alcance';
  static const _nombreAlcance = 'Ver todas las ubicaciones';
  static const _ayudaAlcance =
      'Sin esto, el rol ve solo las ubicaciones asignadas a cada usuario';

  static const double _altoEncabezado = 48;
  static const double _altoFila = 40;
  static const double _altoModulo = 28;
  static const double _anchoRol = 96;

  final _supabase = Supabase.instance.client;

  // El encabezado y el cuerpo se desplazan juntos en horizontal.
  final _hEncabezado = ScrollController();
  final _hCuerpo = ScrollController();
  bool _sincronizando = false;

  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _permisos = [];

  // Permisos por rol: lo que hay en la base y lo que se ve en pantalla.
  final Map<String, Set<String>> _original = {};
  final Map<String, Set<String>> _actual = {};

  // Alcance por rol tal como se ve en pantalla (true = solo ubicaciones
  // asignadas). El valor guardado en la base queda en el mapa de cada rol.
  final Map<String, bool> _restringe = {};

  bool _cargando = true;
  bool _guardando = false;
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    _hEncabezado.addListener(() => _sincronizar(_hEncabezado, _hCuerpo));
    _hCuerpo.addListener(() => _sincronizar(_hCuerpo, _hEncabezado));
    _cargar();
  }

  @override
  void dispose() {
    _hEncabezado.dispose();
    _hCuerpo.dispose();
    super.dispose();
  }

  void _sincronizar(ScrollController origen, ScrollController destino) {
    if (_sincronizando || !destino.hasClients) return;
    if (destino.offset == origen.offset) return;
    _sincronizando = true;
    destino.jumpTo(origen.offset);
    _sincronizando = false;
  }

  // ---------------------------------------------------------------------
  // Datos
  // ---------------------------------------------------------------------

  Future<void> _cargar() async {
    // La RPC de guardado solo acepta roles de la empresa propia, así que
    // la grilla muestra solo esos (importa para el super admin, que por
    // RLS ve los roles de todas las empresas).
    final empresaId = context.read<AuthProvider>().usuario?.empresaId;
    setState(() => _cargando = true);
    try {
      var consultaRoles =
          _supabase.from('roles').select('id, nombre, restringe_por_sector');
      if (empresaId != null) {
        consultaRoles = consultaRoles.eq('empresa_id', empresaId);
      }
      // Copia de cada fila: más abajo se le agrega la cantidad de usuarios.
      final roles = [
        for (final r in await consultaRoles) Map<String, dynamic>.from(r),
      ];
      roles.sort((a, b) {
        final oa = _ordenRol(_texto(a['nombre']));
        final ob = _ordenRol(_texto(b['nombre']));
        if (oa != ob) return oa.compareTo(ob);
        return _texto(a['nombre']).compareTo(_texto(b['nombre']));
      });

      final permisos = List<Map<String, dynamic>>.from(
        await _supabase.from('permisos').select('id, codigo, nombre, modulo'),
      );
      permisos.sort((a, b) {
        final m = _modulo(a).compareTo(_modulo(b));
        if (m != 0) return m;
        return _texto(a['nombre']).compareTo(_texto(b['nombre']));
      });

      final porRol = <String, Set<String>>{
        for (final r in roles) r['id'] as String: <String>{},
      };
      if (roles.isNotEmpty) {
        final asignados = await _supabase
            .from('rol_permisos')
            .select('rol_id, permiso_id')
            .inFilter('rol_id', porRol.keys.toList());
        for (final a in asignados) {
          porRol[a['rol_id'] as String]?.add(a['permiso_id'] as String);
        }

        // Cantidad de usuarios por rol (mismo criterio que la lista de roles).
        final usuarios = await _supabase
            .from('usuarios')
            .select('rol_id')
            .inFilter('rol_id', porRol.keys.toList());
        final cantidad = <String, int>{};
        for (final u in usuarios) {
          final rolId = _texto(u['rol_id']);
          cantidad[rolId] = (cantidad[rolId] ?? 0) + 1;
        }
        for (final r in roles) {
          r['usuarios'] = cantidad[r['id']] ?? 0;
        }
      }

      if (!mounted) return;
      setState(() {
        _roles = roles;
        _permisos = permisos;
        _original.clear();
        _actual.clear();
        _restringe.clear();
        porRol.forEach((rolId, ids) {
          _original[rolId] = Set<String>.from(ids);
          _actual[rolId] = Set<String>.from(ids);
        });
        for (final r in roles) {
          _restringe[r['id'] as String] = r['restringe_por_sector'] == true;
        }
      });
    } catch (e) {
      _mostrarError('Error al cargar la grilla: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    final pendientes = _rolesModificados;
    if (pendientes.isEmpty) return;

    setState(() => _guardando = true);
    final fallidos = <String>[];
    String? primerError;

    for (final rolId in pendientes) {
      try {
        if (_diferenciasPermisos(rolId) > 0) {
          final ids = _actual[rolId] ?? <String>{};
          await _supabase.rpc('establecer_permisos_rol', params: {
            'p_rol_id': rolId,
            'p_permiso_ids': ids.toList(),
          });
          _original[rolId] = Set<String>.from(ids);
        }
        if (_cambioAlcance(rolId)) {
          final valor = _restringeActual(rolId);
          // Se pide la fila de vuelta: si la base no deja modificar el rol,
          // el update no da error, simplemente no devuelve nada.
          final filas = await _supabase
              .from('roles')
              .update({'restringe_por_sector': valor})
              .eq('id', rolId)
              .select('id');
          if (filas.isEmpty) {
            throw Exception('No se pudo cambiar el alcance del rol');
          }
          _rol(rolId)?['restringe_por_sector'] = valor;
        }
      } catch (e) {
        fallidos.add(_titulo(_nombreRol(rolId)));
        primerError ??= mensajeAmigableDb(e, entidad: 'rol');
      }
    }

    if (!mounted) return;
    setState(() => _guardando = false);

    if (fallidos.isEmpty) {
      _mostrarExito('Cambios guardados');
    } else {
      // Los roles que fallaron quedan marcados como pendientes.
      _mostrarError('No se pudo guardar: ${fallidos.join(', ')}. $primerError');
    }
  }

  /// Exporta lo que está guardado en la base: con cambios pendientes no
  /// se exporta, para que el documento no muestre algo que todavía no rige.
  Future<void> _exportar({required bool excel}) async {
    if (_hayCambios) {
      _mostrarError('Guardá o descartá los cambios antes de exportar');
      return;
    }
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;
    setState(() => _exportando = true);
    try {
      final empresa = await _supabase
          .from('empresas')
          .select('nombre')
          .eq('id', usuario.empresaId)
          .single();
      final nombreEmpresa = empresa['nombre'] as String? ?? '';

      if (excel) {
        final guardada = await RolesPermisosExcelService.generarYGuardar(
          roles: _roles,
          permisos: _permisos,
          permisosPorRol: _original,
          nombreEmpresa: nombreEmpresa,
        );
        if (guardada) _mostrarExito('Planilla Excel generada');
      } else {
        await RolesPermisosPdfService.generarYCompartir(
          roles: _roles,
          permisos: _permisos,
          permisosPorRol: _original,
          nombreEmpresa: nombreEmpresa,
        );
      }
    } catch (e) {
      _mostrarError('Error al exportar: $e');
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  void _descartar() {
    setState(() {
      for (final rolId in _original.keys) {
        _actual[rolId] = Set<String>.from(_original[rolId] ?? <String>{});
        _restringe[rolId] = _restringeGuardado(rolId);
      }
    });
  }

  void _alternarAlcance(Map<String, dynamic> rol) {
    if (_guardando || _alcanceBloqueado(rol)) return;
    final rolId = rol['id'] as String;
    setState(() => _restringe[rolId] = !_restringeActual(rolId));
  }

  void _alternar(Map<String, dynamic> rol, Map<String, dynamic> permiso) {
    if (_guardando || _bloqueada(rol, permiso)) return;
    final ids = _actual[rol['id'] as String];
    if (ids == null) return;
    final permisoId = permiso['id'] as String;
    setState(() {
      if (!ids.add(permisoId)) ids.remove(permisoId);
    });
  }

  // ---------------------------------------------------------------------
  // Consultas sobre el estado de la grilla
  // ---------------------------------------------------------------------

  String _texto(dynamic v) => (v ?? '').toString();

  String _modulo(Map<String, dynamic> permiso) {
    final m = _texto(permiso['modulo']).trim();
    return m.isEmpty ? 'otros' : m;
  }

  String _titulo(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  int _ordenRol(String nombre) {
    final i = _rolesSistema.indexOf(nombre);
    return i == -1 ? _rolesSistema.length : i;
  }

  Map<String, dynamic>? _rol(String rolId) {
    for (final r in _roles) {
      if (r['id'] == rolId) return r;
    }
    return null;
  }

  String _nombreRol(String rolId) => _texto(_rol(rolId)?['nombre']);

  // Alcance: true = el rol ve solo las ubicaciones asignadas.
  bool _restringeGuardado(String rolId) =>
      _rol(rolId)?['restringe_por_sector'] == true;

  bool _restringeActual(String rolId) => _restringe[rolId] ?? false;

  bool _cambioAlcance(String rolId) =>
      _restringeActual(rolId) != _restringeGuardado(rolId);

  /// El rol admin nunca se restringe (la base además lo impide).
  bool _alcanceBloqueado(Map<String, dynamic> rol) => rol['nombre'] == 'admin';

  bool _tiene(String rolId, String permisoId) =>
      _actual[rolId]?.contains(permisoId) ?? false;

  bool _cambio(String rolId, String permisoId) =>
      _tiene(rolId, permisoId) !=
      (_original[rolId]?.contains(permisoId) ?? false);

  /// El admin no puede perder los permisos de gestion: la casilla marcada
  /// queda fija (la base los vuelve a agregar aunque se manden sin ellos).
  bool _bloqueada(Map<String, dynamic> rol, Map<String, dynamic> permiso) =>
      rol['nombre'] == 'admin' &&
      _permisosFijosAdmin.contains(permiso['codigo']) &&
      _tiene(rol['id'] as String, permiso['id'] as String);

  int _diferenciasPermisos(String rolId) {
    final a = _actual[rolId] ?? <String>{};
    final o = _original[rolId] ?? <String>{};
    return a.difference(o).length + o.difference(a).length;
  }

  /// Casillas cambiadas del rol: permisos más la de alcance.
  int _diferencias(String rolId) =>
      _diferenciasPermisos(rolId) + (_cambioAlcance(rolId) ? 1 : 0);

  List<String> get _rolesModificados => [
        for (final r in _roles)
          if (_diferencias(r['id'] as String) > 0) r['id'] as String,
      ];

  int get _casillasCambiadas {
    var n = 0;
    for (final r in _roles) {
      n += _diferencias(r['id'] as String);
    }
    return n;
  }

  bool get _hayCambios => _rolesModificados.isNotEmpty;

  // ---------------------------------------------------------------------
  // Mensajes y diálogos
  // ---------------------------------------------------------------------

  void _mostrarExito(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _confirmarSalida() async {
    final navegador = Navigator.of(context);
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambios sin guardar'),
        content: const Text(
            'Si salís ahora se pierden los cambios hechos en la grilla.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir sin guardar'),
          ),
        ],
      ),
    );
    if (salir == true) navegador.pop();
  }

  // ---------------------------------------------------------------------
  // Interfaz
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final esMovil = MediaQuery.of(context).size.width < 600;
    final anchoPermiso = esMovil ? 150.0 : 280.0;
    final puedeExportar =
        !_cargando && !_guardando && _roles.isNotEmpty && _permisos.isNotEmpty;

    return PopScope(
      canPop: !_hayCambios,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmarSalida();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Grilla de permisos', style: TextStyle(fontSize: 17)),
          toolbarHeight: 48,
          backgroundColor: _azul,
          foregroundColor: Colors.white,
          actions: [
            if (_exportando)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Exportar PDF',
                onPressed:
                    puedeExportar ? () => _exportar(excel: false) : null,
              ),
              IconButton(
                icon: const Icon(Icons.table_chart_outlined),
                tooltip: 'Exportar Excel',
                onPressed: puedeExportar ? () => _exportar(excel: true) : null,
              ),
            ],
          ],
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : (_roles.isEmpty || _permisos.isEmpty)
                ? const Center(
                    child: Text(
                      'No hay roles o permisos para mostrar',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(child: _grilla(anchoPermiso)),
                      _barraInferior(),
                    ],
                  ),
      ),
    );
  }

  Widget _grilla(double anchoPermiso) {
    final porModulo = <String, List<Map<String, dynamic>>>{};
    for (final p in _permisos) {
      porModulo.putIfAbsent(_modulo(p), () => []).add(p);
    }

    return Column(
      children: [
        // Fila de encabezado: queda fija arriba.
        SizedBox(
          height: _altoEncabezado,
          child: Row(
            children: [
              _celdaEsquina(anchoPermiso),
              Expanded(
                child: SingleChildScrollView(
                  controller: _hEncabezado,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final r in _roles) _encabezadoRol(r)],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Cuerpo: la columna de permisos queda fija a la izquierda.
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: anchoPermiso,
                  child: Column(
                    children: [
                      _moduloIzquierda(_grupoAlcance),
                      _celdaNombre(_nombreAlcance, _ayudaAlcance),
                      for (final e in porModulo.entries) ...[
                        _moduloIzquierda(e.key),
                        for (final p in e.value) _celdaPermiso(p),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _hCuerpo,
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _moduloDerecha(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final r in _roles) _casillaAlcance(r),
                          ],
                        ),
                        for (final e in porModulo.entries) ...[
                          _moduloDerecha(),
                          for (final p in e.value)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final r in _roles) _casilla(r, p),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _celdaEsquina(double ancho) {
    return Container(
      width: ancho,
      height: _altoEncabezado,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      decoration:
          const BoxDecoration(color: _fondoEncabezado, border: _bordeCelda),
      child: const Text(
        'Permiso',
        style:
            TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _azul),
      ),
    );
  }

  Widget _encabezadoRol(Map<String, dynamic> rol) {
    final nombre = _titulo(_texto(rol['nombre']));
    final usuarios = (rol['usuarios'] as int?) ?? 0;

    return Tooltip(
      message: nombre,
      child: Container(
        width: _anchoRol,
        height: _altoEncabezado,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration:
            const BoxDecoration(color: _fondoEncabezado, border: _bordeCelda),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: _azul),
            ),
            Text(
              '$usuarios ${usuarios == 1 ? 'usuario' : 'usuarios'}',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moduloIzquierda(String modulo) {
    return Container(
      height: _altoModulo,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: _fondoModulo,
        border: Border(bottom: BorderSide(color: _borde)),
      ),
      child: Text(
        modulo.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: _azul),
      ),
    );
  }

  Widget _moduloDerecha() {
    return Container(
      width: _anchoRol * _roles.length,
      height: _altoModulo,
      decoration: const BoxDecoration(color: _fondoModulo, border: _bordeCelda),
    );
  }

  Widget _celdaPermiso(Map<String, dynamic> permiso) =>
      _celdaNombre(_texto(permiso['nombre']), _texto(permiso['codigo']));

  /// Celda de la columna fija de la izquierda.
  Widget _celdaNombre(String nombre, String detalle) {
    return Tooltip(
      message: '$nombre\n$detalle',
      child: Container(
        height: _altoFila,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        decoration:
            const BoxDecoration(color: Colors.white, border: _bordeCelda),
        child: Text(
          nombre,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Widget _casilla(Map<String, dynamic> rol, Map<String, dynamic> permiso) {
    final rolId = rol['id'] as String;
    final permisoId = permiso['id'] as String;
    return _casillaBase(
      marcada: _tiene(rolId, permisoId),
      bloqueada: _bloqueada(rol, permiso),
      cambio: _cambio(rolId, permisoId),
      alTocar: () => _alternar(rol, permiso),
      avisoBloqueo: 'El rol admin siempre conserva este permiso',
    );
  }

  /// Casilla de alcance: marcada = el rol ve todas las ubicaciones.
  Widget _casillaAlcance(Map<String, dynamic> rol) {
    final rolId = rol['id'] as String;
    return _casillaBase(
      marcada: !_restringeActual(rolId),
      bloqueada: _alcanceBloqueado(rol),
      cambio: _cambioAlcance(rolId),
      alTocar: () => _alternarAlcance(rol),
      avisoBloqueo: 'El rol admin siempre ve todas las ubicaciones',
    );
  }

  Widget _casillaBase({
    required bool marcada,
    required bool bloqueada,
    required bool cambio,
    required VoidCallback alTocar,
    required String avisoBloqueo,
  }) {
    final celda = InkWell(
      onTap: (bloqueada || _guardando) ? null : alTocar,
      child: Container(
        width: _anchoRol,
        height: _altoFila,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cambio ? _fondoCambio : Colors.white,
          border: _bordeCelda,
        ),
        child: Icon(
          bloqueada
              ? Icons.lock
              : (marcada ? Icons.check_box : Icons.check_box_outline_blank),
          size: 20,
          color: bloqueada
              ? Colors.grey.shade600
              : (marcada ? _azul : _grisCasilla),
        ),
      ),
    );

    if (!bloqueada) return celda;
    return Tooltip(message: avisoBloqueo, child: celda);
  }

  Widget _barraInferior() {
    final roles = _rolesModificados.length;
    final casillas = _casillasCambiadas;
    final hayCambios = roles > 0;

    final resumen = hayCambios
        ? '$casillas ${casillas == 1 ? 'cambio' : 'cambios'} sin guardar en '
            '$roles ${roles == 1 ? 'rol' : 'roles'}'
        : 'Sin cambios pendientes';

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _borde)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                resumen,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: hayCambios ? Colors.black87 : Colors.grey.shade600,
                ),
              ),
            ),
            if (hayCambios)
              TextButton(
                onPressed: _guardando ? null : _descartar,
                child: const Text('Descartar', style: TextStyle(fontSize: 12)),
              ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: (!hayCambios || _guardando) ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _azul,
                foregroundColor: Colors.white,
              ),
              child: _guardando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Guardar', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}