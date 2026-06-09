import 'package:flutter/material.dart';
import '../models/tipo_intervalo.dart';
import '../services/tipo_intervalo_service.dart';

class TipoIntervaloProvider extends ChangeNotifier {
  final _service = TipoIntervaloService();

  List<TipoIntervalo> _tipos = [];
  bool _cargando = false;
  String? _error;

  List<TipoIntervalo> get tipos => _tipos;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargarTipos() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _tipos = await _service.obtenerTipos();
    } catch (e) {
      print('ERROR cargarTipos: $e');
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> crearTipo({
    required String nombre,
    required String codigo,
  }) async {
    try {
      final nuevo = await _service.crearTipo(
        nombre: nombre,
        codigo: codigo,
      );
      _tipos.add(nuevo);
      _tipos.sort((a, b) => a.nombre.compareTo(b.nombre));
      notifyListeners();
      return true;
    } catch (e) {
      print('ERROR crearTipo: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarTipo({
    required String id,
    required String nombre,
    required String codigo,
  }) async {
    try {
      final actualizado = await _service.actualizarTipo(
        id: id,
        nombre: nombre,
        codigo: codigo,
      );
      final index = _tipos.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tipos[index] = actualizado;
        notifyListeners();
      }
      return true;
    } catch (e) {
      print('ERROR actualizarTipo: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> desactivarTipo(String id) async {
    try {
      await _service.desactivarTipo(id);
      _tipos.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      print('ERROR desactivarTipo: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void limpiar() {
    _tipos = [];
    _error = null;
    notifyListeners();
  }
}