import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/documento_legal.dart';
import '../providers/legal_provider.dart';

/// Modal bloqueante: el admin debe aceptar antes de operar.
/// Se muestra vencido el preaviso (T&C cl. 13 / Priv. cl. 10).
class LegalBloqueoScreen extends StatelessWidget {
  final List<DocumentoLegal> documentos;
  final VoidCallback onLogout;

  const LegalBloqueoScreen({
    super.key,
    required this.documentos,
    required this.onLogout,
  });

  Future<void> _abrir(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el documento')),
      );
    }
  }

  Future<void> _aceptarTodos(BuildContext context) async {
    final provider = context.read<LegalProvider>();
    var ok = true;

    for (final doc in List<DocumentoLegal>.from(documentos)) {
      final r = await provider.aceptar(doc);
      if (!r) ok = false;
    }

    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'No se pudo registrar la aceptación'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LegalProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: const Text('IndovexApp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: onLogout,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gavel, color: Colors.orange[800], size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Documentos legales actualizados',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      documentos.length == 1
                          ? 'Actualizamos un documento que regula el uso del servicio. '
                            'Para continuar, es necesario que lo revises y lo aceptes.'
                          : 'Actualizamos los documentos que regulan el uso del servicio. '
                            'Para continuar, es necesario que los revises y los aceptes.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 20),
                    ...documentos.map((d) => _DocumentoCard(
                          documento: d,
                          onAbrir: () => _abrir(context, d.url),
                        )),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Al aceptar, quedará registrada la conformidad de tu empresa '
                              'con la fecha y tu usuario.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1F4E79),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: provider.cargando
                            ? null
                            : () => _aceptarTodos(context),
                        icon: provider.cargando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          documentos.length == 1
                              ? 'Acepto el documento'
                              : 'Acepto los documentos',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentoCard extends StatelessWidget {
  final DocumentoLegal documento;
  final VoidCallback onAbrir;

  const _DocumentoCard({required this.documento, required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  documento.titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'v${documento.version}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
          if (documento.resumenCambios != null) ...[
            const SizedBox(height: 8),
            Text(
              documento.resumenCambios!,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: onAbrir,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new,
                    size: 14, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Leer el documento completo',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner no bloqueante. Se muestra durante el preaviso al admin,
/// y siempre a los usuarios no admin.
class LegalBannerAviso extends StatelessWidget {
  final DocumentoLegal documento;
  final bool puedeAceptar;

  const LegalBannerAviso({
    super.key,
    required this.documento,
    required this.puedeAceptar,
  });

  Future<void> _abrir(BuildContext context) async {
    final uri = Uri.parse(documento.url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el documento')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<LegalProvider>();

    final texto = documento.enPreaviso
        ? '${documento.tituloCorto} v${documento.version}: entra en vigencia en '
          '${documento.diasRestantes} día${documento.diasRestantes == 1 ? '' : 's'}'
        : '${documento.tituloCorto} v${documento.version} actualizado';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blueGrey[700],
      child: Row(
        children: [
          const Icon(Icons.gavel, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _abrir(context),
              child: Text(
                texto,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          if (puedeAceptar)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => provider.aceptar(documento),
              child: const Text('Aceptar', style: TextStyle(fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => provider.descartar(documento),
          ),
        ],
      ),
    );
  }
}