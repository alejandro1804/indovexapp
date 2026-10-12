import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'egress_service.dart';

/// PDF de la grilla de roles x permisos de la empresa.
///
/// Filas: permisos agrupados por módulo. Columnas: roles, con la cantidad
/// de usuarios que tiene cada uno. Una X marca que el rol tiene el permiso.
/// La primera fila es el alcance ("Ver todas las ubicaciones"), que sale de
/// roles.restringe_por_sector mostrado al revés.
class RolesPermisosPdfService {
  /// [roles]: mapas con id, nombre, usuarios (cantidad) y
  /// restringe_por_sector, ya ordenados.
  /// [permisos]: mapas con id, nombre y modulo, ya ordenados por módulo.
  /// [permisosPorRol]: ids de permisos asignados a cada rol (clave: id de rol).
  static Future<void> generarYCompartir({
    required List<Map<String, dynamic>> roles,
    required List<Map<String, dynamic>> permisos,
    required Map<String, Set<String>> permisosPorRol,
    required String nombreEmpresa,
  }) async {
    final pdf = pw.Document();
    final ahora = DateTime.now();
    final azul = PdfColor.fromHex('#1F4E79');

    String fmtFechaHora(DateTime f) {
      final l = f.toLocal();
      String d(int n) => n.toString().padLeft(2, '0');
      return '${d(l.day)}/${d(l.month)}/${l.year} ${d(l.hour)}:${d(l.minute)}';
    }

    String texto(dynamic v) => (v ?? '').toString();

    String titulo(String s) =>
        s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

    String modulo(Map<String, dynamic> p) {
      final m = texto(p['modulo']).trim();
      return m.isEmpty ? 'otros' : m;
    }

    int usuarios(Map<String, dynamic> r) => (r['usuarios'] as int?) ?? 0;

    // Con muchos roles la hoja va apaisada y la letra de los roles se achica.
    final apaisado = roles.length > 5;
    final fuenteRol = roles.length > 10 ? 6.0 : 8.0;

    final filas = <pw.TableRow>[
      // Encabezado: se repite en cada página.
      pw.TableRow(
        repeat: true,
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        decoration: pw.BoxDecoration(color: azul),
        children: [
          _celda('Permiso', header: true),
          for (final r in roles)
            _celdaRol(titulo(texto(r['nombre'])), usuarios(r), fuenteRol),
        ],
      ),
    ];

    // Alcance: grupo propio arriba de los permisos.
    filas.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _celdaModulo('ALCANCE', azul),
        for (final _ in roles) pw.SizedBox(),
      ],
    ));
    filas.add(pw.TableRow(
      verticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        _celda('Ver todas las ubicaciones'),
        for (final r in roles)
          _celdaMarca(r['restringe_por_sector'] != true, azul),
      ],
    ));

    String? moduloActual;
    for (final p in permisos) {
      final m = modulo(p);
      if (m != moduloActual) {
        moduloActual = m;
        filas.add(pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _celdaModulo(m.toUpperCase(), azul),
            for (final _ in roles) pw.SizedBox(),
          ],
        ));
      }
      filas.add(pw.TableRow(
        verticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          _celda(texto(p['nombre'])),
          for (final r in roles)
            _celdaMarca(
                permisosPorRol[r['id']]?.contains(p['id']) ?? false, azul),
        ],
      ));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: apaisado ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
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
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: azul)),
                  pw.Text('Roles y permisos',
                      style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                  pw.Text('Generado con IndovexApp',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Generado: ${fmtFechaHora(ahora)}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          // Guion común: la fuente por defecto del PDF (Helvetica) no tiene
          // la raya larga y la dibuja como glifo faltante.
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}  -  IndovexApp',
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
                pw.Text('Referencias', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.SizedBox(height: 2),
                pw.Text('X = el rol tiene el permiso. Debajo de cada rol, la cantidad de usuarios que lo tienen asignado.',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 2),
                pw.Text('Alcance: un rol sin "Ver todas las ubicaciones" ve solo las ubicaciones asignadas a cada usuario.',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 2),
                pw.Text('Total: ${roles.length} rol${roles.length != 1 ? 'es' : ''}  |  ${permisos.length} permiso${permisos.length != 1 ? 's' : ''}',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3.0),
              for (var i = 1; i <= roles.length; i++)
                i: const pw.FlexColumnWidth(1.0),
            },
            children: filas,
          ),
          pw.SizedBox(height: 16),
          _notaPie(),
        ],
      ),
    );

    final bytes = await pdf.save();
    await EgressService.registrar(EgressOrigen.pdf, bytes.length);
    await Printing.sharePdf(
      bytes: Uint8List.fromList(bytes),
      filename: 'roles_permisos_indovexapp_${ahora.millisecondsSinceEpoch}.pdf',
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

  static pw.Widget _celdaRol(String nombre, int usuarios, double fuente) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      child: pw.Column(
        children: [
          pw.Text(
            nombre,
            textAlign: pw.TextAlign.center,
            maxLines: 2,
            style: pw.TextStyle(
              fontSize: fuente,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            '$usuarios ${usuarios == 1 ? 'usuario' : 'usuarios'}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: fuente - 1, color: PdfColors.white),
          ),
        ],
      ),
    );
  }

  static pw.Widget _celdaModulo(String texto, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
        maxLines: 1,
      ),
    );
  }

  static pw.Widget _celdaMarca(bool marcada, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        marcada ? 'X' : '',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: color,
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
        'Documento generado por IndovexApp. La distribución de este reporte es responsabilidad del Cliente como titular de los datos.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }
}