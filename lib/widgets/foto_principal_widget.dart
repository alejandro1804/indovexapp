import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/image_upload_helper.dart';

/// Thumbnail cuadrado que muestra la foto principal de una entidad.
/// Al tocar la foto → la amplía en pantalla completa.
/// Al tocar el ícono de cámara → abre el selector para cambiar la foto.
///
/// Uso:
/// ```dart
/// FotoPrincipalWidget(
///   storagePath: maquina.imagenUrl,
///   tipo: 'maquina',
///   empresaId: maquina.empresaId,
///   entidadId: maquina.id,
///   size: 56,
///   onFotoActualizada: (nuevoPath) => setState(() => maquina = ...),
///   puedeEditar: true,
/// )
/// ```
class FotoPrincipalWidget extends StatefulWidget {
  final String? storagePath;
  final String tipo;          // 'maquina' | 'repuesto' | 'avatar'
  final String empresaId;
  final String entidadId;
  final double size;          // lado del cuadrado en el listado
  final bool puedeEditar;
  final void Function(String nuevoPath)? onFotoActualizada;

  const FotoPrincipalWidget({
    super.key,
    required this.storagePath,
    required this.tipo,
    required this.empresaId,
    required this.entidadId,
    this.size = 56,
    this.puedeEditar = false,
    this.onFotoActualizada,
  });

  @override
  State<FotoPrincipalWidget> createState() => _FotoPrincipalWidgetState();
}

class _FotoPrincipalWidgetState extends State<FotoPrincipalWidget> {
  String? _signedUrl;
  bool _cargando = false;
  bool _subiendo = false;

  @override
  void initState() {
    super.initState();
    _cargarUrl();
  }

  @override
  void didUpdateWidget(FotoPrincipalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storagePath != widget.storagePath) {
      _cargarUrl();
    }
  }

  Future<void> _cargarUrl() async {
    if (widget.storagePath == null || widget.storagePath!.isEmpty) {
      setState(() => _signedUrl = null);
      return;
    }
    setState(() => _cargando = true);
    try {
      final url = await ImageUploadHelper.signedUrl(widget.storagePath!);
      if (mounted) setState(() => _signedUrl = url);
    } catch (_) {
      if (mounted) setState(() => _signedUrl = null);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _subirFoto(ImageSource source) async {
    setState(() => _subiendo = true);
    try {
      final path = await ImageUploadHelper.pickAndUpload(
        tipo: widget.tipo,
        empresaId: widget.empresaId,
        entidadId: widget.entidadId,
        source: source,
      );
      if (path == null) return;

      await ImageUploadHelper.guardarEnDb(
        tipo: widget.tipo,
        entidadId: widget.entidadId,
        path: path,
      );

      widget.onFotoActualizada?.call(path);

      // Recargar URL firmada para el nuevo path
      final url = await ImageUploadHelper.signedUrl(path);
      if (mounted) setState(() => _signedUrl = url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto actualizada'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  void _mostrarOpciones() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () { Navigator.pop(context); _subirFoto(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () { Navigator.pop(context); _subirFoto(ImageSource.gallery); },
            ),
            if (widget.storagePath != null && widget.storagePath!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Eliminar foto', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await _eliminarFoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarFoto() async {
    if (widget.storagePath == null) return;
    try {
      await ImageUploadHelper.eliminar(widget.storagePath!);
      await ImageUploadHelper.guardarEnDb(
        tipo: widget.tipo,
        entidadId: widget.entidadId,
        path: '',
      );
      // Guardar null en DB correctamente
      final tabla = switch (widget.tipo) {
        'maquina'  => 'maquinas',
        'repuesto' => 'repuestos',
        'avatar'   => 'usuarios',
        _          => 'maquinas',
      };
      final campo = widget.tipo == 'avatar' ? 'avatar_path' : 'imagen_url';
      await Supabase.instance.client.from(tabla).update({campo: null}).eq('id', widget.entidadId);

      widget.onFotoActualizada?.call('');
      if (mounted) setState(() => _signedUrl = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _abrirFullscreen() {
    if (_signedUrl == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FotoFullscreenScreen(url: _signedUrl!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final borderRadius = BorderRadius.circular(size * 0.15);

    return Stack(
      children: [
        // Imagen o placeholder
        GestureDetector(
          onTap: _signedUrl != null ? _abrirFullscreen : null,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: SizedBox(
              width: size,
              height: size,
              child: _cargando
                  ? Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : _signedUrl != null
                      ? Image.network(
                          _signedUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(size),
                        )
                      : _placeholder(size),
            ),
          ),
        ),

        // Botón de edición (esquina inferior derecha)
        if (widget.puedeEditar)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _subiendo ? null : _mostrarOpciones,
              child: Container(
                width: size * 0.38,
                height: size * 0.38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F4E79),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: _subiendo
                    ? const Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                      )
                    : Icon(Icons.camera_alt, color: Colors.white, size: size * 0.20),
              ),
            ),
          ),
      ],
    );
  }

  Widget _placeholder(double size) {
    final icon = switch (widget.tipo) {
      'maquina'  => Icons.precision_manufacturing_outlined,
      'repuesto' => Icons.inventory_2_outlined,
      'avatar'   => Icons.person_outline,
      _          => Icons.image_outlined,
    };
    return Container(
      color: const Color(0xFF1F4E79).withValues(alpha: 0.08),
      child: Icon(icon, size: size * 0.45, color: const Color(0xFF1F4E79).withValues(alpha: 0.4)),
    );
  }
}

/// Pantalla fullscreen para ver la foto ampliada con zoom
class _FotoFullscreenScreen extends StatelessWidget {
  final String url;
  const _FotoFullscreenScreen({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}