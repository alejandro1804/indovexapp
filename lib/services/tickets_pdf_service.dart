import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TicketsPdfService {
  static Future<void> generarYCompartir({
    required List<Map<String, dynamic>> tickets,
    required String nombreEmpresa,
    String? filtroEstado,
    String? filtroTipo,
    String? filtroPrioridad,
    String? filtroSector,
    String? busqueda,
  }) async {
    final pdf = pw.Document();
    final ahora = DateTime.now();

    String fmtCorto(DateTime f) {
      final l = f.toLocal();
      String d(int n) => n.toString().padLeft(2, '0');
      return '${d(l.day)}/${d(l.month)}/${l.year} ${d(l.hour)}:${d(l.minute)}';
    }

    String labelEstado(String e) {
      switch (e) {
        case 'abierto':    return 'Abierto';
        case 'asignado':   return 'Asignado';
        case 'en_proceso': return 'En proceso';
        case 'resuelto':   return 'Resuelto';
        case 'cerrado':    return 'Cerrado';
        case 'rechazado':  return 'Rechazado';
        default:           return e;
      }
    }

    String labelTipo(String t) => t == 'preventivo' ? 'Preventivo' : 'Correctivo';

    String labelPrioridad(String p) {
      switch (p) {
        case 'baja':    return 'Baja';
        case 'media':   return 'Media';
        case 'alta':    return 'Alta';
        case 'critica': return 'Crítica';
        default:        return p;
      }
    }

    final filtros = <String>[];
    if (filtroEstado != null && filtroEstado != 'todos') filtros.add('Estado: ${labelEstado(filtroEstado)}');
    if (filtroTipo != null && filtroTipo != 'todos') filtros.add('Tipo: ${labelTipo(filtroTipo)}');
    if (filtroPrioridad != null && filtroPrioridad != 'todos') filtros.add('Prioridad: ${labelPrioridad(filtroPrioridad)}');
    if (filtroSector != null && filtroSector != 'todos') filtros.add('Ubicacion filtrada');
    if (busqueda != null && busqueda.trim().isNotEmpty) filtros.add('Búsqueda: "${busqueda.trim()}"');
    final filtrosTexto = filtros.isEmpty ? 'Sin filtros (todos los tickets)' : filtros.join('  |  ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
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
                  pw.Text(nombreEmpresa,
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1F4E79'))),
                  pw.Text('Listado de Tickets',
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),

                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generado: ${fmtCorto(ahora)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
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
                pw.Text('Total: ${tickets.length} ticket${tickets.length != 1 ? 's' : ''}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.0),
              1: const pw.FlexColumnWidth(2.2),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(3.0),
              4: const pw.FlexColumnWidth(1.0),
              5: const pw.FlexColumnWidth(1.0),
              6: const pw.FlexColumnWidth(1.2),
              7: const pw.FlexColumnWidth(1.5),
              8: const pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1F4E79')),
                children: [
                  _celda('Nº', header: true),
                  _celda('Activo', header: true),
                  _celda('Ubicacion', header: true),
                  _celda('Descripción', header: true),
                  _celda('Tipo', header: true),
                  _celda('Prioridad', header: true),
                  _celda('Estado', header: true),
                  _celda('Técnico', header: true),
                  _celda('Fecha', header: true),
                ],
              ),
              ...tickets.map((t) {
                final maquina = t['maquinas'] as Map?;
                final sector = (maquina?['sectores'] as Map?)?['nombre'] as String? ?? '-';
                final fecha = DateTime.tryParse(t['created_at'] ?? '');
                final fechaStr = fecha != null ? fmtCorto(fecha) : '-';
                final tipo = t['tipo'] as String? ?? 'correctivo';
                final prioridad = t['prioridad'] as String? ?? 'media';
                final estado = t['estado'] as String? ?? '';
                return pw.TableRow(
                  children: [
                    _celda(t['numero'] ?? '-'),
                    _celda(maquina?['nombre'] ?? '-'),
                    _celda(sector),
                    _celda(t['descripcion_desperfecto'] ?? '-'),
                    _celda(labelTipo(tipo)),
                    _celda(labelPrioridad(prioridad)),
                    _celda(labelEstado(estado)),
                    _celda(t['nombre_tecnico'] ?? '-'),
                    _celda(fechaStr),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 16),
          _notaPie(),
        ],
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'tickets_indovexapp_${ahora.millisecondsSinceEpoch}.pdf',
    );
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
        maxLines: 2,
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