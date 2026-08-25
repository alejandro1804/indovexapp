import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tipo_intervalo_provider.dart';
import '../../models/tipo_intervalo.dart';

class TiposIntervaloScreen extends StatefulWidget {
  const TiposIntervaloScreen({super.key});

  @override
  State<TiposIntervaloScreen> createState() => _TiposIntervaloScreenState();
}

class _TiposIntervaloScreenState extends State<TiposIntervaloScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TipoIntervaloProvider>().cargarTipos();
    });
  }

  void _mostrarFormulario({TipoIntervalo? tipo}) {
    final nombreController = TextEditingController(text: tipo?.nombre ?? '');
    final codigoController = TextEditingController(text: tipo?.codigo ?? '');
    final esEdicion = tipo != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 24, 24,
          MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              esEdicion ? 'Editar tipo de intervalo' : 'Nuevo tipo de intervalo',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nombreController,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                labelStyle: TextStyle(fontSize: 13),
                border: OutlineInputBorder(),
                hintText: 'Ej: Kilómetros',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codigoController,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Código *',
                labelStyle: TextStyle(fontSize: 13),
                border: OutlineInputBorder(),
                hintText: 'Ej: km',
              ),
              enabled: !esEdicion || !(tipo.esDefault),
            ),
            if (esEdicion && tipo.esDefault) ...[
              const SizedBox(height: 8),
              Text(
                'El código de los tipos predeterminados no se puede modificar.',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final nombre = nombreController.text.trim();
                  final codigo = codigoController.text.trim().toLowerCase();

                  if (nombre.isEmpty || codigo.isEmpty) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text('Completá todos los campos'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  // Capturamos las referencias contra el context del State
                  // ANTES de cerrar el sheet y del await.
                  final messenger = ScaffoldMessenger.of(context);
                  final provider = context.read<TipoIntervaloProvider>();
                  Navigator.pop(sheetContext);
                  bool ok;

                  if (esEdicion) {
                    ok = await provider.actualizarTipo(
                      id: tipo.id,
                      nombre: nombre,
                      codigo: tipo.esDefault ? tipo.codigo : codigo,
                    );
                  } else {
                    ok = await provider.crearTipo(
                      nombre: nombre,
                      codigo: codigo,
                    );
                  }

                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? esEdicion ? 'Tipo actualizado' : 'Tipo creado correctamente'
                          : 'Error al guardar'),
                      backgroundColor: ok ? Colors.green : Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E79),
                  foregroundColor: Colors.white,
                ),
                child: Text(esEdicion ? 'Guardar cambios' : 'Crear tipo', style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarDesactivar(TipoIntervalo tipo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar tipo'),
        content: Text('¿Seguro que querés eliminar "${tipo.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      final ok = await context.read<TipoIntervaloProvider>().desactivarTipo(tipo.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Tipo eliminado' : 'Error al eliminar'),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TipoIntervaloProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipos de intervalo', style: TextStyle(fontSize: 17)),
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 14),
        extendedIconLabelSpacing: 6,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Nuevo tipo', style: TextStyle(fontSize: 12)),
      ),
      body: provider.cargando
          ? const Center(child: CircularProgressIndicator())
          : provider.tipos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_repeat_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No hay tipos de intervalo', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: provider.tipos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final tipo = provider.tipos[index];
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF1F4E79).withValues(alpha: 0.1),
                          child: Text(
                            tipo.codigo.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF1F4E79),
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        title: Text(
                          tipo.nombre,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          tipo.esDefault ? 'Predeterminado' : 'Personalizado',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _mostrarFormulario(tipo: tipo),
                            ),
                            if (!tipo.esDefault)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                onPressed: () => _confirmarDesactivar(tipo),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}