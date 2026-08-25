import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart';
import '../../models/maquina.dart';

class QrMaquinaScreen extends StatelessWidget {
  final Maquina maquina;

  const QrMaquinaScreen({super.key, required this.maquina});

  String get _deepLink => 'https://app.indovexapp.com/maquina/${maquina.id}';

  // Genera el PDF de la etiqueta con el tamaño elegido (en cm).
  Future<void> _imprimirEtiqueta(double tamanoCm) async {
    final doc = pw.Document();

    // cm -> puntos PDF (1 cm = 28.35 pt)
    final ladoQr = tamanoCm * PdfPageFormat.cm;

    final qr = Barcode.qrCode(
      errorCorrectLevel: BarcodeQRCorrectionLevel.medium,
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 1, color: PdfColors.grey600),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Text(
                    maquina.nombre,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Codigo: ${maquina.codigo}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(height: 10),
                  pw.SizedBox(
                    width: ladoQr,
                    height: ladoQr,
                    child: pw.BarcodeWidget(
                      barcode: qr,
                      data: _deepLink,
                      drawText: false,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'IndovexApp',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  // Muestra el selector de tamaño antes de imprimir.
  Future<void> _elegirTamano(BuildContext context) async {
    final tamano = await showModalBottomSheet<double>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tamaño del QR a imprimir',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.crop_square, size: 20),
                title: const Text('Chico (5 cm)'),
                subtitle: const Text('Activos pequeños o herramientas'),
                onTap: () => Navigator.pop(context, 5.0),
              ),
              ListTile(
                leading: const Icon(Icons.crop_square, size: 28),
                title: const Text('Mediano (8 cm)'),
                subtitle: const Text('Tamaño estándar recomendado'),
                onTap: () => Navigator.pop(context, 8.0),
              ),
              ListTile(
                leading: const Icon(Icons.crop_square, size: 36),
                title: const Text('Grande (10 cm)'),
                subtitle: const Text('Activos grandes, escaneo a distancia'),
                onTap: () => Navigator.pop(context, 10.0),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (tamano != null) {
      await _imprimirEtiqueta(tamano);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Código QR', style: TextStyle(fontSize: 18)),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimir',
            onPressed: () => _elegirTamano(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                maquina.nombre,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Código: ${maquina.codigo}',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _deepLink,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _deepLink,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Escaneá con la cámara del celular\npara abrir directo este activo en IndovexApp',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}