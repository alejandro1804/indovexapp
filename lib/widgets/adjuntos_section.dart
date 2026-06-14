import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/document_helper.dart';

class AdjuntosSection extends StatefulWidget {
  final String entidadTipo; // 'maquina' | 'repuesto' | 'ticket'
  final String entidadId;

  const AdjuntosSection({
    super.key,
    required this.entidadTipo,
    required this.entidadId,
  });

  @override
  State<AdjuntosSection> createState() => _AdjuntosSectionState();
}

class _AdjuntosSectionState extends State<AdjuntosSection> {
  List<Map<String, dynamic>> _adjuntos = [];
  bool _cargando = true;
  bool _subiendo = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await DocumentHelper.listarAdjuntos(
        entidadTipo: widget.entidadTipo,
        entidadId: widget.entidadId,
      );
      if (mounted) setState(() => _adjuntos = data);
    } catch (e) {
      if (mounted) _mostrarError('Error al cargar adjuntos');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _subir() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Obtener empresa_id del usuario actual
    final usuarioData = await Supabase.instance.client
        .from('usuarios')
        .select('empresa_id')
        .eq('id', user.id)
        .single();

    final empresaId = usuarioData['empresa_id'] as String;

    setState(() => _subiendo = true);
    try {
      final adjunto = await DocumentHelper.subirAdjunto(
        entidadTipo: widget.entidadTipo,
        entidadId: widget.entidadId,
        empresaId: empresaId,
        subidoPor: user.id,
      );
      if (adjunto != null) {
        await _cargar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Archivo subido correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) _mostrarError('Error al subir archivo: $e');
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _abrir(Map<String, dynamic> adjunto) async {
    try {
      final url = await DocumentHelper.urlFirmada(adjunto['storage_path']);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) _mostrarError('No se pudo abrir el archivo');
    }
  }

  Future<void> _confirmarEliminar(Map<String, dynamic> adjunto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar adjunto'),
        content: Text('¿Eliminar "${adjunto['nombre_archivo']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await DocumentHelper.eliminarAdjunto(adjunto);
        await _cargar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adjunto eliminado')),
          );
        }
      } catch (e) {
        if (mounted) _mostrarError('Error al eliminar');
      }
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.attach_file, size: 18, color: Color(0xFF1F4E79)),
                    const SizedBox(width: 6),
                    const Text(
                      'Adjuntos',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (_adjuntos.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F4E79).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_adjuntos.length}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF1F4E79),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                _subiendo
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.add, color: Color(0xFF1F4E79)),
                        onPressed: _subir,
                        tooltip: 'Adjuntar archivo',
                      ),
              ],
            ),
            const Divider(),
            if (_cargando)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_adjuntos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Sin adjuntos',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _adjuntos.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _AdjuntoTile(
                  adjunto: _adjuntos[i],
                  onAbrir: () => _abrir(_adjuntos[i]),
                  onEliminar: () => _confirmarEliminar(_adjuntos[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AdjuntoTile extends StatelessWidget {
  final Map<String, dynamic> adjunto;
  final VoidCallback onAbrir;
  final VoidCallback onEliminar;

  const _AdjuntoTile({
    required this.adjunto,
    required this.onAbrir,
    required this.onEliminar,
  });

  // Acorta nombres largos al medio, conservando el inicio y el final (extensión).
  // Ej: "Screenshot_20260613_161402_com_indovex_app_MainActivity.jpg"
  //   → "Screenshot_2026…MainActivity.jpg"
  String _acortarNombre(String nombre, {int maxCaracteres = 32}) {
    if (nombre.length <= maxCaracteres) return nombre;

    // Separar extensión (lo que va después del último punto)
    String base = nombre;
    String extension = '';
    final puntoIdx = nombre.lastIndexOf('.');
    if (puntoIdx > 0 && puntoIdx > nombre.length - 8) {
      base = nombre.substring(0, puntoIdx);
      extension = nombre.substring(puntoIdx); // incluye el punto
    }

    // Espacio disponible para el texto, restando la extensión y el "…"
    final disponible = maxCaracteres - extension.length - 1;
    if (disponible < 6) {
      // Nombre/extensión muy largos: caso de borde, recortar simple al final
      return '${nombre.substring(0, maxCaracteres - 1)}…';
    }

    final inicio = (disponible * 0.6).round(); // más peso al inicio
    final fin = disponible - inicio;
    return '${base.substring(0, inicio)}…${base.substring(base.length - fin)}$extension';
  }

  @override
  Widget build(BuildContext context) {
    final mime = adjunto['tipo_mime'] as String?;
    final nombre = adjunto['nombre_archivo'] as String? ?? 'Archivo';
    final tamanio = DocumentHelper.formatearTamanio(adjunto['tamanio_bytes'] as int?);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Línea 1: nombre del archivo en UNA sola línea, a todo el ancho.
          // Si es muy largo, se acorta al medio conservando inicio + extensión.
          Text(
            _acortarNombre(nombre),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Línea 2: ícono tipo + tamaño a la izquierda, acciones a la derecha
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: DocumentHelper.colorPorMime(mime).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  DocumentHelper.iconoPorMime(mime),
                  color: DocumentHelper.colorPorMime(mime),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tamanio.isNotEmpty ? tamanio : '',
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                icon: const Icon(Icons.open_in_new, size: 18),
                color: const Color(0xFF1F4E79),
                onPressed: onAbrir,
                tooltip: 'Abrir',
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                icon: const Icon(Icons.delete_outline, size: 18),
                color: Colors.red[400],
                onPressed: onEliminar,
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}