import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maneja el contador de notificaciones no leídas del usuario actual.
///
/// Comportamiento base (siempre): se refresca bajo demanda vía [refrescar]
/// (al abrir pantallas, al volver de la lista). Esto es lo único que necesita
/// la campana para contar, y funciona sin activar nada más.
///
/// Comportamiento opcional (solo si se llama [iniciarPolling]): además del
/// refresh bajo demanda, corre un polling periódico (cada [_intervalo])
/// mientras la app está visible, se pausa en segundo plano y refresca al
/// reanudar. MIENTRAS NO SE LLAME iniciarPolling(), el timer y el observador
/// de ciclo de vida permanecen inertes y el provider se comporta igual que la
/// versión original. El realtime (websocket) queda para una etapa posterior.
class NotificacionesProvider extends ChangeNotifier with WidgetsBindingObserver {
  final _supabase = Supabase.instance.client;

  /// Intervalo del polling opcional. 90s equilibra frescura del contador vs.
  /// consumo de consultas; para notificaciones de mantenimiento la inmediatez
  /// absoluta no es crítica.
  static const Duration _intervalo = Duration(seconds: 90);

  int _noLeidas = 0;
  int get noLeidas => _noLeidas;

  Timer? _timer;
  bool _polling = false;

  // ---------------------------------------------------------------------------
  // Refresh base (siempre disponible, no depende del polling)
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Polling opcional (inerte hasta que se llame iniciarPolling)
  // ---------------------------------------------------------------------------

  /// Arranca el polling periódico y registra el observador de ciclo de vida.
  /// Idempotente: llamarlo más de una vez no crea timers ni observers extra.
  /// Hace un refresh inmediato al iniciar.
  void iniciarPolling() {
    if (_polling) return;
    _polling = true;
    WidgetsBinding.instance.addObserver(this);
    _programarTimer();
    refrescar(); // primer conteo inmediato
  }

  /// Detiene el polling y da de baja el observador. Seguro de llamar aunque el
  /// polling nunca se haya iniciado (no hace nada en ese caso).
  void detenerPolling() {
    if (!_polling) return;
    _polling = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void _programarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_intervalo, (_) => refrescar());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si el polling no está activo, ignoramos por completo el ciclo de vida.
    if (!_polling) return;
    if (state == AppLifecycleState.resumed) {
      // El usuario volvió a la app: refresco inmediato + reactivo el timer,
      // así ve el contador al día sin esperar el próximo ciclo.
      _programarTimer();
      refrescar();
    } else {
      // paused / inactive / hidden / detached: freno el timer para no
      // consultar mientras nadie mira la app.
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    // Seguro aunque el polling nunca se haya iniciado: detenerPolling() tiene
    // su propia guarda y no intenta remover un observer que no se agregó.
    detenerPolling();
    super.dispose();
  }
}