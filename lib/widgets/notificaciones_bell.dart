import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notificaciones_provider.dart';
import '../screens/notificaciones/notificaciones_screen.dart';

/// Campanita con badge de no leídas para la AppBar / sidebar.
/// Refresca el contador al montarse y al volver de la lista.
class NotificacionesBell extends StatefulWidget {
  /// Color del ícono (blanco en AppBar azul, gris/blanco en sidebar).
  final Color color;
  const NotificacionesBell({super.key, this.color = Colors.white});

  @override
  State<NotificacionesBell> createState() => _NotificacionesBellState();
}

class _NotificacionesBellState extends State<NotificacionesBell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificacionesProvider>().refrescar();
    });
  }

  Future<void> _abrir() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
    );
    if (mounted) context.read<NotificacionesProvider>().refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final noLeidas = context.watch<NotificacionesProvider>().noLeidas;

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: widget.color),
          tooltip: 'Notificaciones',
          onPressed: _abrir,
        ),
        if (noLeidas > 0)
          Positioned(
            top: 8,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: Text(
                noLeidas > 99 ? '99+' : '$noLeidas',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}