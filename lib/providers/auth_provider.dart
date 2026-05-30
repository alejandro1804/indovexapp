import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  Usuario? _usuario;
  bool _cargando = false;

  Usuario? get usuario => _usuario;
  bool get cargando => _cargando;
  bool get estaAutenticado => _usuario != null;

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
      _usuario = Usuario.fromMap(data);
    } catch (e) {
      _usuario = null;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await cargarUsuario();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    _usuario = null;
    notifyListeners();
  }
}
