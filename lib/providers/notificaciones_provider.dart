import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maneja el contador de notificaciones no leídas del usuario actual.
/// Se refresca bajo demanda (al abrir pantallas, al volver de la lista).
/// El realtime queda para una etapa posterior.
class NotificacionesProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  int _noLeidas = 0;
  int get noLeidas => _noLeidas;

  /// Recuenta las notificaciones no leídas del usuario logueado.
  Future<void> refrescar() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      _noLeidas = 0;
      notifyListeners();
      return;
    }
    try {
      final data = await _supabase
          .from('notificaciones')
          .select('id')
          .eq('para_usuario_id', uid)
          .eq('leida', false);
      _noLeidas = (data as List).length;
    } catch (_) {
      // Ante error, no rompemos la UI: dejamos el contador como estaba.
    }
    notifyListeners();
  }

  /// Ajuste optimista local (al marcar una como leída sin re-consultar todo).
  void decrementar([int n = 1]) {
    _noLeidas = (_noLeidas - n).clamp(0, 1 << 30);
    notifyListeners();
  }

  void limpiar() {
    _noLeidas = 0;
    notifyListeners();
  }
}