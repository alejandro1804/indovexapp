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
      setState(() {
        _permisos = List<Map<String, dynamic>>.from(permisos);
        _seleccionados.clear();
        for (final a in asignados) {
          _seleccionados.add(a['permiso_id'] as String);
        }
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
      if (!mounted) return;
      _mostrarExito('Permisos guardados');
      await _cargar(); // recargar para reflejar los permisos forzados del admin
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
                        Expanded(child: Text('El rol admin siempre conserva "Gestionar roles" y "Gestionar usuarios".', style: TextStyle(fontSize: 12, color: Colors.amber[900]))),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: porModulo.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 4, left: 4),
                            child: Text(entry.key.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                          ),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey[200]!)),
                            child: Column(
                              children: entry.value.map((p) {
                                final id = p['id'] as String;
                                final marcado = _seleccionados.contains(id);
                                return SwitchListTile(
                                  title: Text(p['nombre'], style: const TextStyle(fontSize: 14)),
                                  value: marcado,
                                  activeColor: const Color(0xFF1F4E79),
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
                    }).toList(),
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
                          : const Text('Guardar permisos', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}