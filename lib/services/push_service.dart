import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Gestiona el registro del dispositivo para notificaciones push (FCM).
///
/// Flujo:
///  - Al iniciar sesión: pide permiso de notificaciones, obtiene el token
///    de FCM y lo guarda en la tabla `dispositivos` asociado al usuario.
///  - Al cerrar sesión: borra el token de este dispositivo, para que el
///    usuario deje de recibir push en un equipo que ya no usa.
///
/// La recepción de los mensajes (mostrarlos, abrir el ticket) se maneja
/// aparte, en la Etapa 3.
class PushService {
  static final _supabase = Supabase.instance.client;
  static final _fcm = FirebaseMessaging.instance;

  /// Registra este dispositivo para el usuario logueado.
  /// Llamar después de un login exitoso.
  static Future<void> registrarDispositivo() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;

      // 1. Pedir permiso (Android 13+ y iOS lo requieren explícitamente).
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        // El usuario rechazó las notificaciones: no hay token que guardar.
        return;
      }

      // 2. Obtener el token de este dispositivo.
      final token = await _fcm.getToken();
      if (token == null) return;

      // 3. Guardar (o actualizar) el token en la base.
      await _guardarToken(uid, token);

      // 4. Si Firebase rota el token, actualizarlo también.
      _fcm.onTokenRefresh.listen((nuevoToken) async {
        final u = _supabase.auth.currentUser?.id;
        if (u != null) await _guardarToken(u, nuevoToken);
      });
    } catch (e) {
      // No bloqueamos el login si falla el registro push.
      debugPrint('PushService.registrarDispositivo error: $e');
    }
  }

  static Future<void> _guardarToken(String uid, String token) async {
    final plataforma = kIsWeb ? 'web' : defaultTargetPlatform.name;
    // upsert por token (unique): si el token ya existe, actualiza usuario/fecha.
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

  /// Borra el token de este dispositivo. Llamar antes del logout.
  static Future<void> desregistrarDispositivo() async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;
      await _supabase.from('dispositivos').delete().eq('token', token);
    } catch (e) {
      debugPrint('PushService.desregistrarDispositivo error: $e');
    }
  }
}