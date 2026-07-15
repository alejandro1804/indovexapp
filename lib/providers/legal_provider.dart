import 'package:flutter/material.dart';
import '../models/documento_legal.dart';
import '../services/legal_service.dart';

class LegalProvider extends ChangeNotifier {
  final _service = LegalService();

  List<DocumentoLegal> _pendientes = [];
  bool _cargando = false;
  bool _cargado = false;
  String? _error;

  /// Documentos que el usuario descartó manualmente en esta sesión.
  /// Solo aplica a avisos no bloqueantes.
  final Set<String> _descartados = {};

  List<DocumentoLegal> get pendientes => _pendientes;
  bool get cargando => _cargando;
  bool get cargado => _cargado;
  String? get error => _error;

  /// Documentos que exigen aceptación antes de operar.
  /// Solo se pueblan para el admin y una vez vencido el preaviso.
  List<DocumentoLegal> get bloqueantes =>
      _pendientes.where((d) => d.bloqueante).toList();

  /// Avisos informativos: en preaviso, o para usuarios no admin.
  /// Excluye los descartados en esta sesión.
  List<DocumentoLegal> get avisos => _pendientes
      .where((d) => !d.bloqueante && !_descartados.contains(d.id))
      .toList();

  bool get hayBloqueo => bloqueantes.isNotEmpty;
  bool get hayAvisos => avisos.isNotEmpty;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _pendientes = await _service.estadoPendiente();
      _cargado = true;
    } catch (e) {
      _error = 'No se pudo verificar el estado de los documentos legales';
      _pendientes = [];
      debugPrint('>>> [LEGAL] Error al cargar pendientes: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> aceptar(DocumentoLegal doc, {String? userAgent}) async {
    try {
      await _service.aceptar(doc.id, userAgent: userAgent);
      _pendientes.removeWhere((d) => d.id == doc.id);
      _descartados.remove(doc.id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'No se pudo registrar la aceptación. Intentá nuevamente.';
      debugPrint('>>> [LEGAL] Error al aceptar ${doc.documento} v${doc.version}: $e');
      notifyListeners();
      return false;
    }
  }

  /// Descarta un aviso no bloqueante por lo que resta de la sesión.
  void descartar(DocumentoLegal doc) {
    if (doc.bloqueante) return;
    _descartados.add(doc.id);
    notifyListeners();
  }

  void limpiar() {
    _pendientes = [];
    _descartados.clear();
    _cargado = false;
    _cargando = false;
    _error = null;
    notifyListeners();
  }
}