import 'package:flutter/material.dart';
import '../models/plan_mantenimiento.dart';
import '../services/plan_mantenimiento_service.dart';

class PlanMantenimientoProvider extends ChangeNotifier {
  final _service = PlanMantenimientoService();

  List<PlanMantenimiento> _planes = [];
  bool _cargando = false;
  String? _error;

  List<PlanMantenimiento> get planes => _planes;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargarPlanes({String? maquinaId}) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _planes = await _service.obtenerPlanes(maquinaId: maquinaId);
    } catch (e) {
      print('ERROR cargarPlanes: $e');
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> crearPlan({
    required String maquinaId,
    required String descripcionTarea,
    required String tipoIntervalo,
    required double intervaloValor,
  }) async {
    try {
      final nuevo = await _service.crearPlan(
        maquinaId: maquinaId,
        descripcionTarea: descripcionTarea,
        tipoIntervalo: tipoIntervalo,
        intervaloValor: intervaloValor,
      );
      _planes.insert(0, nuevo);
      notifyListeners();
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
  }) async {
    try {
      final actualizado = await _service.actualizarPlan(
        id: id,
        descripcionTarea: descripcionTarea,
        tipoIntervalo: tipoIntervalo,
        intervaloValor: intervaloValor,
        activo: activo,
      );
      final index = _planes.indexWhere((p) => p.id == id);
      if (index != -1) {
        _planes[index] = actualizado;
        notifyListeners();
      }
      return true;
    } catch (e) {
      print('ERROR actualizarPlan: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> desactivarPlan(String id) async {
    return actualizarPlan(id: id, activo: false);
  }

  void limpiar() {
    _planes = [];
    _error = null;
    notifyListeners();
  }
}