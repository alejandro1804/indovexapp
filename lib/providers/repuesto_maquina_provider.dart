import 'package:flutter/material.dart';
import '../models/repuesto_maquina.dart';
import '../services/repuesto_maquina_service.dart';

class RepuestoMaquinaProvider extends ChangeNotifier {
  final _service = RepuestoMaquinaService();

  List<RepuestoMaquina> _vinculos = [];
  bool _cargando = false;
  String? _error;

  List<RepuestoMaquina> get vinculos => _vinculos;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargarPorMaquina(String maquinaId) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _vinculos = await _service.obtenerPorMaquina(maquinaId);
    } catch (e) {
      debugPrint('ERROR cargarPorMaquina: $e');
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> cargarPorRepuesto(String repuestoId) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _vinculos = await _service.obtenerPorRepuesto(repuestoId);
    } catch (e) {
      debugPrint('ERROR cargarPorRepuesto: $e');
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> vincular({
    required String repuestoId,
    required String maquinaId,
    required int cantidad,
    String? ubicacionEnMaquina,
    String? observacion,
  }) async {
    try {
      final nuevo = await _service.vincular(
        repuestoId: repuestoId,
        maquinaId: maquinaId,
        cantidad: cantidad,
        ubicacionEnMaquina: ubicacionEnMaquina,
        observacion: observacion,
      );
      _vinculos.insert(0, nuevo);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('ERROR vincular: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizar({
    required String id,
    int? cantidad,
    String? ubicacionEnMaquina,
    String? observacion,
  }) async {
    try {
      final actualizado = await _service.actualizar(
        id: id,
        cantidad: cantidad,
        ubicacionEnMaquina: ubicacionEnMaquina,
        observacion: observacion,
      );
      final index = _vinculos.indexWhere((v) => v.id == id);
      if (index != -1) {
        _vinculos[index] = actualizado;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('ERROR actualizar: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> desvincular(String id) async {
    try {
      await _service.desvincular(id);
      _vinculos.removeWhere((v) => v.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('ERROR desvincular: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void limpiar() {
    _vinculos = [];
    _error = null;
    notifyListeners();
  }
}