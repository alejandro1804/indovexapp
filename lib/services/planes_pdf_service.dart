import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/plan_mantenimiento.dart';

class PlanesPdfService {
  static Future<void> generarYCompartir({
    required List<PlanMantenimiento> planes,
    required String nombreEmpresa,
    String? busqueda,
  }) async {
    final pdf = pw.Document();
    final ahora = DateTime.now();

    String fmtCorto(DateTime f) {
      final l = f.toLocal();
      String d(int n) => n.toString().padLeft(2, '0');
      return '${d(l.day)}/${d(l.month)}/${l.year}';
    }

    String labelIntervalo(String tipo) {
      switch (tipo) {
        case 'dias':   return 'Días';
        case 'horas':  return 'Horas';
        case 'ciclos': return 'Ciclos';
        case 'm3':     return 'm³';
        default:       return tipo;
      }
    }

    String frecuenciaLabel(PlanMantenimiento p) {
      final valor = p.intervaloValor.truncateToDouble() == p.intervaloValor
          ? p.intervaloValor.toInt().toString()
          : p.intervaloValor.toStringAsFixed(1);
      return 'Cada $valor ${p.unidadIntervalo}';
    }

    String proximoLabel(PlanMantenimiento p) {
      if (p.proximoValor == null) return '-';
      final valor = p.proximoValor!.truncateToDouble() == p.proximoValor
          ? p.proximoValor!.toInt().toString()
          : p.proximoValor!.toStringAsFixed(1);
      return '$valor ${p.unidadIntervalo}';
    }

    // Resumen de filtros
    final filtros = <String>[];
    if (busqueda != null && busqueda.trim().isNotEmpty) filtros.add('Búsqueda: "${busqueda.trim()}"');
    final filtrosTexto = filtros.isEmpty ? 'Sin filtros (todos los planes activos)' : filtros.join('  |  ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
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
                  pw.Text('INDOVEXAPP', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1F4E79'))),
                  pw.Text('Planes de Mantenimiento', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
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
            'Página ${context.pageNumber} de ${context.pagesCount}  —  IndovexApp',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
        build: (context) => [
          // Resumen
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
                pw.Text('Total: ${planes.length} plan${planes.length != 1 ? 'es' : ''}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
          // Tabla
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.0), // Máquina
              1: const pw.FlexColumnWidth(3.0), // Tarea
              2: const pw.FlexColumnWidth(1.2), // Tipo intervalo
              3: const pw.FlexColumnWidth(1.5), // Frecuencia
              4: const pw.FlexColumnWidth(1.5), // Próximo
              5: const pw.FlexColumnWidth(1.2), // Creado
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1F4E79')),
                children: [
                  _celda('Máquina', header: true),
                  _celda('Tarea', header: true),
                  _celda('Intervalo', header: true),
                  _celda('Frecuencia', header: true),
                  _celda('Próximo', header: true),
                  _celda('Creado', header: true),
                ],
              ),
              ...planes.map((p) => pw.TableRow(
                children: [
                  _celda(p.nombreMaquina != null && p.codigoMaquina != null
                      ? '${p.nombreMaquina} (${p.codigoMaquina})'
                      : p.nombreMaquina ?? '-'),
                  _celda(p.descripcionTarea),
                  _celda(labelIntervalo(p.tipoIntervalo)),
                  _celda(frecuenciaLabel(p)),
                  _celda(proximoLabel(p)),
                  _celda(fmtCorto(p.createdAt)),
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
      filename: 'planes_mantenimiento_indovexapp_${ahora.millisecondsSinceEpoch}.pdf',
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
        maxLines: 3,
      ),
    );
  }
}