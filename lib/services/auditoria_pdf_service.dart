import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/audit_log.dart';

class AuditoriaPdfService {
  static Future<void> generarYCompartir({
    required List<AuditLog> logs,
    required String nombreEmpresa,
    String? filtroTabla,
    String? filtroOperacion,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final pdf = pw.Document();
    final ahora = DateTime.now();

    String fmt(DateTime f) {
      final l = f.toLocal();
      String d(int n) => n.toString().padLeft(2, '0');
      final offset = l.timeZoneOffset;
      final signo = offset.isNegative ? '-' : '+';
      return '${l.year}-${d(l.month)}-${d(l.day)} ${d(l.hour)}:${d(l.minute)}:${d(l.second)} (UTC$signo${offset.inHours.abs()})';
    }

    String fmtCorto(DateTime f) {
      final l = f.toLocal();
      String d(int n) => n.toString().padLeft(2, '0');
      return '${d(l.day)}/${d(l.month)}/${l.year} ${d(l.hour)}:${d(l.minute)}';
    }

    // Resumen de filtros aplicados
    final filtros = <String>[];
    if (filtroTabla != null && filtroTabla != 'todos') filtros.add('Tabla: $filtroTabla');
    if (filtroOperacion != null && filtroOperacion != 'todos') {
      filtros.add('Operación: $filtroOperacion');
    }
    if (desde != null && hasta != null) {
      filtros.add('Período: ${fmtCorto(desde)} a ${fmtCorto(hasta)}');
    }
    final filtrosTexto = filtros.isEmpty ? 'Sin filtros (todos los eventos)' : filtros.join('  |  ');

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
                  pw.Text('INDOVEX', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1F4E79'))),
                  pw.Text('Reporte de Auditoría', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(nombreEmpresa, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Generado: ${fmtCorto(ahora)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}  —  Documento de trazabilidad ALCOA+',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            margin: const pw.EdgeInsets.only(bottom: 12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Filtros aplicados', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Text(filtrosTexto, style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 2),
                pw.Text('Total de eventos: ${logs.length}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.2),
              1: const pw.FlexColumnWidth(1.3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              // Encabezado
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1F4E79')),
                children: [
                  _celda('Fecha', header: true),
                  _celda('Operación', header: true),
                  _celda('Entidad', header: true),
                  _celda('Usuario', header: true),
                ],
              ),
              // Filas
              ...logs.map((log) => pw.TableRow(
                    children: [
                      _celda(fmt(log.createdAt)),
                      _celda(log.operacionLabel),
                      _celda(log.tablaLabel),
                      _celda(log.nombreUsuario ?? 'Sistema'),
                    ],
                  )),
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'auditoria_indovex_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _celda(String texto, {bool header = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontSize: header ? 9 : 8,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }
}