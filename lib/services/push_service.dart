import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart' show navigatorKey;
import '../screens/tickets/ticket_detail_screen.dart';

/// Registro del dispositivo + recepción de notificaciones push (FCM).
///
/// Recepción en los tres estados:
///  - App en primer plano: FCM no muestra nada solo; lo mostramos con
///    flutter_local_notifications. Al tocarlo, abre el ticket.
///  - App en segundo plano: Android muestra la notificación. Al tocarla,
///    onMessageOpenedApp navega al ticket.
///  - App cerrada: al abrir por el push, getInitialMessage navega al ticket.
class PushService {
  static final _supabase = Supabase.instance.client;
  static final _fcm = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  // Canal de Android para las notificaciones (obligatorio en Android 8+).
  static const _canal = AndroidNotificationChannel(
    'indovex_tickets',
    'Notificaciones de tickets',
    description: 'Avisos de creación y cambios de estado de tickets',
    importance: Importance.high,
  );

  // ---------------- REGISTRO DE TOKEN ----------------

  static Future<void> registrarDispositivo() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;

      final settings = await _fcm.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await _fcm.getToken();
      if (token == null) return;
      await _guardarToken(uid, token);

      _fcm.onTokenRefresh.listen((nuevoToken) async {
        final u = _supabase.auth.currentUser?.id;
        if (u != null) await _guardarToken(u, nuevoToken);
      });
    } catch (e) {
      debugPrint('PushService.registrarDispositivo error: $e');
    }
  }

  static Future<void> _guardarToken(String uid, String token) async {
    final plataforma = kIsWeb ? 'web' : defaultTargetPlatform.name;
    await _supabase.from('dispositivos').upsert(
      {
        'usuario_id': uid,
        'token': token,
        'plataforma': plataforma,
        'actualizado': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  static Future<void> desregistrarDispositivo() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await _supabase.from('dispositivos').delete().eq('token', token);
    } catch (e) {
      debugPrint('PushService.desregistrarDispositivo error: $e');
    }
  }

  // ---------------- RECEPCIÓN / NAVEGACIÓN ----------------

  /// Inicializa los handlers de recepción. Llamar una vez al arrancar la app
  /// (después de Firebase.initializeApp, en main).
  static Future<void> initRecepcion() async {
    if (kIsWeb) return; // esta recepción es para móvil

    // 1. Configurar flutter_local_notifications (para foreground).
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: initAndroid);
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        // Tap sobre la notificación local (foreground).
        final ticketId = resp.payload;
        if (ticketId != null && ticketId.isNotEmpty) _abrirTicket(ticketId);
      },
    );

    // Crear el canal en Android.
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_canal);

    // 2. App en primer plano: mostrar la notificación manualmente.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notif = message.notification;
      final ticketId = message.data['ticket_id'];
      if (notif != null) {
        _local.show(
          notif.hashCode,
          notif.title ?? 'IndovexApp',
          notif.body ?? '',
          NotificationDetails(
            android: AndroidNotificationDetails(
              _canal.id,
              _canal.name,
              channelDescription: _canal.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: ticketId,
        );
      }
    });

    // 3. App en segundo plano y se toca la notificación → navegar.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final ticketId = message.data['ticket_id'];
      if (ticketId != null) _abrirTicket(ticketId);
    });

    // 4. App cerrada, se abrió por tocar el push → navegar tras cargar.
    final inicial = await _fcm.getInitialMessage();
    if (inicial != null) {
      final ticketId = inicial.data['ticket_id'];
      if (ticketId != null) {
        _navegarCuandoListo(ticketId);
      }
    }
  }

  /// Espera a que el navigator esté montado y con una ruta base (el home ya
  /// cargó) antes de navegar al ticket. Reintenta hasta ~8 segundos.
  /// Esto evita que, en arranque en frío, el push navegue antes de tiempo
  /// y termine en el dashboard.
  static Future<void> _navegarCuandoListo(String ticketId) async {
    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      final nav = navigatorKey.currentState;
      // canPop true significa que ya hay al menos una pantalla base montada
      // (el home). Recién ahí apilamos el ticket encima.
      if (nav != null && nav.mounted) {
        // Damos un respiro extra para que el home termine de asentarse.
        await Future.delayed(const Duration(milliseconds: 400));
        _abrirTicket(ticketId);
        return;
      }
    }
  }

  /// Navega al detalle del ticket usando el navigatorKey global.
  static void _abrirTicket(String ticketId) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: ticketId)),
    );
  }
}