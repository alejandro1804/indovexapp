import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;

  static const _azul = Color(0xFF1F4E79);

  bool _cargando = true;
  String? _error;
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _mtbf = [];

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
      // Carga en paralelo: KPIs existentes + MTBF
      final results = await Future.wait([
        _supabase.rpc('dashboard_kpis'),
        _supabase.rpc('get_mtbf_empresa'),
      ]);

      final map = Map<String, dynamic>.from(results[0] as Map);
      if (map['error'] != null) {
        setState(() {
          _error = 'No se pudo determinar la empresa.';
          _cargando = false;
        });
        return;
      }

      final mtbfRaw = results[1] as List? ?? [];
      final mtbf = mtbfRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      setState(() {
        _data = map;
        _mtbf = mtbf;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar el panel: $e';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final puedeRatio = usuario.tienePermiso('ver_kpi_ratio_mantenimiento');
    final puedeMttr = usuario.tienePermiso('ver_kpi_mttr');
    final puedeBacklog = usuario.tienePermiso('ver_kpi_backlog_tickets');
    final puedeMtbf = usuario.tienePermiso('ver_kpi_mtbf');

    final isDesktop = Responsive.isTabletOrDesktop(context);

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: _azul,
              foregroundColor: Colors.white,
              title: const Text('Dashboard',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _cargando ? null : _cargar,
                  tooltip: 'Actualizar',
                ),
              ],
            ),
      body: _buildBody(puedeRatio, puedeMttr, puedeBacklog, puedeMtbf),
    );
  }

  Widget _buildBody(
      bool puedeRatio, bool puedeMttr, bool puedeBacklog, bool puedeMtbf) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _estadoVacio(Icons.error_outline, _error!, accion: _cargar);
    }

    if (!puedeRatio && !puedeMttr && !puedeBacklog && !puedeMtbf) {
      return _estadoVacio(
        Icons.lock_outline,
        'No tenés KPIs habilitados. Contactá al administrador de tu empresa.',
      );
    }

    final ratio = _data?['ratio'] as Map<String, dynamic>?;
    final mttr = _data?['mttr'] as Map<String, dynamic>?;
    final backlog = (_data?['backlog'] as List?) ?? [];
    final padding = Responsive.pagePadding(context);

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: padding,
        children: [
          if (Responsive.isTabletOrDesktop(context)) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 16, top: 8),
              child: Text('Dashboard',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ],
          if (puedeRatio) ...[
            _CardKpi(
              titulo: 'Mantenimiento preventivo vs correctivo',
              icono: Icons.donut_large_outlined,
              child: _buildRatio(ratio),
            ),
            const SizedBox(height: 16),
          ],
          if (puedeMttr) ...[
            _CardKpi(
              titulo: 'MTTR — Tiempo medio de reparación',
              icono: Icons.timer_outlined,
              child: _buildMttr(mttr),
            ),
            const SizedBox(height: 16),
          ],
          if (puedeBacklog) ...[
            _CardKpi(
              titulo: 'Backlog de tickets pendientes',
              icono: Icons.layers_outlined,
              child: _buildBacklog(backlog),
            ),
            const SizedBox(height: 16),
          ],
          if (puedeMtbf) ...[
            _CardKpi(
              titulo: 'MTBF — Tiempo medio entre fallas',
              icono: Icons.pending_actions_outlined,
              child: _buildMtbf(_mtbf),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ============================================
  // KPI 1: RATIO PREVENTIVO / CORRECTIVO
  // ============================================
  Widget _buildRatio(Map<String, dynamic>? ratio) {
    final preventivo = (ratio?['preventivo'] ?? 0) as int;
    final correctivo = (ratio?['correctivo'] ?? 0) as int;
    final total = (ratio?['total'] ?? 0) as int;

    if (total == 0) {
      return _sinDatos('No hay tickets registrados todavía.');
    }

    final pctPrev = (preventivo / total * 100);
    final pctCorr = (correctivo / total * 100);

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 32,
                    sections: [
                      PieChartSectionData(
                        value: preventivo.toDouble(),
                        title: '${pctPrev.round()}%',
                        color: Colors.green,
                        radius: 44,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      PieChartSectionData(
                        value: correctivo.toDouble(),
                        title: '${pctCorr.round()}%',
                        color: Colors.red,
                        radius: 44,
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _leyenda(Colors.green, 'Preventivo', preventivo),
                    const SizedBox(height: 10),
                    _leyenda(Colors.red, 'Correctivo', correctivo),
                    const SizedBox(height: 10),
                    _leyenda(Colors.grey, 'Total', total),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (pctCorr > 50) ...[
          const SizedBox(height: 12),
          _alerta(
            'Predomina el mantenimiento correctivo. Un ratio alto de correctivo '
            'puede indicar fallas frecuentes o planes preventivos insuficientes.',
          ),
        ],
      ],
    );
  }

  Widget _leyenda(Color color, String label, int valor) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '$label: $valor',
            style: TextStyle(color: Colors.grey[800], fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ============================================
  // KPI 2: MTTR
  // ============================================
  Widget _buildMttr(Map<String, dynamic>? mttr) {
    final considerados = (mttr?['tickets_considerados'] ?? 0) as int;
    final horas = mttr?['mttr_horas'];

    if (considerados == 0 || horas == null) {
      return _sinDatos(
        'Sin correctivos cerrados aún. El MTTR se calculará cuando se cierre '
        'el primer ticket correctivo.',
      );
    }

    final horasNum = (horas as num).toDouble();
    final texto = _formatoDuracion(horasNum);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          texto,
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: _azul),
        ),
        const SizedBox(height: 4),
        Text(
          'Promedio sobre $considerados ticket${considerados == 1 ? '' : 's'} '
          'correctivo${considerados == 1 ? '' : 's'} cerrado${considerados == 1 ? '' : 's'}.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  String _formatoDuracion(double horas) {
    if (horas < 24) return '${horas.toStringAsFixed(1)} h';
    final dias = (horas / 24);
    return '${dias.toStringAsFixed(1)} días';
  }

  // ============================================
  // KPI 3: BACKLOG
  // ============================================
  Widget _buildBacklog(List backlog) {
    if (backlog.isEmpty) {
      return _sinDatos('No hay tickets pendientes. Todo al día.');
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: const [
              Expanded(
                  flex: 3,
                  child: Text('Prioridad',
                      style: _thStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)),
              Expanded(
                  flex: 2,
                  child: Text('0-3 d',
                      style: _thStyle, textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('4-7 d',
                      style: _thStyle, textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('+7 d',
                      style: _thStyle, textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('Total',
                      style: _thStyle, textAlign: TextAlign.center)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ...backlog.map((fila) {
          final f = Map<String, dynamic>.from(fila);
          final prioridad = f['prioridad'] as String? ?? '';
          final r03 = (f['rango_0_3'] ?? 0) as int;
          final r47 = (f['rango_4_7'] ?? 0) as int;
          final r7 = (f['rango_mas_7'] ?? 0) as int;
          final total = (f['total'] ?? 0) as int;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: _colorPrioridad(prioridad),
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(_labelPrioridad(prioridad),
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: _celda(r03, intensidad: 0)),
                Expanded(flex: 2, child: _celda(r47, intensidad: 1)),
                Expanded(flex: 2, child: _celda(r7, intensidad: 2)),
                Expanded(
                  flex: 2,
                  child: Text('$total',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        if (_tieneEnvejecidos(backlog))
          _alerta(
            'Hay tickets con más de 7 días sin resolver. Revisá el backlog para '
            'evitar acumulación.',
          ),
      ],
    );
  }

  Widget _celda(int valor, {required int intensidad}) {
    if (valor == 0) {
      return Center(
        child: Text('0', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
      );
    }
    final colores = [Colors.green, Colors.orange, Colors.red];
    final color = colores[intensidad];
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 3),
        width: 30,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          '$valor',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.bold,
              fontSize: 12),
        ),
      ),
    );
  }

  bool _tieneEnvejecidos(List backlog) {
    for (final fila in backlog) {
      final f = Map<String, dynamic>.from(fila);
      if (((f['rango_mas_7'] ?? 0) as int) > 0) return true;
    }
    return false;
  }

  // ============================================
  // KPI 4: MTBF
  // ============================================
  Widget _buildMtbf(List<Map<String, dynamic>> mtbf) {
    if (mtbf.isEmpty) {
      return _sinDatos(
        'El MTBF se calculará automáticamente cuando un activo '
        'acumule su segundo ticket correctivo cerrado.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: const [
              Expanded(flex: 4, child: Text('Activo', style: _thStyle)),
              Expanded(
                  flex: 3,
                  child: Text('MTBF',
                      style: _thStyle, textAlign: TextAlign.center)),
              Expanded(
                  flex: 3,
                  child: Text('Fallas',
                      style: _thStyle, textAlign: TextAlign.center)),
              Expanded(
                  flex: 3,
                  child: Text('Confiab.',
                      style: _thStyle, textAlign: TextAlign.center)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ...mtbf.map((fila) {
          final nombre = fila['maquina_nombre'] as String? ?? '-';
          final sector = fila['sector_nombre'] as String? ?? '';
          final mtbfDias = (fila['mtbf_dias'] as num?)?.toDouble() ?? 0;
          final totalTickets = (fila['total_tickets_correctivos'] as int?) ?? 0;
          final confiabilidad = fila['confiabilidad'] as String? ?? 'baja';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Activo + sector
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (sector.isNotEmpty)
                        Text(
                          sector,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // MTBF en días
                Expanded(
                  flex: 3,
                  child: Text(
                    '${mtbfDias.toStringAsFixed(1)} d',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _colorMtbf(mtbfDias),
                    ),
                  ),
                ),
                // Cantidad de fallas
                Expanded(
                  flex: 3,
                  child: Text(
                    '$totalTickets',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
                // Badge de confiabilidad
                Expanded(
                  flex: 3,
                  child: Center(child: _badgeConfiabilidad(confiabilidad)),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        // Nota aclaratoria
        Text(
          '* Confiab. indica cuántos datos hay para el cálculo: '
          'Baja (<3 fallas), Media (3-5), Alta (6+).',
          style: TextStyle(color: Colors.grey[400], fontSize: 10),
        ),
        // Alerta si hay activos con MTBF muy bajo
        if (_tieneMtbfCritico(mtbf)) ...[
          const SizedBox(height: 8),
          _alerta(
            'Hay activos con MTBF menor a 30 días. '
            'Revisá su plan de mantenimiento preventivo.',
          ),
        ],
      ],
    );
  }

  Color _colorMtbf(double dias) {
    if (dias < 30) return Colors.red;
    if (dias < 60) return Colors.orange;
    return Colors.green;
  }

  Widget _badgeConfiabilidad(String confiabilidad) {
    final colores = {
      'baja': Colors.grey,
      'media': Colors.orange,
      'alta': Colors.green,
    };
    final labels = {
      'baja': 'Baja',
      'media': 'Media',
      'alta': 'Alta',
    };
    final color = colores[confiabilidad] ?? Colors.grey;
    final label = labels[confiabilidad] ?? confiabilidad;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 10,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  bool _tieneMtbfCritico(List<Map<String, dynamic>> mtbf) {
    for (final fila in mtbf) {
      final dias = (fila['mtbf_dias'] as num?)?.toDouble() ?? 0;
      if (dias < 30) return true;
    }
    return false;
  }

  // ============================================
  // Helpers de UI
  // ============================================
  Color _colorPrioridad(String p) {
    switch (p) {
      case 'baja':
        return Colors.green;
      case 'media':
        return Colors.orange;
      case 'alta':
        return Colors.deepOrange;
      case 'critica':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _labelPrioridad(String p) {
    if (p.isEmpty) return '-';
    return p[0].toUpperCase() + p.substring(1);
  }

  Widget _sinDatos(String mensaje) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.bar_chart_outlined, size: 32, color: Colors.grey[300]),
          const SizedBox(height: 8),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _estadoVacio(IconData icono, String mensaje, {VoidCallback? accion}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[600]),
            ),
            if (accion != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: accion,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _alerta(String texto) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange[700], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(color: Colors.orange[900], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

const _thStyle = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54);

class _CardKpi extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final Widget child;

  const _CardKpi({
    required this.titulo,
    required this.icono,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 18, color: const Color(0xFF1F4E79)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}