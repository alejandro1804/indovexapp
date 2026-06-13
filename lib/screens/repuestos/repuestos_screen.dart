import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/repuesto.dart';
import '../../models/categoria_repuesto.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';
import '../../core/db_error_helper.dart';
import 'repuesto_detail_screen.dart';

class RepuestosScreen extends StatefulWidget {
  const RepuestosScreen({super.key});
  @override
  State<RepuestosScreen> createState() => _RepuestosScreenState();
}

class _RepuestosScreenState extends State<RepuestosScreen> {
  final _supabase = Supabase.instance.client;
  List<Repuesto> _repuestos = [];
  List<CategoriaRepuesto> _categorias = [];
  bool _cargando = true;
  String _filtroCategoriaId = 'todos';
  bool _soloStockBajo = false;
  final _busquedaController = TextEditingController();
  String _textoBusqueda = '';

  @override
  void initState() { super.initState(); _cargarDatos(); }

  @override
  void dispose() { _busquedaController.dispose(); super.dispose(); }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final repuestosData = await _supabase.from('repuestos').select().eq('activo', true).order('descripcion');
      final categoriasData = await _supabase.from('categorias_repuestos').select().order('nombre');
      setState(() {
        _repuestos = (repuestosData as List).map((e) => Repuesto.fromMap(e)).toList();
        _categorias = (categoriasData as List).map((e) => CategoriaRepuesto.fromMap(e)).toList();
      });
    } catch (e) { _mostrarError('Error al cargar repuestos: $e'); }
    finally { setState(() => _cargando = false); }
  }

  List<Repuesto> get _repuestosFiltrados {
    return _repuestos.where((r) {
      final coincideBusqueda = _textoBusqueda.isEmpty ||
          r.descripcion.toLowerCase().contains(_textoBusqueda.toLowerCase()) ||
          r.codigo.toLowerCase().contains(_textoBusqueda.toLowerCase());
      final coincideCategoria = _filtroCategoriaId == 'todos' || r.categoriaId == _filtroCategoriaId;
      final coincideStock = !_soloStockBajo || r.stockBajo;
      return coincideBusqueda && coincideCategoria && coincideStock;
    }).toList();
  }

  String _nombreCategoria(String? categoriaId) {
    if (categoriaId == null) return 'Sin categoría';
    return _categorias.firstWhere((c) => c.id == categoriaId,
        orElse: () => CategoriaRepuesto(id: '', empresaId: '', nombre: 'Sin categoría')).nombre;
  }

  Future<void> _mostrarFormulario({Repuesto? repuesto}) async {
    final codigoController = TextEditingController(text: repuesto?.codigo ?? '');
    final descripcionController = TextEditingController(text: repuesto?.descripcion ?? '');
    final stockActualController = TextEditingController(text: repuesto?.stockActual.toString() ?? '0');
    final stockMinimoController = TextEditingController(text: repuesto?.stockMinimo.toString() ?? '0');
    final ubicacionController = TextEditingController(text: repuesto?.ubicacion ?? '');
    final notasController = TextEditingController(text: repuesto?.notas ?? '');
    String? categoriaSeleccionada = repuesto?.categoriaId;
    String unidadSeleccionada = repuesto?.unidadMedida ?? 'unidad';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(repuesto == null ? 'Nuevo Repuesto' : 'Editar Repuesto'),
          content: SizedBox(
            width: Responsive.isDesktop(context) ? 520 : double.maxFinite,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: codigoController, decoration: const InputDecoration(labelText: 'Código *', border: OutlineInputBorder(), hintText: 'Ej: REP-001'), textCapitalization: TextCapitalization.characters, maxLength: 30),
                const SizedBox(height: 12),
                TextField(controller: descripcionController, decoration: const InputDecoration(labelText: 'Descripción *', border: OutlineInputBorder()), textCapitalization: TextCapitalization.sentences, maxLines: 2, maxLength: 500),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: categoriaSeleccionada,
                  decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                  items: [const DropdownMenuItem(value: null, child: Text('Sin categoría')), ..._categorias.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))],
                  onChanged: (v) => setDialogState(() => categoriaSeleccionada = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: unidadSeleccionada,
                  decoration: const InputDecoration(labelText: 'Unidad de medida *', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'unidad', child: Text('Unidad')),
                    DropdownMenuItem(value: 'metro', child: Text('Metro')),
                    DropdownMenuItem(value: 'litro', child: Text('Litro')),
                    DropdownMenuItem(value: 'kg', child: Text('Kilogramo')),
                    DropdownMenuItem(value: 'caja', child: Text('Caja')),
                    DropdownMenuItem(value: 'par', child: Text('Par')),
                    DropdownMenuItem(value: 'juego', child: Text('Juego')),
                  ],
                  onChanged: (v) => setDialogState(() => unidadSeleccionada = v!),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: stockActualController, decoration: const InputDecoration(labelText: 'Stock actual', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: stockMinimoController, decoration: const InputDecoration(labelText: 'Stock mínimo', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 12),
                TextField(controller: ubicacionController, decoration: const InputDecoration(labelText: 'Ubicación', border: OutlineInputBorder(), hintText: 'Ej: Estante A, Cajón 3'), textCapitalization: TextCapitalization.sentences, maxLength: 100),
                const SizedBox(height: 12),
                TextField(controller: notasController, decoration: const InputDecoration(labelText: 'Notas', border: OutlineInputBorder()), maxLines: 2, maxLength: 500),
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
                if (codigo.isEmpty || descripcion.isEmpty) return;
                Navigator.pop(context);
                if (repuesto == null) {
                  await _crearRepuesto(codigo: codigo, descripcion: descripcion, categoriaId: categoriaSeleccionada, unidadMedida: unidadSeleccionada, stockActual: int.tryParse(stockActualController.text) ?? 0, stockMinimo: int.tryParse(stockMinimoController.text) ?? 0, ubicacion: ubicacion, notas: notas);
                } else {
                  await _editarRepuesto(id: repuesto.id, codigo: codigo, descripcion: descripcion, categoriaId: categoriaSeleccionada, unidadMedida: unidadSeleccionada, stockMinimo: int.tryParse(stockMinimoController.text) ?? 0, ubicacion: ubicacion, notas: notas);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
              child: Text(repuesto == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearRepuesto({required String codigo, required String descripcion, String? categoriaId, required String unidadMedida, required int stockActual, required int stockMinimo, required String ubicacion, required String notas}) async {
    try {
      final usuario = context.read<AuthProvider>().usuario;
      if (usuario == null) return;
      await _supabase.from('repuestos').insert({'empresa_id': usuario.empresaId, 'categoria_id': categoriaId, 'codigo': codigo, 'descripcion': descripcion, 'stock_actual': stockActual, 'stock_minimo': stockMinimo, 'ubicacion': ubicacion.isEmpty ? null : ubicacion, 'unidad_medida': unidadMedida, 'notas': notas.isEmpty ? null : notas, 'activo': true});
      await _cargarDatos();
      _mostrarExito('Repuesto creado correctamente');
    } catch (e) { _mostrarError(mensajeAmigableDb(e, entidad: 'repuesto')); }
  }

  Future<void> _editarRepuesto({required String id, required String codigo, required String descripcion, String? categoriaId, required String unidadMedida, required int stockMinimo, required String ubicacion, required String notas}) async {
    try {
      await _supabase.from('repuestos').update({'categoria_id': categoriaId, 'codigo': codigo, 'descripcion': descripcion, 'stock_minimo': stockMinimo, 'ubicacion': ubicacion.isEmpty ? null : ubicacion, 'unidad_medida': unidadMedida, 'notas': notas.isEmpty ? null : notas}).eq('id', id);
      await _cargarDatos();
      _mostrarExito('Repuesto actualizado correctamente');
    } catch (e) { _mostrarError(mensajeAmigableDb(e, entidad: 'repuesto')); }
  }

  void _mostrarExito(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)); }
  void _mostrarError(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating)); }

  Widget _buildCard(Repuesto repuesto) {
    final stockBajo = repuesto.stockBajo;
    final titleSize = Responsive.cardTitleSize(context);
    final subtitleSize = Responsive.cardSubtitleSize(context);
    final stockSize = Responsive.stockNumberSize(context);
    final avatarRadius = Responsive.avatarRadius(context);
    final cardPadding = Responsive.cardPadding(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: stockBajo ? const BorderSide(color: Colors.orange, width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RepuestoDetailScreen(repuesto: repuesto))).then((_) => _cargarDatos()),
        child: Padding(
          padding: cardPadding,
          child: Row(
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: stockBajo ? Colors.orange.withOpacity(0.1) : const Color(0xFF1F4E79).withOpacity(0.1),
                child: Icon(
                  stockBajo ? Icons.warning_amber_outlined : Icons.inventory_2_outlined,
                  color: stockBajo ? Colors.orange : const Color(0xFF1F4E79),
                  size: avatarRadius,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(repuesto.descripcion, style: TextStyle(fontWeight: FontWeight.w600, fontSize: titleSize), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Código: ${repuesto.codigo}', style: TextStyle(color: Colors.grey[600], fontSize: subtitleSize)),
                    Text(_nombreCategoria(repuesto.categoriaId), style: TextStyle(color: Colors.grey[500], fontSize: subtitleSize)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${repuesto.stockActual}', style: TextStyle(fontSize: stockSize, fontWeight: FontWeight.bold, color: stockBajo ? Colors.orange : const Color(0xFF1F4E79))),
                  Text(repuesto.unidadMedida, style: TextStyle(fontSize: subtitleSize, color: Colors.grey[500])),
                  if (stockBajo) Text('Stock bajo', style: TextStyle(fontSize: subtitleSize - 1, color: Colors.orange, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriaChip(String valor, String label) {
    final seleccionado = _filtroCategoriaId == valor;
    return FilterChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (_) => setState(() => _filtroCategoriaId = valor),
      selectedColor: const Color(0xFF1F4E79).withOpacity(0.15),
      checkmarkColor: const Color(0xFF1F4E79),
      labelStyle: TextStyle(color: seleccionado ? const Color(0xFF1F4E79) : Colors.grey[700], fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthProvider>().usuario;
    final puedeGestionar = usuario?.tienePermiso('gestionar_repuestos') ?? false;
    final repuestosFiltrados = _repuestosFiltrados;
    final stockBajoCount = _repuestos.where((r) => r.stockBajo).length;
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repuestos'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          if (stockBajoCount > 0)
            Stack(children: [
              IconButton(icon: const Icon(Icons.warning_amber_outlined), onPressed: () => setState(() => _soloStockBajo = !_soloStockBajo), tooltip: 'Stock bajo'),
              Positioned(right: 6, top: 6, child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text('$stockBajoCount', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
              )),
            ]),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _busquedaController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por código o descripción...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _textoBusqueda.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _busquedaController.clear(); setState(() => _textoBusqueda = ''); })
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (v) => setState(() => _textoBusqueda = v),
                ),
              ),
              if (_categorias.isNotEmpty)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _buildCategoriaChip('todos', 'Todas'),
                      ..._categorias.map((c) => Padding(padding: const EdgeInsets.only(left: 8), child: _buildCategoriaChip(c.id, c.nombre))),
                    ]),
                  ),
                ),
              if (_soloStockBajo)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.orange[50],
                  child: Row(children: [
                    const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Mostrando solo repuestos con stock bajo', style: TextStyle(color: Colors.orange, fontSize: 12))),
                    GestureDetector(onTap: () => setState(() => _soloStockBajo = false), child: const Text('Ver todos', style: TextStyle(color: Colors.orange, fontSize: 12, decoration: TextDecoration.underline))),
                  ]),
                ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Colors.grey[100],
                child: Text('${repuestosFiltrados.length} repuesto${repuestosFiltrados.length != 1 ? 's' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ),
              Expanded(
                child: repuestosFiltrados.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(_repuestos.isEmpty ? 'No hay repuestos cargados' : 'No hay repuestos con ese filtro', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      ]))
                    : RefreshIndicator(
                        onRefresh: _cargarDatos,
                        child: ListView.separated(
                          padding: padding,
                          itemCount: repuestosFiltrados.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _buildCard(repuestosFiltrados[index]),
                        ),
                      ),
              ),
            ]),
      floatingActionButton: puedeGestionar
          ? FloatingActionButton(onPressed: () => _mostrarFormulario(), backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white, child: const Icon(Icons.add))
          : null,
    );
  }
}