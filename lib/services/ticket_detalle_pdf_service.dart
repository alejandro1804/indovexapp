import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TicketDetallePdfService {
  static Future<void> generarYCompartir({
    required Map<String, dynamic> ticket,
    required List<Map<String, dynamic>> historial,
    required String nombreEmpresa,
    required String nombreCreadoPor,
    required String nombreTecnico,
  }) async {
    final pdf = pw.Document();
    final ahora = DateTime.now();
    final colorAzul = PdfColor.fromHex('#1F4E79');

    String fmtCorto(DateTime? f) {
      if (f == null) return '-';
      final l = f.toLocal();
      String d(int n) => n.toString().padLeft(2, '0');
      return '${d(l.day)}/${d(l.month)}/${l.year} ${d(l.hour)}:${d(l.minute)}';
    }

    String fmtAuditoria(DateTime? f) {
      if (f == null) return '-';
      final l = f.toLocal();
      String d(int n) => n.toString().padLeft(2, '0');
      final offset = l.timeZoneOffset;
      final signo = offset.isNegative ? '-' : '+';
      return '${l.year}-${d(l.month)}-${d(l.day)} ${d(l.hour)}:${d(l.minute)}:${d(l.second)} (UTC$signo${offset.inHours.abs()})';
    }

    String labelEstado(String e) {
      switch (e) {
        case 'abierto':    return 'Abierto';
        case 'asignado':   return 'Asignado';
        case 'en_proceso': return 'En proceso';
        case 'pausado':    return 'Pausado';
        case 'resuelto':   return 'Resuelto';
        case 'cerrado':    return 'Cerrado';
        case 'rechazado':  return 'Rechazado';
        default:           return e;
      }
    }

    final maquina = ticket['maquinas'] as Map<String, dynamic>?;
    final sector = (maquina?['sectores'] as Map?)?['nombre'] as String? ?? '-';
    final tipo = ticket['tipo'] as String? ?? 'correctivo';
    final prioridad = ticket['prioridad'] as String? ?? 'media';
    final estado = ticket['estado'] as String? ?? '-';
    final numero = ticket['numero'] as String? ?? '-';
    final fecha = DateTime.tryParse(ticket['created_at'] ?? '');
    final fechaCierre = ticket['fecha_cierre'] != null
        ? DateTime.tryParse(ticket['fecha_cierre'])
        : null;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          margin: const pw.EdgeInsets.only(bottom: 16),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(nombreEmpresa,
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: colorAzul)),
                  pw.Text('Detalle de Ticket — $numero',
                      style: const pw.TextStyle(
                          fontSize: 11, color: PdfColors.grey700)),

                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generado: ${fmtCorto(ahora)}',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}  —  IndovexApp',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            margin: const pw.EdgeInsets.only(bottom: 16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(children: [
              _badge('Estado', labelEstado(estado)),
              pw.SizedBox(width: 24),
              _badge('Tipo', tipo == 'preventivo' ? 'Preventivo' : 'Correctivo'),
              pw.SizedBox(width: 24),
              _badge('Prioridad', prioridad[0].toUpperCase() + prioridad.substring(1)),
            ]),
          ),
          _seccion('Información general', colorAzul),
          _fila('Máquina', maquina?['nombre'] ?? '-'),
          _fila('Código', maquina?['codigo'] ?? '-'),
          _fila('Ubicacion', sector),
          _fila('Creado por', nombreCreadoPor.isNotEmpty ? nombreCreadoPor : '-'),
          if (nombreTecnico.isNotEmpty) _fila('Técnico', nombreTecnico),
          _fila('Fecha apertura', fmtAuditoria(fecha)),
          if (fechaCierre != null) _fila('Fecha cierre', fmtAuditoria(fechaCierre)),
          pw.SizedBox(height: 12),
          _seccion('Descripción', colorAzul),
          pw.Text(ticket['descripcion_desperfecto'] ?? '-',
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          if (ticket['observacion_tecnico'] != null) ...[
            _seccion('Observación del técnico', colorAzul),
            pw.Text(ticket['observacion_tecnico'],
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
          ],
          if (ticket['observacion_encargado'] != null) ...[
            _seccion('Observación del encargado', colorAzul),
            pw.Text(ticket['observacion_encargado'],
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
          ],
          _seccion('Historial de cambios de estado', colorAzul),
          if (historial.isEmpty)
            pw.Text('Sin historial registrado.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.0),
                1: const pw.FlexColumnWidth(2.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(2.5),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: colorAzul),
                  children: [
                    _celda('Cambio de estado', header: true),
                    _celda('Comentario', header: true),
                    _celda('Usuario', header: true),
                    _celda('Fecha', header: true),
                  ],
                ),
                ...historial.reversed.map((h) {
                  final fechaH = DateTime.tryParse(h['fecha'] ?? '');
                  final estadoAnterior = h['estado_anterior'] != null
                      ? '${labelEstado(h['estado_anterior'])} → '
                      : '';
                  return pw.TableRow(children: [
                    _celda('$estadoAnterior${labelEstado(h['estado_nuevo'])}'),
                    _celda(h['comentario'] ?? '-'),
                    _celda((h['usuarios'] as Map?)?['nombre'] ?? '-'),
                    _celda(fmtAuditoria(fechaH)),
                  ]);
                }),
              ],
            ),
          pw.SizedBox(height: 20),
          _notaPie(),
        ],
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'ticket_${numero}_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _seccion(String titulo, PdfColor color) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 4),
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: color, width: 0.8)),
      ),
      child: pw.Text(titulo,
          style: pw.TextStyle(
              fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
    );
  }

  static pw.Widget _fila(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(
          width: 110,
          child: pw.Text(label,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ),
        pw.Expanded(
          child: pw.Text(valor,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ),
      ]),
    );
  }

  static pw.Widget _badge(String label, String valor) {
    return pw.Row(children: [
      pw.Text('$label: ',
          style: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
      pw.Text(valor, style: const pw.TextStyle(fontSize: 9)),
    ]);
  }

  static pw.Widget _celda(String texto, {bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontSize: header ? 8 : 7,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? PdfColors.white : PdfColors.black,
        ),
        maxLines: 3,
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
        'Documento generado por IndovexApp. La distribución de este reporte es responsabilidad del Cliente como titular de los datos.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }
}