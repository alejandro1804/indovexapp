import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Servicio de exportación de datos de una empresa (portabilidad / baja voluntaria).
///
/// Genera un ZIP con:
///  - Un CSV por cada tabla de la empresa (tickets, máquinas, repuestos, etc.)
///  - audit_log.csv (trazabilidad ALCOA+)
///  - archivos_descarga.csv: lista de archivos de Storage con signed URLs (5 días)
///
/// Los archivos binarios NO se reempaquetan en el ZIP; se entregan como links
/// firmados, lo que evita límites de memoria y funciona a cualquier escala.
class ExportEmpresaService {
  ExportEmpresaService(this._supabase);

  final SupabaseClient _supabase;

  // 5 días de validez para los links de descarga.
  static const int _signedUrlSeconds = 5 * 24 * 3600; // 432000

  // Bucket donde viven imágenes y adjuntos.
  static const String _bucket = 'documentos';

  /// Orden y nombres de las secciones tal como vienen del JSON de sa_export_empresa.
  static const List<String> _secciones = [
    'empresa',
    'sectores',
    'maquinas',
    'repuestos',
    'categorias_repuestos',
    'proveedores',
    'planes_mantenimiento',
    'tickets',
    'ticket_historial',
    'usuarios',
    'audit_log',
    'ticket_fotos',
    'maquina_documentos',
    'adjuntos',
  ];

  /// Ejecuta el export completo y dispara la descarga del ZIP.
  /// Devuelve la cantidad de archivos de Storage incluidos como links.
  Future<int> exportar({
    required String empresaId,
    required String empresaNombre,
  }) async {
    // 1. Traer todos los datos en un solo JSON.
    final data = await _supabase
        .rpc('sa_export_empresa', params: {'p_empresa_id': empresaId});
    final Map<String, dynamic> json = Map<String, dynamic>.from(data as Map);

    final archive = Archive();

    // 2. Un CSV por sección.
    for (final seccion in _secciones) {
      final contenido = json[seccion];
      final List<Map<String, dynamic>> filas = _normalizarSeccion(contenido);
      final csv = _filasACsv(filas);
      final bytes = _utf8ConBom(csv);
      archive.addFile(ArchiveFile('$seccion.csv', bytes.length, bytes));
    }

    // 3. Recolectar paths de Storage y generar signed URLs.
    final paths = _recolectarPaths(json);
    final List<List<String>> indiceArchivos = [
      ['origen', 'path', 'link_descarga (válido 5 días)'],
    ];
    int archivosOk = 0;

    for (final entrada in paths) {
      try {
        final signed = await _supabase.storage
            .from(_bucket)
            .createSignedUrl(entrada.path, _signedUrlSeconds);
        indiceArchivos.add([entrada.origen, entrada.path, signed]);
        archivosOk++;
      } catch (_) {
        // Si un archivo no existe o falla, lo registramos igual sin link.
        indiceArchivos.add([entrada.origen, entrada.path, 'ERROR: no disponible']);
      }
    }

    final indiceCsv = const ListToCsvConverter().convert(indiceArchivos);
    final indiceBytes = _utf8ConBom(indiceCsv);
    archive.addFile(
        ArchiveFile('archivos_descarga.csv', indiceBytes.length, indiceBytes));

    // 4. README explicativo.
    final readme = _readme(empresaNombre, archivosOk);
    final readmeBytes = _utf8ConBom(readme);
    archive.addFile(ArchiveFile('LEEME.txt', readmeBytes.length, readmeBytes));

    // 4b. PDF resumen (constancia presentable).
    final pdfBytes = await _generarPdfResumen(json, empresaNombre, archivosOk);
    archive.addFile(ArchiveFile('resumen.pdf', pdfBytes.length, pdfBytes));

    // 5. Comprimir y descargar.
    final zipData = ZipEncoder().encode(archive);
    final zipBytes = Uint8List.fromList(zipData!);

    final fecha = DateTime.now();
    final nombreArchivo =
        'export_${_slug(empresaNombre)}_${fecha.year}-${_dosD(fecha.month)}-${_dosD(fecha.day)}.zip';

    await Printing.sharePdf(bytes: zipBytes, filename: nombreArchivo);

    return archivosOk;
  }

  // ── Helpers ──

  /// Convierte el contenido de una sección a lista de mapas.
  /// 'empresa' viene como objeto único; el resto como arrays.
  List<Map<String, dynamic>> _normalizarSeccion(dynamic contenido) {
    if (contenido == null) return [];
    if (contenido is List) {
      return contenido.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (contenido is Map) {
      return [Map<String, dynamic>.from(contenido)];
    }
    return [];
  }

  /// Convierte una lista de mapas a CSV. La primera fila son los encabezados,
  /// tomados de la unión de todas las claves presentes.
  String _filasACsv(List<Map<String, dynamic>> filas) {
    if (filas.isEmpty) return '';

    // Encabezados: unión de claves preservando el orden de aparición.
    final headers = <String>[];
    for (final fila in filas) {
      for (final k in fila.keys) {
        if (!headers.contains(k)) headers.add(k);
      }
    }

    final rows = <List<dynamic>>[headers];
    for (final fila in filas) {
      rows.add(headers.map((h) => _valorCsv(fila[h])).toList());
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Aplana valores complejos (mapas/listas) a texto para el CSV.
  dynamic _valorCsv(dynamic v) {
    if (v == null) return '';
    if (v is Map || v is List) return v.toString();
    return v;
  }

  /// Recorre los datos buscando paths de Storage en campos conocidos.
  List<_PathStorage> _recolectarPaths(Map<String, dynamic> json) {
    final paths = <_PathStorage>[];

    void agregarDesde(String seccion, String campo) {
      final lista = _normalizarSeccion(json[seccion]);
      for (final fila in lista) {
        final valor = fila[campo];
        if (valor != null && valor.toString().trim().isNotEmpty) {
          paths.add(_PathStorage(seccion, _normalizarPath(valor.toString())));
        }
      }
    }

    // Campos que contienen paths de Storage según el esquema real.
    agregarDesde('maquinas', 'imagen_url');
    agregarDesde('repuestos', 'imagen_url');
    agregarDesde('tickets', 'foto_url');
    agregarDesde('ticket_fotos', 'foto_url');
    agregarDesde('maquina_documentos', 'url');
    agregarDesde('adjuntos', 'storage_path');

    return paths;
  }

  /// Devuelve el path relativo al bucket. Si el valor es una URL completa
  /// (https://.../object/.../documentos/<path>), extrae solo <path>.
  String _normalizarPath(String valor) {
    final v = valor.trim();
    if (!v.startsWith('http')) return v; // ya es path relativo
    // Buscar el segmento del bucket en la URL y quedarnos con lo que sigue.
    final marcador = '/$_bucket/';
    final idx = v.indexOf(marcador);
    if (idx >= 0) {
      var rel = v.substring(idx + marcador.length);
      // Quitar query string de signed URLs si la hubiera.
      final q = rel.indexOf('?');
      if (q >= 0) rel = rel.substring(0, q);
      return rel;
    }
    return v; // no se pudo extraer, devolver tal cual
  }

  Uint8List _utf8ConBom(String texto) {
    // BOM UTF-8 para que Excel abra acentos correctamente.
    final bom = [0xEF, 0xBB, 0xBF];
    final bytes = texto.codeUnits;
    return Uint8List.fromList([...bom, ...bytes]);
  }

  /// Genera un PDF resumen (constancia de exportación) con el estilo de IndovexApp.
  Future<Uint8List> _generarPdfResumen(
      Map<String, dynamic> json, String empresaNombre, int archivosOk) async {
    final pdf = pw.Document();
    final ahora = DateTime.now();
    final azul = PdfColor.fromHex('#1F4E79');

    String fmtCorto(DateTime f) {
      final l = f.toLocal();
      String d(int n) => n.toString().padLeft(2, '0');
      return '${d(l.day)}/${d(l.month)}/${l.year} ${d(l.hour)}:${d(l.minute)}';
    }

    int contar(String seccion) => _normalizarSeccion(json[seccion]).length;

    final empresa = _normalizarSeccion(json['empresa']);
    final emp = empresa.isNotEmpty ? empresa.first : <String, dynamic>{};

    // Filas de datos de la empresa.
    final datosEmpresa = <List<String>>[
      ['Nombre', (emp['nombre'] ?? empresaNombre).toString()],
      ['RUT', (emp['rut'] ?? '-').toString()],
      ['Email de contacto', (emp['email_contacto'] ?? '-').toString()],
      ['Estado', (emp['estado'] ?? '-').toString()],
      ['Registrada', _fechaSolo(emp['created_at'])],
    ];

    // Conteos del contenido exportado.
    final conteos = <List<String>>[
      ['Sectores', contar('sectores').toString()],
      ['Máquinas', contar('maquinas').toString()],
      ['Repuestos', contar('repuestos').toString()],
      ['Categorías de repuestos', contar('categorias_repuestos').toString()],
      ['Proveedores', contar('proveedores').toString()],
      ['Planes de mantenimiento', contar('planes_mantenimiento').toString()],
      ['Tickets', contar('tickets').toString()],
      ['Historial de tickets', contar('ticket_historial').toString()],
      ['Usuarios', contar('usuarios').toString()],
      ['Registros de auditoría', contar('audit_log').toString()],
      ['Archivos adjuntos (enlaces)', archivosOk.toString()],
    ];

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
                  pw.Text(empresaNombre,
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: azul)),
                  pw.Text('Constancia de Exportación de Datos',
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
          pw.Text('Datos de la empresa',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: azul)),
          pw.SizedBox(height: 6),
          _tablaDatos(datosEmpresa),
          pw.SizedBox(height: 18),
          pw.Text('Contenido exportado',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: azul)),
          pw.SizedBox(height: 6),
          _tablaConteos(conteos, azul),
          pw.SizedBox(height: 18),
          _notaPie(),
        ],
      ),
    );

    final bytes = await pdf.save();
    return Uint8List.fromList(bytes);
  }

  pw.Widget _tablaDatos(List<List<String>> filas) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(2.5),
      },
      children: filas
          .map((f) => pw.TableRow(children: [
                _celdaPdf(f[0], bold: true),
                _celdaPdf(f[1]),
              ]))
          .toList(),
    );
  }

  pw.Widget _tablaConteos(List<List<String>> filas, PdfColor azul) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: azul),
          children: [
            _celdaPdf('Tipo de registro', header: true),
            _celdaPdf('Cantidad', header: true),
          ],
        ),
        ...filas.map((f) => pw.TableRow(children: [
              _celdaPdf(f[0]),
              _celdaPdf(f[1]),
            ])),
      ],
    );
  }

  pw.Widget _celdaPdf(String texto, {bool header = false, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
          fontSize: header ? 9 : 8,
          fontWeight: (header || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: header ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
  }

  pw.Widget _notaPie() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'Documento generado por IndovexApp. El detalle completo de cada registro se '
        'encuentra en los archivos CSV de este paquete. Los enlaces de descarga de '
        'archivos adjuntos son válidos por 5 días. La distribución de esta información '
        'es responsabilidad del Cliente como titular de los datos.',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  String _fechaSolo(dynamic fecha) {
    if (fecha == null) return '-';
    final d = DateTime.tryParse(fecha.toString());
    if (d == null) return '-';
    final l = d.toLocal();
    String dd(int n) => n.toString().padLeft(2, '0');
    return '${dd(l.day)}/${dd(l.month)}/${l.year}';
  }

  String _readme(String empresa, int archivos) {
    final ahora = DateTime.now().toString().split('.').first;
    return 'EXPORTACIÓN DE DATOS — IndovexApp\r\n'
        '====================================\r\n\r\n'
        'Empresa: $empresa\r\n'
        'Generado: $ahora\r\n\r\n'
        'Este paquete contiene todos los registros de tu empresa en formato CSV,\r\n'
        'abribles con Excel, Google Sheets o cualquier herramienta de planillas.\r\n\r\n'
        'resumen.pdf — Constancia de exportación con los datos de la empresa y\r\n'
        '              el conteo de registros incluidos.\r\n\r\n'
        'ARCHIVOS DE REGISTROS:\r\n'
        ' - empresa.csv, sectores.csv, maquinas.csv, repuestos.csv,\r\n'
        '   categorias_repuestos.csv, proveedores.csv, planes_mantenimiento.csv,\r\n'
        '   tickets.csv, ticket_historial.csv, usuarios.csv, audit_log.csv,\r\n'
        '   ticket_fotos.csv, maquina_documentos.csv, adjuntos.csv\r\n\r\n'
        'ARCHIVOS ADJUNTOS (fotos, documentos):\r\n'
        ' - archivos_descarga.csv contiene $archivos enlace(s) de descarga.\r\n'
        ' - IMPORTANTE: los enlaces son válidos por 5 días desde la generación.\r\n'
        '   Descargá los archivos antes de que venzan.\r\n\r\n'
        'IndovexApp — indovexapp.com\r\n';
  }

  String _slug(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _dosD(int n) => n.toString().padLeft(2, '0');
}

class _PathStorage {
  _PathStorage(this.origen, this.path);
  final String origen;
  final String path;
}