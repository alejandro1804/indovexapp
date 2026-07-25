import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/notificaciones_provider.dart';
import '../../core/responsive.dart';
import '../tickets/ticket_detail_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notificaciones = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      final data = await _supabase
          .from('notificaciones')
          .select('*')
          .eq('para_usuario_id', uid)
          .order('created_at', ascending: false)
          .limit(100);
      setState(() {
        _notificaciones = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      _mostrarError('Error al cargar notificaciones: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _marcarLeida(Map<String, dynamic> n) async {
    if (n['leida'] == true) return;
    try {
      await _supabase
          .from('notificaciones')
          .update({'leida': true, 'leida_en': DateTime.now().toUtc().toIso8601String()})
          .eq('id', n['id']);
      n['leida'] = true;
      if (mounted) {
        context.read<NotificacionesProvider>().decrementar();
        setState(() {});
      }
    } catch (_) {
      // Silencioso: no bloqueamos la navegación por un fallo de marca.
    }
  }

  Future<void> _marcarTodasLeidas() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _supabase
          .from('notificaciones')
          .update({'leida': true, 'leida_en': DateTime.now().toUtc().toIso8601String()})
          .eq('para_usuario_id', uid)
          .eq('leida', false);
      for (final n in _notificaciones) {
        n['leida'] = true;
      }
      if (mounted) {
        context.read<NotificacionesProvider>().limpiar();
        setState(() {});
        _mostrarExito('Todas marcadas como leídas');
      }
    } catch (e) {
      _mostrarError('No se pudieron marcar: $e');
    }
  }

  Future<void> _abrir(Map<String, dynamic> n) async {
    await _marcarLeida(n);
    final ticketId = n['ticket_id'];
    if (ticketId != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: ticketId)),
      );
    }
  }

  String _formatoFecha(DateTime? fechaUtc) {
    if (fechaUtc == null) return '';
    final local = fechaUtc.toLocal();
    final ahora = DateTime.now();
    final diff = ahora.difference(local);
    if (diff.inMinutes < 1) return 'Recién';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} día${diff.inDays == 1 ? '' : 's'}';
    String d(int x) => x.toString().padLeft(2, '0');
    return '${d(local.day)}/${d(local.month)}/${local.year}';
  }

  IconData _iconoTipo(String tipo) {
    if (tipo.contains('resuelto')) return Icons.check_circle_outline;
    if (tipo.contains('rechazado')) return Icons.cancel_outlined;
    if (tipo.contains('asignado')) return Icons.assignment_ind_outlined;
    if (tipo.contains('cerrado')) return Icons.lock_outline;
    if (tipo.contains('pausado')) return Icons.pause_circle_outline;
    if (tipo.contains('en_proceso')) return Icons.build_outlined;
    if (tipo.contains('nuevo')) return Icons.fiber_new_outlined;
    if (tipo.contains('stock')) return Icons.inventory_2_outlined;
    return Icons.notifications_outlined;
  }

  void _mostrarExito(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final hayNoLeidas = _notificaciones.any((n) => n['leida'] != true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          if (hayNoLeidas)
            TextButton(
              onPressed: _marcarTodasLeidas,
              child: const Text('Marcar todas', style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _notificaciones.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No tenés notificaciones',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: Responsive.pagePadding(context),
                    itemCount: _notificaciones.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final n = _notificaciones[index];
                      final leida = n['leida'] == true;
                      final tipo = (n['tipo'] ?? '').toString();
                      final fecha = DateTime.tryParse(n['created_at'] ?? '');

                      return Card(
                        elevation: leida ? 0 : 1,
                        color: leida ? Colors.grey[50] : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: leida ? Colors.grey[200]! : const Color(0xFF1F4E79).withOpacity(0.25),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _abrir(n),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: (leida ? Colors.grey : const Color(0xFF1F4E79))
                                      .withOpacity(0.12),
                                  child: Icon(_iconoTipo(tipo),
                                      size: 18,
                                      color: leida ? Colors.grey : const Color(0xFF1F4E79)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n['mensaje'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: leida ? FontWeight.normal : FontWeight.w600,
                                          color: leida ? Colors.grey[700] : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_formatoFecha(fecha),
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                    ],
                                  ),
                                ),
                                if (!leida)
                                  Container(
                                    width: 9,
                                    height: 9,
                                    margin: const EdgeInsets.only(top: 4, left: 6),
                                    decoration: const BoxDecoration(
                                        color: Color(0xFF1F4E79), shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}