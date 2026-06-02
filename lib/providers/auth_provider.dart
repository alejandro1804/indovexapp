import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  Usuario? _usuario;
  bool _cargando = false;
  String? _errorLogin;

  Usuario? get usuario => _usuario;
  bool get cargando => _cargando;
  bool get estaAutenticado => _usuario != null;
  String? get errorLogin => _errorLogin;

  Future<void> cargarUsuario() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) return;

    _cargando = true;
    notifyListeners();

    try {
      final data = await _supabase
          .from('usuarios')
          .select('*, roles(nombre)')
          .eq('id', authUser.id)
          .single();

      // Cargar los permisos del rol del usuario vía RPC (robusto, se saltea RLS)
      final permisos = await _cargarPermisos();

      _usuario = Usuario.fromMap(data, permisos: permisos);
    } catch (e) {
      _usuario = null;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<List<String>> _cargarPermisos() async {
    try {
      final data = await _supabase.rpc('mis_permisos');
      return (data as List).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> login(String email, String password) async {
    _errorLogin = null;
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final estadoEmpresa = await _supabase.rpc('estado_mi_empresa');

      if (estadoEmpresa != 'activa') {
        await _supabase.auth.signOut();
        if (estadoEmpresa == 'pendiente') {
          _errorLogin = 'Tu empresa está pendiente de aprobación. Te avisaremos cuando esté activa.';
        } else if (estadoEmpresa == 'suspendida') {
          _errorLogin = 'Tu empresa está suspendida. Contactá al administrador del sistema.';
        } else {
          _errorLogin = 'Tu empresa no está activa.';
        }
        return false;
      }

      await cargarUsuario();
      return true;
    } catch (e) {
      _errorLogin = 'Email o contraseña incorrectos';
      return false;
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    _usuario = null;
    notifyListeners();
  }
}