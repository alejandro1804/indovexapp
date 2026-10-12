import 'package:flutter/material.dart';
import '../../services/historial_maquina_pdf_service.dart';
import '../../services/historial_maquina_service.dart';

/// Reporte "Historial de un activo": se elige activo y período, y se
/// exporta el PDF desde el ícono del sector superior derecho.
class ReporteHistorialMaquinaScreen extends StatefulWidget {
  const ReporteHistorialMaquinaScreen({super.key});

  @override
  State<ReporteHistorialMaquinaScreen> createState() =>
      _ReporteHistorialMaquinaScreenState();
}

enum _Periodo { todo, ultimos30, ultimos12meses, personalizado }

class _ReporteHistorialMaquinaScreenState
    extends State<ReporteHistorialMaquinaScreen> {
  List<Map<String, dynamic>> _maquinas = [];
  bool _cargando = true;
  String? _error;

  String? _maquinaId;
  _Periodo _periodo = _Periodo.todo;
  DateTimeRange? _rango; // solo para "personalizado"
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    _cargarMaquinas();
  }

  Future<void> _cargarMaquinas() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final maquinas = await HistorialMaquinaService.listarMaquinas();
      if (!mounted) return;
      setState(() {
        _maquinas = maquinas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los activos.';
        _cargando = false;
      });
    }
  }

  /// (desde, hasta) según el período elegido. null = sin límite.
  (DateTime?, DateTime?) get _limites {
    final hoy = DateTime.now();
    switch (_periodo) {
      case _Periodo.todo:
        return (null, null);
      case _Periodo.ultimos30:
        return (hoy.subtract(const Duration(days: 30)), hoy);
      case _Periodo.ultimos12meses:
        return (DateTime(hoy.year - 1, hoy.month, hoy.day), hoy);
      case _Periodo.personalizado:
        return (_rango?.start, _rango?.end);
    }
  }

  Future<void> _elegirPeriodo(_Periodo? p) async {
    if (p == null) return;
    if (p != _Periodo.personalizado) {
      setState(() => _periodo = p);
      return;
    }
    final hoy = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: hoy,
      initialDateRange: _rango ??
          DateTimeRange(start: DateTime(hoy.year, hoy.month, 1), end: hoy),
    );
    if (!mounted || rango == null) return;
    setState(() {
      _rango = rango;
      _periodo = _Periodo.personalizado;
    });
  }

  Future<void> _exportarPdf() async {
    final id = _maquinaId;
    if (id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final (desde, hasta) = _limites;

    setState(() => _generando = true);
    try {
      final historial = await HistorialMaquinaService.cargar(
        maquinaId: id,
        desde: desde,
        hasta: hasta,
      );
      await HistorialMaquinaPdfService.generarYCompartir(historial);
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo generar el reporte.')),
      );
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  String _fmt(DateTime f) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(f.day)}/${d(f.month)}/${f.year}';
  }

  String _textoPeriodo(_Periodo p) {
    switch (p) {
      case _Periodo.todo:
        return 'Todo el historial';
      case _Periodo.ultimos30:
        return 'Últimos 30 días';
      case _Periodo.ultimos12meses:
        return 'Últimos 12 meses';
      case _Periodo.personalizado:
        final r = _rango;
        return r == null
            ? 'Elegir fechas...'
            : '${_fmt(r.start)} al ${_fmt(r.end)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final puedeExportar = _maquinaId != null && !_generando;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de un activo',
            style: TextStyle(fontSize: 18)),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          _generando
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'Exportar PDF',
                  onPressed: puedeExportar ? _exportarPdf : null,
                ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _cuerpo(),
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            TextButton(
                onPressed: _cargarMaquinas, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_maquinas.isEmpty) {
      return const Center(child: Text('No hay activos para mostrar.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _maquinaId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Activo',
            border: OutlineInputBorder(),
          ),
          items: _maquinas.map((m) {
            final deBaja = m['estado'] == 'dada_de_baja';
            return DropdownMenuItem<String>(
              value: m['id'] as String,
              child: Text(
                '${m['codigo']}  ·  ${m['nombre']}  (${m['sector_nombre']})'
                '${deBaja ? '  - dado de baja' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() => _maquinaId = v),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<_Periodo>(
          // La key fuerza a redibujar si se cancela el selector de fechas
          // o cambia el rango, para que el texto mostrado no quede viejo.
          key: ValueKey('$_periodo-$_rango'),
          initialValue: _periodo,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Período',
            border: OutlineInputBorder(),
          ),
          items: _Periodo.values
              .map((p) => DropdownMenuItem<_Periodo>(
                    value: p,
                    child: Text(_textoPeriodo(p)),
                  ))
              .toList(),
          onChanged: _elegirPeriodo,
        ),
        const SizedBox(height: 24),
        Text(
          'El PDF incluye la ficha del activo, un resumen (tickets, '
          'preventivo vs. correctivo, MTTR), los tickets y las lecturas del '
          'período, los planes de mantenimiento con sus tickets generados y '
          'cerrados, y los documentos adjuntos.',
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        Text(
          'Los activos dados de baja también aparecen: su historial se conserva.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}