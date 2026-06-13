import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/repuesto_maquina.dart';
import '../providers/repuesto_maquina_provider.dart';

class RepuestosMaquinaSection extends StatefulWidget {
  final String modo; // 'desde_maquina' o 'desde_repuesto'
  final String entidadId; // id de la máquina o del repuesto según el modo

  const RepuestosMaquinaSection({
    super.key,
    required this.modo,
    required this.entidadId,
  });

  @override
  State<RepuestosMaquinaSection> createState() => _RepuestosMaquinaSectionState();
}

class _RepuestosMaquinaSectionState extends State<RepuestosMaquinaSection> {
  final _supabase = Supabase.instance.client;

  bool get _desdeMaquina => widget.modo == 'desde_maquina';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final provider = context.read<RepuestoMaquinaProvider>();
    if (_desdeMaquina) {
      await provider.cargarPorMaquina(widget.entidadId);
    } else {
      await provider.cargarPorRepuesto(widget.entidadId);
    }
  }

  // Carga las opciones disponibles para vincular (repuestos o máquinas según modo)
  Future<List<Map<String, dynamic>>> _cargarOpciones() async {
    if (_desdeMaquina) {
      final data = await _supabase
          .from('repuestos')
          .select('id, codigo, descripcion')
          .eq('activo', true)
          .order('descripcion');
      return List<Map<String, dynamic>>.from(data);
    } else {
      final data = await _supabase
          .from('maquinas')
          .select('id, nombre, codigo')
          .order('nombre');
      return List<Map<String, dynamic>>.from(data);
    }
  }

  Future<void> _mostrarFormulario({RepuestoMaquina? vinculo}) async {
    final esEdicion = vinculo != null;
    final cantidadController = TextEditingController(
      text: vinculo?.cantidad.toString() ?? '1',
    );
    final ubicacionController = TextEditingController(
      text: vinculo?.ubicacionEnMaquina ?? '',
    );
    final observacionController = TextEditingController(
      text: vinculo?.observacion ?? '',
    );

    List<Map<String, dynamic>> opciones = [];
    String? seleccionId = esEdicion
        ? (_desdeMaquina ? vinculo.repuestoId : vinculo.maquinaId)
        : null;

    if (!esEdicion) {
      opciones = await _cargarOpciones();
      if (opciones.isNotEmpty) seleccionId = opciones.first['id'] as String;
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                esEdicion
                    ? 'Editar vínculo'
                    : _desdeMaquina
                        ? 'Agregar repuesto'
                        : 'Asociar a máquina',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Selector (solo en alta)
              if (!esEdicion)
                DropdownButtonFormField<String>(
                  value: seleccionId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _desdeMaquina ? 'Repuesto *' : 'Máquina *',
                    border: const OutlineInputBorder(),
                  ),
                  items: opciones.map((o) {
                    final label = _desdeMaquina
                        ? '${o['descripcion']} (${o['codigo']})'
                        : '${o['nombre']} (${o['codigo']})';
                    return DropdownMenuItem(
                      value: o['id'] as String,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setSheetState(() => seleccionId = v),
                )
              else
                // En edición, mostrar el nombre fijo
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _desdeMaquina
                        ? '${vinculo.repuestoDescripcion ?? ''} (${vinculo.repuestoCodigo ?? ''})'
                        : '${vinculo.maquinaNombre ?? ''} (${vinculo.maquinaCodigo ?? ''})',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              const SizedBox(height: 12),

              // Cantidad
              TextField(
                controller: cantidadController,
                decoration: const InputDecoration(
                  labelText: 'Cantidad *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers_outlined),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),

              // Ubicación en máquina
              TextField(
                controller: ubicacionController,
                decoration: const InputDecoration(
                  labelText: 'Ubicación en máquina',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: eje principal, motor...',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),

              // Observación
              TextField(
                controller: observacionController,
                decoration: const InputDecoration(
                  labelText: 'Observación',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final cantidad = int.tryParse(cantidadController.text.trim());
                    if (cantidad == null || cantidad <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ingresá una cantidad válida'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    if (!esEdicion && seleccionId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_desdeMaquina
                              ? 'Seleccioná un repuesto'
                              : 'Seleccioná una máquina'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context);
                    final provider = this.context.read<RepuestoMaquinaProvider>();
                    bool ok;

                    if (esEdicion) {
                      ok = await provider.actualizar(
                        id: vinculo.id,
                        cantidad: cantidad,
                        ubicacionEnMaquina: ubicacionController.text.trim(),
                        observacion: observacionController.text.trim(),
                      );
                    } else {
                      ok = await provider.vincular(
                        repuestoId: _desdeMaquina ? seleccionId! : widget.entidadId,
                        maquinaId: _desdeMaquina ? widget.entidadId : seleccionId!,
                        cantidad: cantidad,
                        ubicacionEnMaquina: ubicacionController.text.trim(),
                        observacion: observacionController.text.trim(),
                      );
                    }

                    if (!this.context.mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Guardado correctamente' : 'Error al guardar'),
                        backgroundColor: ok ? Colors.green : Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F4E79),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(esEdicion ? 'Guardar cambios' : 'Agregar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RepuestoMaquinaProvider>();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Fix overflow del header: título en Expanded, sin Spacer.
            // El IconButton (+) se compacta para no robar ancho.
            Row(
              children: [
                Icon(
                  _desdeMaquina ? Icons.inventory_2_outlined : Icons.precision_manufacturing_outlined,
                  size: 18,
                  color: const Color(0xFF1F4E79),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _desdeMaquina ? 'Repuestos asociados' : 'Máquinas que lo usan',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  tooltip: _desdeMaquina ? 'Agregar repuesto' : 'Asociar máquina',
                  icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1F4E79)),
                  onPressed: () => _mostrarFormulario(),
                ),
              ],
            ),
            const Divider(),
            if (provider.cargando)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.vinculos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _desdeMaquina
                      ? 'No hay repuestos asociados a esta máquina.'
                      : 'Este repuesto no está asociado a ninguna máquina.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              )
            else
              ...provider.vinculos.map((v) {
                final titulo = _desdeMaquina
                    ? '${v.repuestoDescripcion ?? ''} (${v.repuestoCodigo ?? ''})'
                    : '${v.maquinaNombre ?? ''} (${v.maquinaCodigo ?? ''})';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F4E79).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${v.cantidad}x',
                          style: const TextStyle(
                            color: Color(0xFF1F4E79),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titulo,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (v.ubicacionEnMaquina != null && v.ubicacionEnMaquina!.isNotEmpty)
                              Text(
                                v.ubicacionEnMaquina!,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (v.observacion != null && v.observacion!.isNotEmpty)
                              Text(
                                v.observacion!,
                                style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // ✅ Botones compactos para no empujar el texto
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _mostrarFormulario(vinculo: v),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        tooltip: 'Quitar',
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        onPressed: () async {
                          final confirmar = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Quitar vínculo'),
                              content: const Text('¿Seguro que querés quitar este vínculo?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  child: const Text('Quitar'),
                                ),
                              ],
                            ),
                          );
                          if (confirmar == true && context.mounted) {
                            await context.read<RepuestoMaquinaProvider>().desvincular(v.id);
                          }
                        },
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}