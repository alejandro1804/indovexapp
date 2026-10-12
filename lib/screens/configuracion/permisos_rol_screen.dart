import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PermisosRolScreen extends StatefulWidget {
  final String rolId;
  final String rolNombre;
  const PermisosRolScreen({super.key, required this.rolId, required this.rolNombre});

  @override
  State<PermisosRolScreen> createState() => _PermisosRolScreenState();
}

class _PermisosRolScreenState extends State<PermisosRolScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _permisos = [];
  final Set<String> _seleccionados = {};
  bool _cargando = true;
  bool _guardando = false;

  // Alcance del rol: true = ve solo las ubicaciones asignadas. Es la columna
  // roles.restringe_por_sector; en pantalla se muestra al revés, como
  // "Ver todas las ubicaciones".
  bool _restringe = false;
  bool _restringeGuardado = false;

  bool get _esAdmin => widget.rolNombre == 'admin';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final permisos = await _supabase.from('permisos').select('id, codigo, nombre, modulo').order('modulo');
      final asignados = await _supabase.from('rol_permisos').select('permiso_id').eq('rol_id', widget.rolId);
      final rol = await _supabase.from('roles').select('restringe_por_sector').eq('id', widget.rolId).single();
      setState(() {
        _permisos = List<Map<String, dynamic>>.from(permisos);
        _seleccionados.clear();
        for (final a in asignados) {
          _seleccionados.add(a['permiso_id'] as String);
        }
        _restringeGuardado = rol['restringe_por_sector'] == true;
        _restringe = _restringeGuardado;
      });
    } catch (e) {
      _mostrarError('Error al cargar permisos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await _supabase.rpc('establecer_permisos_rol', params: {
        'p_rol_id': widget.rolId,
        'p_permiso_ids': _seleccionados.toList(),
      });
      if (_restringe != _restringeGuardado) {
        // Se pide la fila de vuelta: si la base no deja modificar el rol,
        // el update no da error, simplemente no devuelve nada.
        final filas = await _supabase.from('roles').update({'restringe_por_sector': _restringe}).eq('id', widget.rolId).select('id');
        if (filas.isEmpty) {
          throw Exception('No se pudo cambiar el alcance del rol');
        }
      }
      if (!mounted) return;
      _mostrarExito('Permisos guardados');
      await _cargar(); // recargar para reflejar los permisos forzados del admin y el alcance
    } catch (e) {
      _mostrarError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
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

  // Grupo "Alcance": va arriba de los permisos porque define sobre qué
  // ubicaciones aplican todos los demás.
  Widget _grupoAlcance() {
    final veTodas = !_restringe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
          child: Text('ALCANCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey[200]!)),
          child: SwitchListTile(
            title: const Text('Ver todas las ubicaciones', style: TextStyle(fontSize: 12)),
            subtitle: Text(
              _esAdmin
                  ? 'El rol admin siempre ve todas las ubicaciones'
                  : veTodas
                      ? 'El rol ve todas las ubicaciones'
                      : 'El rol ve solo las ubicaciones asignadas a cada usuario',
              style: const TextStyle(fontSize: 10),
            ),
            value: veTodas,
            activeThumbColor: const Color(0xFF1F4E79),
            // El rol admin nunca se restringe (la base además lo impide).
            onChanged: _esAdmin ? null : (v) => setState(() => _restringe = !v),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Agrupar permisos por módulo
    final porModulo = <String, List<Map<String, dynamic>>>{};
    for (final p in _permisos) {
      final modulo = (p['modulo'] ?? 'Otros').toString();
      porModulo.putIfAbsent(modulo, () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Permisos: ${widget.rolNombre}'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_esAdmin)
                  Container(
                    width: double.infinity,
                    color: Colors.amber[50],
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.amber[800]),
                        const SizedBox(width: 8),
                        Expanded(child: Text('El rol admin siempre conserva "Gestionar roles" y "Gestionar usuarios".', style: TextStyle(fontSize: 10, color: Colors.amber[900]))),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _grupoAlcance(),
                      ...porModulo.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
                              child: Text(entry.key.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                            ),
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey[200]!)),
                              child: Column(
                                children: entry.value.map((p) {
                                  final id = p['id'] as String;
                                  final marcado = _seleccionados.contains(id);
                                  return SwitchListTile(
                                    title: Text(p['nombre'], style: const TextStyle(fontSize: 12)),
                                    value: marcado,
                                    activeThumbColor: const Color(0xFF1F4E79),
                                    onChanged: (v) {
                                      setState(() {
                                        if (v) {
                                          _seleccionados.add(id);
                                        } else {
                                          _seleccionados.remove(id);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _guardar,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
                      child: _guardando
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Guardar permisos', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}