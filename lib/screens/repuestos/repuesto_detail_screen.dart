import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/repuesto.dart';
import '../../models/categoria_repuesto.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';
import '../../core/db_error_helper.dart';
import '../../widgets/adjuntos_section.dart';
import '../../widgets/foto_principal_widget.dart';
import '../../widgets/repuestos_maquina_section.dart';
import 'ingreso_repuesto_screen.dart';
import 'salida_repuesto_screen.dart';

class RepuestoDetailScreen extends StatefulWidget {
  final Repuesto repuesto;

  const RepuestoDetailScreen({super.key, required this.repuesto});

  @override
  State<RepuestoDetailScreen> createState() => _RepuestoDetailScreenState();
}

class _RepuestoDetailScreenState extends State<RepuestoDetailScreen> {
  final _supabase = Supabase.instance.client;
  late Repuesto _repuesto;
  List<CategoriaRepuesto> _categorias = [];

  @override
  void initState() {
    super.initState();
    _repuesto = widget.repuesto;
    _cargarCategorias();
  }

  Future<void> _cargarCategorias() async {
    try {
      final data = await _supabase.from('categorias_repuestos').select().order('nombre');
      setState(() => _categorias = (data as List).map((e) => CategoriaRepuesto.fromMap(e)).toList());
    } catch (_) {}
  }

  Future<void> _recargarRepuesto() async {
    try {
      final data = await _supabase.from('repuestos').select().eq('id', _repuesto.id).single();
      setState(() => _repuesto = Repuesto.fromMap(data));
    } catch (e) {}
  }

  Future<void> _irAIngreso() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IngresoRepuestoScreen(repuesto: _repuesto)),
    );
    if (resultado == true) await _recargarRepuesto();
  }

  Future<void> _irASalida() async {
    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SalidaRepuestoScreen(repuesto: _repuesto)),
    );
    if (resultado == true) await _recargarRepuesto();
  }

  Future<void> _mostrarFormularioEdicion() async {
    final codigoController = TextEditingController(text: _repuesto.codigo);
    final descripcionController = TextEditingController(text: _repuesto.descripcion);
    final stockMinimoController = TextEditingController(text: _repuesto.stockMinimo.toString());
    final ubicacionController = TextEditingController(text: _repuesto.ubicacion ?? '');
    final notasController = TextEditingController(text: _repuesto.notas ?? '');
    String? categoriaSeleccionada = _repuesto.categoriaId;
    String unidadSeleccionada = _repuesto.unidadMedida;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Repuesto', style: TextStyle(fontSize: 18)),
          content: SizedBox(
            width: Responsive.isDesktop(context) ? 520 : double.maxFinite,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Código opcional: si se completa, la DB valida que no se repita
                // dentro de la empresa (índice único parcial normalizado).
                TextField(
                  controller: codigoController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Código', border: OutlineInputBorder(), hintText: 'Opcional. Ej: REP-001'),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 30,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descripcionController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Descripción *', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  maxLength: 500,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: categoriaSeleccionada,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin categoría', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                    ..._categorias.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setDialogState(() => categoriaSeleccionada = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: unidadSeleccionada,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  decoration: const InputDecoration(labelText: 'Unidad de medida *', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'unidad', child: Text('Unidad', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'metro', child: Text('Metro', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'litro', child: Text('Litro', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'kg', child: Text('Kilogramo', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'caja', child: Text('Caja', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'par', child: Text('Par', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'juego', child: Text('Juego', style: TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setDialogState(() => unidadSeleccionada = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockMinimoController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Stock mínimo', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Stock actual: ${_repuesto.stockActual} ${_repuesto.unidadMedida} (se modifica desde Ingreso/Salida)',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ubicacionController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Ubicación', border: OutlineInputBorder(), hintText: 'Ej: Estante A, Cajón 3'),
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 100,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notasController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(labelText: 'Notas', border: OutlineInputBorder()),
                  maxLines: 2,
                  maxLength: 500,
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                final codigo = normalizarTexto(codigoController.text);
                final descripcion = normalizarTexto(descripcionController.text);
                final ubicacion = normalizarTexto(ubicacionController.text);
                final notas = normalizarTexto(notasController.text);
                // Solo la descripción es obligatoria; el código es opcional.
                if (descripcion.isEmpty) return;
                Navigator.pop(context);
                await _editarRepuesto(
                  codigo: codigo,
                  descripcion: descripcion,
                  categoriaId: categoriaSeleccionada,
                  unidadMedida: unidadSeleccionada,
                  stockMinimo: int.tryParse(stockMinimoController.text) ?? 0,
                  ubicacion: ubicacion,
                  notas: notas,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editarRepuesto({
    required String codigo,
    required String descripcion,
    String? categoriaId,
    required String unidadMedida,
    required int stockMinimo,
    required String ubicacion,
    required String notas,
  }) async {
    try {
      await _supabase.from('repuestos').update({
        'categoria_id': categoriaId,
        // Código vacío => null, para que el índice único parcial no lo cuente.
        'codigo': codigo.isEmpty ? null : codigo,
        'descripcion': descripcion,
        'stock_minimo': stockMinimo,
        'ubicacion': ubicacion.isEmpty ? null : ubicacion,
        'unidad_medida': unidadMedida,
        'notas': notas.isEmpty ? null : notas,
      }).eq('id', _repuesto.id);
      await _recargarRepuesto();
      _mostrarExito('Repuesto actualizado correctamente');
    } catch (e) {
      _mostrarError(_mensajeErrorRepuesto(e));
    }
  }

  /// Traduce los dos índices únicos de repuestos a mensajes claros.
  /// Distingue código vs. descripción; si no es ninguno, cae al helper.
  String _mensajeErrorRepuesto(Object e) {
    final texto = e.toString().toLowerCase();
    if (texto.contains('uq_repuestos_empresa_codigo_norm')) {
      return 'Ya existe un repuesto con ese código. Elegí otro o dejalo vacío.';
    }
    if (texto.contains('uq_repuestos_empresa_descripcion_norm')) {
      return 'Ya existe un repuesto con esa descripción.';
    }
    return mensajeAmigableDb(e, entidad: 'repuesto', campos: 'descripción o código');
  }

  void _mostrarExito(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  String _nombreCategoria(String? categoriaId) {
    if (categoriaId == null) return 'Sin categoría';
    return _categorias.firstWhere(
      (c) => c.id == categoriaId,
      orElse: () => CategoriaRepuesto(id: '', empresaId: '', nombre: 'Sin categoría'),
    ).nombre;
  }

  @override
  Widget build(BuildContext context) {
    final stockBajo = _repuesto.stockBajo;
    final usuario = context.read<AuthProvider>().usuario;
    final puedeIngreso = usuario?.tienePermiso('registrar_ingreso') ?? false;
    final puedeSalida = usuario?.tienePermiso('registrar_salida') ?? false;
    final puedeGestionar = usuario?.tienePermiso('gestionar_repuestos') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(_repuesto.descripcion, style: const TextStyle(fontSize: 18)),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          if (puedeGestionar)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar repuesto',
              onPressed: _mostrarFormularioEdicion,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Foto principal ──────────────────────────────────────────────
          Center(
            child: FotoPrincipalWidget(
              storagePath: _repuesto.imagenUrl,
              tipo: 'repuesto',
              empresaId: _repuesto.empresaId,
              entidadId: _repuesto.id,
              size: 120,
              puedeEditar: puedeGestionar,
              onFotoActualizada: (nuevoPath) {
                setState(() {
                  _repuesto = Repuesto(
                    id: _repuesto.id,
                    empresaId: _repuesto.empresaId,
                    categoriaId: _repuesto.categoriaId,
                    codigo: _repuesto.codigo,
                    descripcion: _repuesto.descripcion,
                    stockActual: _repuesto.stockActual,
                    stockMinimo: _repuesto.stockMinimo,
                    ubicacion: _repuesto.ubicacion,
                    unidadMedida: _repuesto.unidadMedida,
                    notas: _repuesto.notas,
                    imagenUrl: nuevoPath.isEmpty ? null : nuevoPath,
                    activo: _repuesto.activo,
                  );
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Stock actual ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: stockBajo ? Colors.orange.withOpacity(0.1) : const Color(0xFF1F4E79).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: stockBajo ? Colors.orange.withOpacity(0.3) : const Color(0xFF1F4E79).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock actual', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    Text(
                      '${_repuesto.stockActual} ${_repuesto.unidadMedida}',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: stockBajo ? Colors.orange : const Color(0xFF1F4E79)),
                    ),
                    if (stockBajo)
                      const Text('⚠ Stock bajo', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Mínimo', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                    Text('${_repuesto.stockMinimo}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Acciones ingreso / salida ───────────────────────────────────
          if (puedeIngreso || puedeSalida)
            Row(
              children: [
                if (puedeIngreso)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _irAIngreso,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Ingreso', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
                if (puedeIngreso && puedeSalida) const SizedBox(width: 12),
                if (puedeSalida)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _irASalida,
                      icon: const Icon(Icons.remove_circle_outline),
                      label: const Text('Salida', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ),
              ],
            ),
          if (puedeIngreso || puedeSalida) const SizedBox(height: 16),

          // ── Información ─────────────────────────────────────────────────
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Información', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Divider(),
                  // La fila de código solo aparece si el repuesto tiene uno.
                  if (_repuesto.codigo.trim().isNotEmpty)
                    _infoRow('Código', _repuesto.codigo),
                  _infoRow('Categoría', _nombreCategoria(_repuesto.categoriaId)),
                  if (_repuesto.ubicacion != null && _repuesto.ubicacion!.isNotEmpty)
                    _infoRow('Ubicación', _repuesto.ubicacion!),
                  if (_repuesto.notas != null && _repuesto.notas!.isNotEmpty)
                    _infoRow('Notas', _repuesto.notas!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Máquinas que usan este repuesto ────────────────────────────
          RepuestosMaquinaSection(modo: 'desde_repuesto', entidadId: _repuesto.id),
          const SizedBox(height: 16),

          // ── Adjuntos (PDFs, manuales, etc.) ────────────────────────────
          AdjuntosSection(entidadTipo: 'repuesto', entidadId: _repuesto.id),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}