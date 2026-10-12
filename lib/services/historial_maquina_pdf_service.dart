import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'egress_service.dart';
import 'historial_maquina_service.dart';

/// PDF del reporte "Historial de un activo". Mismo estilo que
/// MaquinasPdfService (encabezado, pie, tablas azules, nota final).
class HistorialMaquinaPdfService {
  static final PdfColor _azul = PdfColor.fromHex('#1F4E79');

  static Future<void> generarYCompartir(HistorialMaquina h) async {
    final pdf = pw.Document();
    final ahora = DateTime.now();
    final m = h.maquina;

    // ── Resumen ────────────────────────────────────────────────────────────
    final correctivos = h.tickets.where((t) => t['tipo'] == 'correctivo').length;
    final preventivos = h.tickets.where((t) => t['tipo'] == 'preventivo').length;
    final cerrados = h.tickets.where((t) => t['estado'] == 'cerrado').toList();
    final abiertos = h.tickets
        .where((t) => t['estado'] != 'cerrado' && t['estado'] != 'cancelado')
        .length;

    final horasReparacion = <double>[];
    for (final t in cerrados) {
      final ini = _parse(t['created_at']);
      final fin = _parse(t['fecha_cierre']);
      if (ini != null && fin != null) {
        horasReparacion.add(fin.difference(ini).inMinutes / 60);
      }
    }
    final mttr = horasReparacion.isEmpty
        ? '-'
        : '${(horasReparacion.reduce((a, b) => a + b) / horasReparacion.length).toStringAsFixed(1)} h';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          margin: const pw.EdgeInsets.only(bottom: 16),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(h.nombreEmpresa,
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _azul)),
                  pw.Text('Historial del activo',
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generado: ${_fmtFechaHora(ahora)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          // Guion común: Helvetica no tiene la raya larga.
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}  -  IndovexApp',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
        build: (context) => [
          // ── Ficha ──────────────────────────────────────────────────────
          _caja([
            _par('Activo', '${m['nombre'] ?? '-'}'),
            _par('Código', '${m['codigo'] ?? '-'}'),
            _par('Ubicación', h.nombreSector),
            _par('Estado', _labelEstadoMaquina(m['estado'] as String?)),
            if ((m['descripcion'] as String?)?.trim().isNotEmpty ?? false)
              _par('Descripción', (m['descripcion'] as String).trim()),
            _par('Período', _textoPeriodo(h)),
          ]),

          // ── Resumen ────────────────────────────────────────────────────
          pw.Row(
            children: [
              _kpi('Tickets', '${h.tickets.length}'),
              _kpi('Correctivos', '$correctivos'),
              _kpi('Preventivos', '$preventivos'),
              _kpi('Cerrados', '${cerrados.length}'),
              _kpi('Sin cerrar', '$abiertos'),
              _kpi('MTTR', mttr),
            ],
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, bottom: 12),
            child: pw.Text(
              'MTTR: promedio entre la apertura y el cierre formal de los tickets cerrados (incluye el tiempo en pausa).',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ),

          // ── Tickets ────────────────────────────────────────────────────
          _titulo('Tickets'),
          if (h.tickets.isEmpty)
            _vacio('Sin tickets en el período.')
          else
            _tabla(
              encabezados: ['Nro.', 'Apertura', 'Tipo', 'Prioridad', 'Estado', 'Cierre', 'Técnico', 'Detalle'],
              anchos: [0.8, 1.3, 1.0, 0.9, 1.0, 1.3, 1.3, 3.0],
              filas: h.tickets.map((t) {
                final detalle = [
                  (t['descripcion_desperfecto'] as String?)?.trim() ?? '',
                  if ((t['observacion_tecnico'] as String?)?.trim().isNotEmpty ?? false)
                    'Técnico: ${(t['observacion_tecnico'] as String).trim()}',
                ].where((s) => s.isNotEmpty).join('\n');
                return [
                  '${t['numero'] ?? '-'}',
                  _fmtFechaHora(_parse(t['created_at'])),
                  _labelTipo(t['tipo'] as String?),
                  _labelPrioridad(t['prioridad'] as String?),
                  _labelEstadoTicket(t['estado'] as String?),
                  _fmtFechaHora(_parse(t['fecha_cierre'])),
                  _usuario(h, t['tecnico_id']),
                  _corto(detalle, 300),
                ];
              }).toList(),
            ),

          // ── Planes ─────────────────────────────────────────────────────
          _titulo('Planes de mantenimiento'),
          if (h.planes.isEmpty)
            _vacio('El activo no tiene planes de mantenimiento.')
          else
            _tabla(
              encabezados: ['Tarea', 'Intervalo', 'Último ejecutado', 'Próximo', 'Estado', 'Tickets del plan*'],
              anchos: [3.0, 1.4, 1.2, 1.0, 0.9, 1.3],
              filas: h.planes.map((p) {
                final delPlan = h.tickets.where((t) => t['plan_id'] == p['id']).toList();
                final cerradosPlan = delPlan.where((t) => t['estado'] == 'cerrado').length;
                final tipo = p['tipo_intervalo'] as String?;
                return [
                  _corto('${p['descripcion_tarea'] ?? '-'}', 200),
                  '${_num(p['intervalo_valor'])} ${h.tiposIntervalo[tipo] ?? tipo ?? ''}'.trim(),
                  _num(p['ultimo_valor_ejecutado']),
                  _num(p['proximo_valor']),
                  p['activo'] == true ? 'Activo' : 'Inactivo',
                  '${delPlan.length} generados / $cerradosPlan cerrados',
                ];
              }).toList(),
            ),
          if (h.planes.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                '* Tickets del plan creados dentro del período del reporte.',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
              ),
            ),

          // ── Lecturas ───────────────────────────────────────────────────
          _titulo('Lecturas'),
          if (h.lecturas.isEmpty)
            _vacio('Sin lecturas en el período.')
          else
            _tabla(
              encabezados: ['Fecha', 'Tipo', 'Valor', 'Registró', 'Observación'],
              anchos: [1.1, 1.4, 1.0, 1.6, 3.0],
              filas: h.lecturas.map((l) => [
                    _fmtFecha(l['fecha_lectura'] as String?),
                    '${l['tipo'] ?? '-'}',
                    _num(l['valor']),
                    _usuario(h, l['registrado_por']),
                    _corto((l['observacion'] as String?)?.trim() ?? '', 200),
                  ]).toList(),
            ),

          // ── Adjuntos ───────────────────────────────────────────────────
          _titulo('Documentos adjuntos'),
          if (h.adjuntos.isEmpty)
            _vacio('El activo no tiene documentos adjuntos.')
          else
            _tabla(
              encabezados: ['Archivo', 'Subido', 'Por'],
              anchos: [4.0, 1.4, 1.8],
              filas: h.adjuntos.map((a) => [
                    '${a['nombre_archivo'] ?? '-'}',
                    _fmtFechaHora(_parse(a['created_at'])),
                    _usuario(h, a['subido_por']),
                  ]).toList(),
            ),

          pw.SizedBox(height: 16),
          _notaPie(),
        ],
      ),
    );

    final bytes = await pdf.save();
    await EgressService.registrar(EgressOrigen.pdf, bytes.length);

    final codigo = '${m['codigo'] ?? 'activo'}'.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'historial_activo_${codigo}_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  // ── Formato ──────────────────────────────────────────────────────────────

  static String _d(int n) => n.toString().padLeft(2, '0');

  static DateTime? _parse(dynamic v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static String _fmtFechaHora(DateTime? f) => f == null
      ? '-'
      : '${_d(f.day)}/${_d(f.month)}/${f.year} ${_d(f.hour)}:${_d(f.minute)}';

  static String _fmtDia(DateTime f) => '${_d(f.day)}/${_d(f.month)}/${f.year}';

  /// Columnas date ('YYYY-MM-DD'): sin pasar por zona horaria.
  static String _fmtFecha(String? v) {
    final f = v == null ? null : DateTime.tryParse(v);
    return f == null ? '-' : _fmtDia(f);
  }

  static String _num(dynamic v) {
    if (v == null) return '-';
    final n = v is num ? v : num.tryParse('$v');
    if (n == null) return '$v';
    return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  }

  static String _corto(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}...';

  static String _usuario(HistorialMaquina h, dynamic id) =>
      id is String ? (h.usuarios[id] ?? '-') : '-';

  static String _textoPeriodo(HistorialMaquina h) {
    if (h.desde == null && h.hasta == null) return 'Todo el historial';
    if (h.desde == null) return 'Hasta ${_fmtDia(h.hasta!)}';
    if (h.hasta == null) return 'Desde ${_fmtDia(h.desde!)}';
    return '${_fmtDia(h.desde!)} al ${_fmtDia(h.hasta!)}';
  }

  static String _labelEstadoMaquina(String? e) {
    switch (e) {
      case 'operativa':         return 'Operativa';
      case 'en_mantenimiento':  return 'En mantenimiento';
      case 'fuera_de_servicio': return 'Fuera de servicio';
      case 'dada_de_baja':      return 'Dado de baja';
      default:                  return e ?? '-';
    }
  }

  static String _labelEstadoTicket(String? e) {
    switch (e) {
      case 'abierto':     return 'Abierto';
      case 'en_progreso': return 'En progreso';
      case 'pausado':     return 'Pausado';
      case 'cerrado':     return 'Cerrado';
      case 'cancelado':   return 'Cancelado';
      default:            return e ?? '-';
    }
  }

  static String _labelTipo(String? t) {
    switch (t) {
      case 'correctivo': return 'Correctivo';
      case 'preventivo': return 'Preventivo';
      default:           return t ?? '-';
    }
  }

  static String _labelPrioridad(String? p) {
    switch (p) {
      case 'baja':    return 'Baja';
      case 'media':   return 'Media';
      case 'alta':    return 'Alta';
      case 'critica': return 'Crítica';
      default:        return p ?? '-';
    }
  }

  // ── Bloques ──────────────────────────────────────────────────────────────

  static pw.Widget _titulo(String texto) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(texto,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _azul)),
      );

  static pw.Widget _vacio(String texto) =>
      pw.Text(texto, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600));

  static pw.Widget _caja(List<pw.Widget> hijos) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: hijos),
      );

  static pw.Widget _par(String etiqueta, String valor) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 70,
              child: pw.Text(etiqueta,
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
            ),
            pw.Expanded(child: pw.Text(valor, style: const pw.TextStyle(fontSize: 9))),
          ],
        ),
      );

  static pw.Widget _kpi(String etiqueta, String valor) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.symmetric(horizontal: 2),
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            children: [
              pw.Text(valor,
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _azul)),
              pw.Text(etiqueta, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            ],
          ),
        ),
      );

  static pw.Widget _tabla({
    required List<String> encabezados,
    required List<double> anchos,
    required List<List<String>> filas,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        for (var i = 0; i < anchos.length; i++) i: pw.FlexColumnWidth(anchos[i]),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: pw.BoxDecoration(color: _azul),
          children: encabezados.map((e) => _celda(e, header: true)).toList(),
        ),
        ...filas.map((f) => pw.TableRow(children: f.map(_celda).toList())),
      ],
    );
  }

  static pw.Widget _celda(String texto, {bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontSize: header ? 8 : 7.5,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _notaPie() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'Documento generado por IndovexApp a partir de los registros del sistema, '
        'con fecha, hora y usuario responsable de cada acción. La distribución de '
        'este reporte es responsabilidad del Cliente como titular de los datos.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }
}