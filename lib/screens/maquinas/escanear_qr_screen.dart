import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class EscanearQrScreen extends StatefulWidget {
  const EscanearQrScreen({super.key});

  @override
  State<EscanearQrScreen> createState() => _EscanearQrScreenState();
}

class _EscanearQrScreenState extends State<EscanearQrScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _yaDetectado = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Extrae el ID de máquina de una URL tipo
  // https://app.indovexapp.com/maquina/{id}
  String? _extraerMaquinaId(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.host == 'app.indovexapp.com' &&
          uri.pathSegments.length > 1 &&
          uri.pathSegments[0] == 'maquina') {
        return uri.pathSegments[1];
      }
    } catch (_) {}
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_yaDetectado) return;
    for (final barcode in capture.barcodes) {
      final valor = barcode.rawValue;
      if (valor == null) continue;
      final maquinaId = _extraerMaquinaId(valor);
      if (maquinaId != null) {
        _yaDetectado = true;
        Navigator.pop(context, maquinaId);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR', style: TextStyle(fontSize: 18)),
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Linterna',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Cambiar cámara',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Marco guía centrado
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Apuntá al código QR de la máquina',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                shadows: [
                  Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}