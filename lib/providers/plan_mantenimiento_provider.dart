import 'package:flutter/material.dart';
import '../models/plan_mantenimiento.dart';
import '../services/plan_mantenimiento_service.dart';

class PlanMantenimientoProvider extends ChangeNotifier {
  final _service = PlanMantenimientoService();

  List<PlanMantenimiento> _planes = [];
  bool _cargando = false;
  String? _error;

  // true = mostrando planes activos | false = mostrando desactivados
  bool _mostrandoActivos = true;

  List<PlanMantenimiento> get planes => _planes;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get mostrandoActivos => _mostrandoActivos;

  Future<void> cargarPlanes({String? maquinaId}) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _planes = await _service.obtenerPlanes(
        maquinaId: maquinaId,
        activo: _mostrandoActivos,
      );
    } catch (e) {
      print('ERROR cargarPlanes: $e');
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // Cambia entre ver activos / inactivos y recarga la lista.
  Future<void> setMostrandoActivos(bool valor, {String? maquinaId}) async {
    if (_mostrandoActivos == valor) return;
    _mostrandoActivos = valor;
    await cargarPlanes(maquinaId: maquinaId);
  }

  Future<bool> crearPlan({
    required String maquinaId,
    required String descripcionTarea,
    required String tipoIntervalo,
    required double intervaloValor,
    String? procedimiento,
  }) async {
    try {
      final nuevo = await _service.crearPlan(
        maquinaId: maquinaId,
        descripcionTarea: descripcionTarea,
        tipoIntervalo: tipoIntervalo,
        intervaloValor: intervaloValor,
        procedimiento: procedimiento,
      );
      // Solo lo agregamos a la lista visible si estamos viendo activos.
      if (_mostrandoActivos) {
        _planes.insert(0, nuevo);
        notifyListeners();
      }
      return true;
    } catch (e) {
      print('ERROR crearPlan: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarPlan({
    required String id,
    String? descripcionTarea,
    String? tipoIntervalo,
    double? intervaloValor,
    bool? activo,
    String? procedimiento,
  }) async {
    try {
      final actualizado = await _service.actualizarPlan(
        id: id,
        descripcionTarea: descripcionTarea,
        tipoIntervalo: tipoIntervalo,
        intervaloValor: intervaloValor,
        activo: activo,
        procedimiento: procedimiento,
      );

      final index = _planes.indexWhere((p) => p.id == id);

      // Si el estado activo del plan ya no coincide con lo que estamos
      // mostrando, lo quitamos de la lista visible. Si coincide, lo
      // reemplazamos en su lugar.
      if (actualizado.activo != _mostrandoActivos) {
        if (index != -1) _planes.removeAt(index);
      } else {
        if (index != -1) {
          _planes[index] = actualizado;
        } else {
          _planes.insert(0, actualizado);
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      print('ERROR actualizarPlan: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> desactivarPlan(String id) async {
    try {
      await _service.actualizarPlan(id: id, activo: false);
      // Si estamos viendo activos, el plan desactivado sale de la lista.
      // Si estamos viendo inactivos, debería aparecer — recargamos.
      if (_mostrandoActivos) {
        _planes.removeWhere((p) => p.id == id);
        notifyListeners();
      } else {
        await cargarPlanes();
      }
      return true;
    } catch (e) {
      print('ERROR desactivarPlan: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> reactivarPlan(String id) async {
    try {
      await _service.actualizarPlan(id: id, activo: true);
      // Si estamos viendo inactivos, el plan reactivado sale de la lista.
      // Si estamos viendo activos, debería aparecer — recargamos.
      if (!_mostrandoActivos) {
        _planes.removeWhere((p) => p.id == id);
        notifyListeners();
      } else {
        await cargarPlanes();
      }
      return true;
    } catch (e) {
      print('ERROR reactivarPlan: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void limpiar() {
    _planes = [];
    _error = null;
    _mostrandoActivos = true;
    notifyListeners();
  }
}