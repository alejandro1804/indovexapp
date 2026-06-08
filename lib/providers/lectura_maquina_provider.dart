import 'package:flutter/material.dart';
import '../models/lectura_maquina.dart';
import '../services/lectura_maquina_service.dart';

class LecturaMaquinaProvider extends ChangeNotifier {
  final _service = LecturaMaquinaService();

  List<LecturaMaquina> _lecturas = [];
  LecturaMaquina? _ultimaLectura;
  bool _cargando = false;
  String? _error;

  List<LecturaMaquina> get lecturas => _lecturas;
  LecturaMaquina? get ultimaLectura => _ultimaLectura;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargarLecturas({
    required String maquinaId,
    String? tipo,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _lecturas = await _service.obtenerLecturas(
        maquinaId: maquinaId,
        tipo: tipo,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> cargarUltimaLectura({
    required String maquinaId,
    required String tipo,
  }) async {
    try {
      _ultimaLectura = await _service.obtenerUltimaLectura(
        maquinaId: maquinaId,
        tipo: tipo,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> registrarLectura({
    required String maquinaId,
    required String tipo,
    required double valor,
    DateTime? fechaLectura,
    String? observacion,
  }) async {
    try {
      final nueva = await _service.registrarLectura(
        maquinaId: maquinaId,
        tipo: tipo,
        valor: valor,
        fechaLectura: fechaLectura,
        observacion: observacion,
      );
      _lecturas.insert(0, nueva);
      _ultimaLectura = nueva;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void limpiar() {
    _lecturas = [];
    _ultimaLectura = null;
    _error = null;
    notifyListeners();
  }
}