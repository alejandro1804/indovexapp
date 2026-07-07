import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/responsive.dart';
import '../../core/db_error_helper.dart';

/// Pantalla para que el admin configure qué usuarios reciben las alertas
/// por WhatsApp (ej: stock bajo). Solo se pueden activar usuarios que
/// tengan un teléfono cargado en su perfil.
class DestinatariosWhatsappScreen extends StatefulWidget {
  const DestinatariosWhatsappScreen({super.key});

  @override
  State<DestinatariosWhatsappScreen> createState() => _DestinatariosWhatsappScreenState();
}

class _DestinatariosWhatsappScreenState extends State<DestinatariosWhatsappScreen> {
  final _supabase = Supabase.instance.client;

  // Lista de usuarios activos de la empresa
  List<Map<String, dynamic>> _usuarios = [];
  // Set con los usuario_id que actualmente son destinatarios activos
  Set<String> _destinatariosActivos = {};
  bool _cargando = true;
  // Para evitar doble toque mientras se procesa un cambio
  final Set<String> _procesando = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      // Usuarios activos de la empresa (RLS filtra por empresa automáticamente)
      final usuariosData = await _supabase
          .from('usuarios')
          .select('id, nombre, email, telefono, roles(nombre)')
          .eq('estado', 'activo')
          .order('nombre');

      // Destinatarios ya configurados (RLS filtra por empresa)
      final destData = await _supabase
          .from('whatsapp_destinatarios')
          .select('usuario_id, activo');

      final activos = <String>{};
      for (final d in destData) {
        if (d['activo'] == true) activos.add(d['usuario_id'] as String);
      }

      setState(() {
        _usuarios = List<Map<String, dynamic>>.from(usuariosData);
        _destinatariosActivos = activos;
      });
    } catch (e) {
      _mostrarError('Error al cargar destinatarios: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _toggleDestinatario(Map<String, dynamic> usuario, bool activar) async {
    final usuarioId = usuario['id'] as String;
    final telefono = usuario['telefono'] as String?;

    // No se puede activar a alguien sin teléfono cargado
    if (activar && (telefono == null || telefono.trim().isEmpty)) {
      _mostrarError('${usuario['nombre']} no tiene teléfono cargado. Cargalo primero desde Usuarios.');
      return;
    }

    setState(() => _procesando.add(usuarioId));
    try {
      final empresaId = await _empresaIdActual();
      if (activar) {
        // upsert: si ya existe la fila (empresa+usuario por la constraint única),
        // la reactiva; si no, la crea.
        await _supabase.from('whatsapp_destinatarios').upsert(
          {
            'empresa_id': empresaId,
            'usuario_id': usuarioId,
            'activo': true,
          },
          onConflict: 'empresa_id,usuario_id',
        );
        setState(() => _destinatariosActivos.add(usuarioId));
      } else {
        // Desactivar: marcamos activo=false en vez de borrar, para mantener
        // historial y auditoría. Filtramos por empresa + usuario (defensa en
        // profundidad, consistente con el upsert de activación).
        await _supabase
            .from('whatsapp_destinatarios')
            .update({'activo': false})
            .eq('empresa_id', empresaId)
            .eq('usuario_id', usuarioId);
        setState(() => _destinatariosActivos.remove(usuarioId));
      }
    } catch (e) {
      _mostrarError(mensajeAmigableDb(e, entidad: 'destinatario'));
    } finally {
      if (mounted) setState(() => _procesando.remove(usuarioId));
    }
  }

  Future<String> _empresaIdActual() async {
    // empresa_id del usuario logueado, vía la fila de usuarios
    final authId = _supabase.auth.currentUser!.id;
    final row = await _supabase.from('usuarios').select('empresa_id').eq('id', authId).single();
    return row['empresa_id'] as String;
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Destinatarios de alertas', style: TextStyle(fontSize: 17)),
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: ListView(
                padding: padding,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue[200]!)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Los usuarios activados reciben alertas (ej: stock bajo) por WhatsApp. Solo se pueden activar usuarios con teléfono cargado.', style: TextStyle(fontSize: 10, color: Colors.blue[700]))),
                      ],
                    ),
                  ),
                  if (_usuarios.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No hay usuarios activos', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    )
                  else
                    ..._usuarios.map(_buildTile),
                ],
              ),
            ),
    );
  }

  Widget _buildTile(Map<String, dynamic> usuario) {
    final usuarioId = usuario['id'] as String;
    final telefono = usuario['telefono'] as String?;
    final tieneTelefono = telefono != null && telefono.trim().isNotEmpty;
    final activo = _destinatariosActivos.contains(usuarioId);
    final procesando = _procesando.contains(usuarioId);
    final rolNombre = usuario['roles']?['nombre'] ?? '';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF1F4E79).withOpacity(0.15),
          child: Text(usuario['nombre'][0].toUpperCase(), style: const TextStyle(color: Color(0xFF1F4E79), fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        title: Text(usuario['nombre'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rolNombre, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(tieneTelefono ? Icons.phone_outlined : Icons.phone_disabled_outlined, size: 12, color: tieneTelefono ? Colors.green : Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    tieneTelefono ? telefono : 'Sin teléfono cargado',
                    style: TextStyle(fontSize: 10, color: tieneTelefono ? Colors.grey[700] : Colors.orange[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: procesando
            ? const SizedBox(width: 36, height: 36, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
            : Switch(
                value: activo,
                activeColor: const Color(0xFF1F4E79),
                onChanged: tieneTelefono ? (v) => _toggleDestinatario(usuario, v) : null,
              ),
      ),
    );
  }
}