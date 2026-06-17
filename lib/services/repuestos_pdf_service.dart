import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/repuesto.dart';

class RepuestosPdfService {
  static Future<void> generarYCompartir({
    required List<Repuesto> repuestos,
    required String nombreEmpresa,
    required Map<String, String> categorias, // categoriaId -> nombre
    String? filtroCategoria,
    bool soloStockBajo = false,
    String? busqueda,
  }) async {
    final pdf = pw.Document();
    final ahora = DateTime.now();

    String fmtCorto(DateTime f) {
      final l = f.toLocal();
      String d(int n) => n.toString().padLeft(2, '0');
      return '${d(l.day)}/${d(l.month)}/${l.year} ${d(l.hour)}:${d(l.minute)}';
    }

    // Resumen de filtros
    final filtros = <String>[];
    if (filtroCategoria != null && filtroCategoria != 'todos') filtros.add('Categoría: ${categorias[filtroCategoria] ?? filtroCategoria}');
    if (soloStockBajo) filtros.add('Solo stock bajo');
    if (busqueda != null && busqueda.trim().isNotEmpty) filtros.add('Búsqueda: "${busqueda.trim()}"');
    final filtrosTexto = filtros.isEmpty ? 'Sin filtros (todos los repuestos)' : filtros.join('  |  ');

    final stockBajoCount = repuestos.where((r) => r.stockBajo).length;

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
                  pw.Text('INDOVEXAPP', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1F4E79'))),
                  pw.Text('Listado de Repuestos', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
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
          // Resumen de filtros
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
                pw.Text(
                  'Total: ${repuestos.length} repuesto${repuestos.length != 1 ? 's' : ''}${stockBajoCount > 0 ? '  |  ⚠ $stockBajoCount con stock bajo' : ''}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
          // Tabla
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2), // Código
              1: const pw.FlexColumnWidth(2.8), // Descripción
              2: const pw.FlexColumnWidth(1.8), // Categoría
              3: const pw.FlexColumnWidth(1.0), // Stock actual
              4: const pw.FlexColumnWidth(1.0), // Stock mínimo
              5: const pw.FlexColumnWidth(1.2), // Unidad
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1F4E79')),
                children: [
                  _celda('Código', header: true),
                  _celda('Descripción', header: true),
                  _celda('Categoría', header: true),
                  _celda('Stock', header: true),
                  _celda('Mínimo', header: true),
                  _celda('Unidad', header: true),
                ],
              ),
              ...repuestos.map((r) {
                final stockBajo = r.stockBajo;
                return pw.TableRow(
                  decoration: stockBajo
                      ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFFF3E0)) // naranja muy suave
                      : null,
                  children: [
                    _celda(r.codigo, stockBajo: stockBajo),
                    _celda(r.descripcion, stockBajo: stockBajo),
                    _celda(categorias[r.categoriaId] ?? 'Sin categoría', stockBajo: stockBajo),
                    _celda('${r.stockActual}', stockBajo: stockBajo),
                    _celda('${r.stockMinimo}', stockBajo: stockBajo),
                    _celda(r.unidadMedida, stockBajo: stockBajo),
                  ],
                );
              }),
            ],
          ),
          if (stockBajoCount > 0)
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                '⚠ Las filas resaltadas tienen stock por debajo del mínimo.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.orange),
              ),
            ),
        ],
      ),
    );

    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'repuestos_indovexapp_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _celda(String texto, {bool header = false, bool stockBajo = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontSize: header ? 9 : 8,
          fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header
              ? PdfColors.white
              : stockBajo
                  ? PdfColors.orange
                  : PdfColors.black,
        ),
      ),
    );
  }
}