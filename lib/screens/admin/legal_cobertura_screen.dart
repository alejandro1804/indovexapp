import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/legal_service.dart';

/// Vista de super admin: qué empresas aceptaron cada documento vigente.
/// Permite detectar clientes que quedarán bloqueados al vencer el preaviso.
class LegalCoberturaScreen extends StatefulWidget {
  const LegalCoberturaScreen({super.key});

  @override
  State<LegalCoberturaScreen> createState() => _LegalCoberturaScreenState();
}

class _LegalCoberturaScreenState extends State<LegalCoberturaScreen> {
  final _service = LegalService();
  final _fmtFecha = DateFormat('dd/MM/yyyy');
  final _fmtFechaHora = DateFormat('dd/MM/yyyy HH:mm');

  List<Map<String, dynamic>> _filas = [];
  bool _cargando = true;
  String? _error;

  // Filtro: 'todos' | 'pendientes' | 'aceptados'
  String _filtro = 'todos';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final data = await _service.cobertura();
      if (!mounted) return;
      setState(() => _filas = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo cargar la cobertura legal');
      debugPrint('>>> [LEGAL] Error en sa_legal_cobertura: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<Map<String, dynamic>> get _filasFiltradas {
    switch (_filtro) {
      case 'pendientes':
        return _filas.where((f) => f['aceptado'] != true).toList();
      case 'aceptados':
        return _filas.where((f) => f['aceptado'] == true).toList();
      default:
        return _filas;
    }
  }

  int get _totalPendientes =>
      _filas.where((f) => f['aceptado'] != true).length;

  String _tituloDoc(String codigo) =>
      codigo == 'tyc' ? 'Términos y Condiciones' : 'Política de Privacidad';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        title: const Text('Cobertura legal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _cargar,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    _buildResumen(),
                    _buildFiltros(),
                    Expanded(child: _buildLista()),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumen() {
    if (_filas.isEmpty) return const SizedBox.shrink();

    // Los días para vigencia son iguales por documento; tomamos el mínimo
    // para el aviso general.
    final dias = _filas
        .map((f) => f['dias_para_vigencia'] as int? ?? 0)
        .fold<int>(9999, (a, b) => b < a ? b : a);

    final vencido = dias < 0;
    final hayPendientes = _totalPendientes > 0;

    Color color;
    IconData icono;
    String texto;

    if (!hayPendientes) {
      color = Colors.green[700]!;
      icono = Icons.check_circle_outline;
      texto = 'Todas las empresas activas aceptaron los documentos vigentes.';
    } else if (vencido) {
      color = Colors.red[700]!;
      icono = Icons.block;
      texto = '$_totalPendientes pendiente${_totalPendientes == 1 ? '' : 's'}. '
          'El preaviso venció: esas empresas están bloqueadas.';
    } else {
      color = Colors.orange[800]!;
      icono = Icons.schedule;
      texto = '$_totalPendientes pendiente${_totalPendientes == 1 ? '' : 's'}. '
          'Quedan $dias día${dias == 1 ? '' : 's'} de preaviso.';
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          _chip('todos', 'Todos', _filas.length),
          const SizedBox(width: 8),
          _chip('pendientes', 'Pendientes', _totalPendientes),
          const SizedBox(width: 8),
          _chip('aceptados', 'Aceptados', _filas.length - _totalPendientes),
        ],
      ),
    );
  }

  Widget _chip(String valor, String label, int cantidad) {
    final activo = _filtro == valor;
    return ChoiceChip(
      label: Text('$label ($cantidad)'),
      selected: activo,
      onSelected: (_) => setState(() => _filtro = valor),
      labelStyle: TextStyle(
        fontSize: 12,
        color: activo ? Colors.white : Colors.grey[700],
        fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
      ),
      selectedColor: const Color(0xFF1F4E79),
      backgroundColor: Colors.grey[200],
      side: BorderSide.none,
    );
  }

  Widget _buildLista() {
    final filas = _filasFiltradas;

    if (filas.isEmpty) {
      return Center(
        child: Text(
          'Sin resultados para este filtro',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        itemCount: filas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _buildFila(filas[i]),
      ),
    );
  }

  Widget _buildFila(Map<String, dynamic> f) {
    final aceptado = f['aceptado'] == true;
    final dias = f['dias_para_vigencia'] as int? ?? 0;
    final vencido = dias < 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            aceptado ? Icons.check_circle : Icons.radio_button_unchecked,
            color: aceptado
                ? Colors.green[600]
                : (vencido ? Colors.red[600] : Colors.orange[700]),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f['empresa_nombre'] ?? '—',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_tituloDoc(f['documento'])} · v${f['version']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                if (aceptado)
                  Text(
                    'Aceptado el ${_fmtFechaHora.format(DateTime.parse(f['aceptado_en']).toLocal())}'
                    '${f['aceptado_por'] != null ? ' por ${f['aceptado_por']}' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.green[800]),
                  )
                else
                  Text(
                    vencido
                        ? 'Bloqueada — el preaviso venció el ${_fmtFecha.format(DateTime.parse(f['fecha_vigencia']))}'
                        : 'Pendiente — vigencia el ${_fmtFecha.format(DateTime.parse(f['fecha_vigencia']))} '
                          '($dias día${dias == 1 ? '' : 's'})',
                    style: TextStyle(
                      fontSize: 11,
                      color: vencido ? Colors.red[700] : Colors.orange[800],
                      fontWeight: vencido ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}