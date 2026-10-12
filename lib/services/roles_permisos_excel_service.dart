import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:printing/printing.dart';
import 'egress_service.dart';

/// Planilla Excel (.xlsx) de la grilla de roles x permisos de la empresa.
///
/// Un .xlsx es un ZIP con archivos XML adentro, así que se arma con el
/// paquete archive (el mismo del export de empresa) y no hace falta sumar
/// un paquete de Excel.
///
/// Columnas: Módulo, Permiso y una por rol. Una X marca que el rol tiene el
/// permiso. La planilla sale con filtros y con los encabezados inmovilizados.
class RolesPermisosExcelService {
  static const _hoja = 'Grilla';

  // Fila del encabezado de la tabla (arriba van título y fecha).
  static const _filaEncabezado = 5;

  // Índices de estilo: tienen que coincidir con el orden de cellXfs en _estilos.
  static const _sTitulo = 1;
  static const _sSubtitulo = 2;
  static const _sNota = 3;
  static const _sEncabezado = 4;
  static const _sTexto = 5;
  static const _sMarca = 6;

  /// [roles]: mapas con id, nombre y usuarios (cantidad), ya ordenados.
  /// [permisos]: mapas con id, nombre y modulo, ya ordenados por módulo.
  /// [permisosPorRol]: ids de permisos asignados a cada rol (clave: id de rol).
  ///
  /// Devuelve false si el usuario canceló el guardado.
  static Future<bool> generarYGuardar({
    required List<Map<String, dynamic>> roles,
    required List<Map<String, dynamic>> permisos,
    required Map<String, Set<String>> permisosPorRol,
    required String nombreEmpresa,
  }) async {
    final ahora = DateTime.now();

    final archive = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypes))
      ..addFile(ArchiveFile.string('_rels/.rels', _rels))
      ..addFile(ArchiveFile.string(
          'xl/workbook.xml', _workbook(roles.length, permisos.length)))
      ..addFile(ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRels))
      ..addFile(ArchiveFile.string('xl/styles.xml', _estilos))
      ..addFile(ArchiveFile.string(
        'xl/worksheets/sheet1.xml',
        _hojaXml(
          roles: roles,
          permisos: permisos,
          permisosPorRol: permisosPorRol,
          nombreEmpresa: nombreEmpresa,
          ahora: ahora,
        ),
      ));

    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    await EgressService.registrar(EgressOrigen.export, bytes.length);

    final nombre = 'roles_permisos_indovexapp_${ahora.millisecondsSinceEpoch}.xlsx';

    if (kIsWeb) {
      // En web sharePdf descarga los bytes con el nombre indicado, sea o no
      // un PDF (igual que el ZIP del export de empresa).
      await Printing.sharePdf(bytes: bytes, filename: nombre);
      return true;
    }

    // En el celular sharePdf comparte siempre como "application/pdf", y eso
    // confunde a las apps que reciben una planilla. Se usa el diálogo de
    // guardado del sistema.
    final ruta = await FilePicker.platform.saveFile(
      fileName: nombre,
      bytes: bytes,
    );
    return ruta != null;
  }

  // ---------------------------------------------------------------------
  // Hoja
  // ---------------------------------------------------------------------

  static String _hojaXml({
    required List<Map<String, dynamic>> roles,
    required List<Map<String, dynamic>> permisos,
    required Map<String, Set<String>> permisosPorRol,
    required String nombreEmpresa,
    required DateTime ahora,
  }) {
    final columnas = 2 + roles.length;
    final ultimaFila = _ultimaFilaDatos(permisos.length);
    final x = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
      ..write('<sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>')
      // Inmoviliza Módulo y Permiso a la izquierda y el encabezado arriba.
      ..write('<sheetViews><sheetView workbookViewId="0">')
      ..write('<pane xSplit="2" ySplit="$_filaEncabezado" '
          'topLeftCell="C${_filaEncabezado + 1}" activePane="bottomRight" state="frozen"/>')
      ..write('</sheetView></sheetViews>')
      ..write('<sheetFormatPr defaultRowHeight="15"/>')
      ..write('<cols>')
      ..write('<col min="1" max="1" width="18" customWidth="1"/>')
      ..write('<col min="2" max="2" width="44" customWidth="1"/>');
    if (roles.isNotEmpty) {
      x.write('<col min="3" max="$columnas" width="14" customWidth="1"/>');
    }
    x
      ..write('</cols>')
      ..write('<sheetData>')
      // Título, subtítulo y fecha.
      ..write('<row r="1">${_celdaTexto(0, 1, nombreEmpresa, _sTitulo)}</row>')
      ..write('<row r="2">${_celdaTexto(0, 2, 'Roles y permisos', _sSubtitulo)}</row>')
      ..write('<row r="3">'
          '${_celdaTexto(0, 3, 'Generado: ${_fechaHora(ahora)} - IndovexApp. X = el rol tiene el permiso.', _sNota)}'
          '</row>')
      // Encabezado de la tabla.
      ..write('<row r="$_filaEncabezado" ht="32" customHeight="1">')
      ..write(_celdaTexto(0, _filaEncabezado, 'Módulo', _sEncabezado))
      ..write(_celdaTexto(1, _filaEncabezado, 'Permiso', _sEncabezado));
    for (var c = 0; c < roles.length; c++) {
      final usuarios = (roles[c]['usuarios'] as int?) ?? 0;
      x.write(_celdaTexto(
        c + 2,
        _filaEncabezado,
        '${_titulo(_texto(roles[c]['nombre']))}\n'
        '$usuarios ${usuarios == 1 ? 'usuario' : 'usuarios'}',
        _sEncabezado,
      ));
    }
    x.write('</row>');

    // Una fila por permiso.
    for (var f = 0; f < permisos.length; f++) {
      final p = permisos[f];
      final fila = _filaEncabezado + 1 + f;
      x
        ..write('<row r="$fila">')
        ..write(_celdaTexto(0, fila, _titulo(_modulo(p)), _sTexto))
        ..write(_celdaTexto(1, fila, _texto(p['nombre']), _sTexto));
      for (var c = 0; c < roles.length; c++) {
        final marcada =
            permisosPorRol[roles[c]['id']]?.contains(p['id']) ?? false;
        x.write(marcada
            ? _celdaTexto(c + 2, fila, 'X', _sMarca)
            : '<c r="${_columna(c + 2)}$fila" s="$_sMarca"/>');
      }
      x.write('</row>');
    }

    // Nota de pie, igual que en los PDF.
    final filaNota = ultimaFila + 2;
    x
      ..write('<row r="$filaNota">')
      ..write(_celdaTexto(
        0,
        filaNota,
        'Documento generado por IndovexApp. La distribución de este reporte '
        'es responsabilidad del Cliente como titular de los datos.',
        _sNota,
      ))
      ..write('</row>')
      ..write('</sheetData>')
      ..write('<autoFilter ref="${_rangoTabla(roles.length, permisos.length)}"/>')
      ..write('<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>')
      ..write('<pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>')
      ..write('</worksheet>');
    return x.toString();
  }

  /// Celda con texto escrito en la propia celda (inlineStr): evita tener que
  /// armar la tabla aparte de textos compartidos.
  static String _celdaTexto(int columna, int fila, String texto, int estilo) {
    return '<c r="${_columna(columna)}$fila" s="$estilo" t="inlineStr">'
        '<is><t xml:space="preserve">${_escapar(texto)}</t></is></c>';
  }

  /// Letra de columna a partir del índice (0 = A, 25 = Z, 26 = AA...).
  static String _columna(int indice) {
    var n = indice + 1;
    var letras = '';
    while (n > 0) {
      final resto = (n - 1) % 26;
      letras = String.fromCharCode(65 + resto) + letras;
      n = (n - 1) ~/ 26;
    }
    return letras;
  }

  static int _ultimaFilaDatos(int cantidadPermisos) =>
      _filaEncabezado + cantidadPermisos;

  /// Rango de la tabla (encabezado + datos), por ejemplo A5:H40.
  static String _rangoTabla(int cantidadRoles, int cantidadPermisos,
      {bool absoluto = false}) {
    final ultimaColumna = _columna(1 + cantidadRoles);
    final ultimaFila = _ultimaFilaDatos(cantidadPermisos);
    return absoluto
        ? '\$A\$$_filaEncabezado:\$$ultimaColumna\$$ultimaFila'
        : 'A$_filaEncabezado:$ultimaColumna$ultimaFila';
  }

  static String _escapar(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      // XML 1.0 no admite caracteres de control salvo tab y saltos de línea.
      if (r < 0x20 && r != 0x09 && r != 0x0A && r != 0x0D) continue;
      switch (r) {
        case 0x26:
          b.write('&amp;');
        case 0x3C:
          b.write('&lt;');
        case 0x3E:
          b.write('&gt;');
        default:
          b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  static String _texto(dynamic v) => (v ?? '').toString();

  static String _titulo(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _modulo(Map<String, dynamic> p) {
    final m = _texto(p['modulo']).trim();
    return m.isEmpty ? 'otros' : m;
  }

  static String _fechaHora(DateTime f) {
    final l = f.toLocal();
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(l.day)}/${d(l.month)}/${l.year} ${d(l.hour)}:${d(l.minute)}';
  }

  // ---------------------------------------------------------------------
  // Partes fijas del .xlsx
  // ---------------------------------------------------------------------

  static const _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '</Types>';

  static const _rels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const _workbookRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  /// El nombre definido _xlnm._FilterDatabase es el que Excel asocia a los
  /// filtros de la hoja.
  static String _workbook(int cantidadRoles, int cantidadPermisos) {
    final rango = _rangoTabla(cantidadRoles, cantidadPermisos, absoluto: true);
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="$_hoja" sheetId="1" r:id="rId1"/></sheets>'
        '<definedNames>'
        '<definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">$_hoja!$rango</definedName>'
        '</definedNames>'
        '</workbook>';
  }

  /// Estilos. El orden de cellXfs define los índices _sTitulo, _sEncabezado...
  static const _estilos =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="5">'
      '<font><sz val="11"/><name val="Calibri"/></font>'
      '<font><b/><sz val="14"/><color rgb="FF1F4E79"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><name val="Calibri"/></font>'
      '<font><sz val="9"/><color rgb="FF6B7280"/><name val="Calibri"/></font>'
      '<font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>'
      '</fonts>'
      '<fills count="3">'
      '<fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF1F4E79"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="2">'
      '<border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border>'
      '<left style="thin"><color rgb="FFD0D7DE"/></left>'
      '<right style="thin"><color rgb="FFD0D7DE"/></right>'
      '<top style="thin"><color rgb="FFD0D7DE"/></top>'
      '<bottom style="thin"><color rgb="FFD0D7DE"/></bottom>'
      '<diagonal/>'
      '</border>'
      '</borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="7">'
      // 0: por defecto
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      // 1: título (nombre de la empresa)
      '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      // 2: subtítulo
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      // 3: nota (fecha y pie)
      '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
      // 4: encabezado de la tabla
      '<xf numFmtId="0" fontId="4" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1">'
      '<alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
      // 5: texto (módulo y permiso)
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1">'
      '<alignment vertical="center"/></xf>'
      // 6: marca (X centrada)
      '<xf numFmtId="0" fontId="2" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1" applyAlignment="1">'
      '<alignment horizontal="center" vertical="center"/></xf>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '</styleSheet>';
}