import 'package:flutter/material.dart';
import '../models/audit_log.dart';
import '../services/audit_log_service.dart';

class AuditLogProvider extends ChangeNotifier {
  final _service = AuditLogService();

  List<AuditLog> _logs = [];
  bool _cargando = false;
  String? _error;

  // Filtros activos
  String _filtroTabla = 'todos';
  String _filtroOperacion = 'todos';
  DateTime? _desde;
  DateTime? _hasta;

  List<AuditLog> get logs => _logs;
  bool get cargando => _cargando;
  String? get error => _error;
  String get filtroTabla => _filtroTabla;
  String get filtroOperacion => _filtroOperacion;
  DateTime? get desde => _desde;
  DateTime? get hasta => _hasta;

  Future<void> cargarLogs() async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      _logs = await _service.obtenerLogs(
        tabla: _filtroTabla,
        operacion: _filtroOperacion,
        desde: _desde,
        hasta: _hasta,
      );
    } catch (e) {
      debugPrint('ERROR cargarLogs: $e');
      _error = e.toString();
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  void setFiltroTabla(String v) {
    _filtroTabla = v;
    cargarLogs();
  }

  void setFiltroOperacion(String v) {
    _filtroOperacion = v;
    cargarLogs();
  }

  void setRangoFechas(DateTime? desde, DateTime? hasta) {
    _desde = desde;
    _hasta = hasta;
    cargarLogs();
  }

  void limpiarFiltros() {
    _filtroTabla = 'todos';
    _filtroOperacion = 'todos';
    _desde = null;
    _hasta = null;
    cargarLogs();
  }

  Future<List<String>> obtenerTablasDisponibles() {
    return _service.obtenerTablasDisponibles();
  }

  void limpiar() {
    _logs = [];
    _error = null;
    notifyListeners();
  }
}