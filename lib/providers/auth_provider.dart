import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario.dart';
import '../services/push_service.dart';


class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  Usuario? _usuario;
  bool _cargando = false;
  String? _errorLogin;

  // Datos del trial
  DateTime? _trialVence;
  String _plan = 'trial';

  // Modo admin (solo super admin puede togglear)
  bool _modoAdmin = false;

  Usuario? get usuario => _usuario;
  bool get cargando => _cargando;
  bool get estaAutenticado => _usuario != null;
  String? get errorLogin => _errorLogin;
  String get plan => _plan;
  bool get modoAdmin => _modoAdmin;
  get supabase => _supabase;

  int get diasRestantesTrial {
    if (_trialVence == null) return 999;
    return _trialVence!.difference(DateTime.now()).inDays;
  }

  bool get trialVencido {
    if (_plan != 'trial') return false;
    return diasRestantesTrial < 0;
  }

  bool get mostrarBannerTrial {
    if (_plan != 'trial') return false;
    final dias = diasRestantesTrial;
    return dias >= 0 && dias <= 5;
  }

  void toggleModoAdmin() {
    if (_usuario?.esSuperAdmin != true) return;
    _modoAdmin = !_modoAdmin;
    notifyListeners();
  }

  Future<void> cargarUsuario() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) return;

    _cargando = true;
    notifyListeners();

    try {
      final data = await _supabase
          .from('usuarios')
          .select('*, roles(nombre, restringe_por_sector)')
          .eq('id', authUser.id)
          .single();

      final permisos = await _cargarPermisos();
      _usuario = Usuario.fromMap(data, permisos: permisos);

      await _cargarDatosEmpresa(_usuario!.empresaId);

    } catch (e) {
      _usuario = null;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> _cargarDatosEmpresa(String empresaId) async {
    try {
      final data = await _supabase
          .from('empresas')
          .select('plan, trial_vence')
          .eq('id', empresaId)
          .single();

      _plan = data['plan'] ?? 'trial';
      if (data['trial_vence'] != null) {
        _trialVence = DateTime.parse(data['trial_vence']);
      }
    } catch (e) {
      print('>>> ERROR cargarDatosEmpresa: $e');
      _plan = 'trial';
      _trialVence = null;
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

      // 1. Validar que el usuario esté activo.
      //    Supabase Auth valida credenciales, pero no conoce nuestro campo
      //    'estado'. Un usuario desactivado por su admin tiene credenciales
      //    válidas, así que debemos bloquearlo explícitamente acá.
      final authUserId = _supabase.auth.currentUser!.id;
      final datosUsuario = await _supabase
          .from('usuarios')
          .select('estado')
          .eq('id', authUserId)
          .single();

      final estadoUsuario = datosUsuario['estado'] as String?;
      if (estadoUsuario != 'activo') {
        await _supabase.auth.signOut();
        _errorLogin = 'Tu usuario está desactivado. Contactá al administrador de tu empresa.';
        return false;
      }

      // 2. Validar que la empresa esté activa.
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
      await PushService.registrarDispositivo();
      return true;
    } catch (e) {
      _errorLogin = 'Email o contraseña incorrectos';
      return false;
    }
  }

  Future<void> logout() async {

    await PushService.desregistrarDispositivo();
    await _supabase.auth.signOut();
    await _supabase.auth.signOut();
    _usuario = null;
    _plan = 'trial';
    _trialVence = null;
    _modoAdmin = false;
    notifyListeners();
  }
}