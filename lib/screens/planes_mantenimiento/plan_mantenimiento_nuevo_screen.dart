import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/plan_mantenimiento.dart';
import '../../providers/plan_mantenimiento_provider.dart';
import '../../providers/tipo_intervalo_provider.dart';
import '../../core/responsive.dart';

class PlanMantenimientoNuevoScreen extends StatefulWidget {
  final PlanMantenimiento? plan;

  const PlanMantenimientoNuevoScreen({super.key, this.plan});

  @override
  State<PlanMantenimientoNuevoScreen> createState() => _PlanMantenimientoNuevoScreenState();
}

class _PlanMantenimientoNuevoScreenState extends State<PlanMantenimientoNuevoScreen> {
  final _supabase = Supabase.instance.client;
  late final _descripcionController = TextEditingController(text: widget.plan?.descripcionTarea ?? '');
  late final _intervaloController = TextEditingController(
    text: widget.plan != null
        ? widget.plan!.intervaloValor.toStringAsFixed(
            widget.plan!.intervaloValor.truncateToDouble() == widget.plan!.intervaloValor ? 0 : 1)
        : '',
  );
  late final _procedimientoController = TextEditingController(text: widget.plan?.procedimiento ?? '');

  bool get _esEdicion => widget.plan != null;

  List<Map<String, dynamic>> _maquinas = [];
  String? _maquinaSeleccionada;
  String? _tipoIntervaloSeleccionado;
  bool _cargando = false;
  bool _cargandoMaquinas = true;

  @override
  void initState() {
    super.initState();
    _maquinaSeleccionada = widget.plan?.maquinaId;
    _tipoIntervaloSeleccionado = widget.plan?.tipoIntervalo;
    _cargarMaquinas();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TipoIntervaloProvider>().cargarTipos().then((_) {
        final tipos = context.read<TipoIntervaloProvider>().tipos;
        if (tipos.isNotEmpty && _tipoIntervaloSeleccionado == null) {
          setState(() => _tipoIntervaloSeleccionado = tipos.first.codigo);
        }
      });
    });
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _intervaloController.dispose();
    _procedimientoController.dispose();
    super.dispose();
  }

  Future<void> _cargarMaquinas() async {
    try {
      final data = await _supabase
          .from('maquinas')
          .select('id, nombre, codigo, sectores(nombre)')
          .order('nombre');
      setState(() {
        _maquinas = List<Map<String, dynamic>>.from(data);
        if (_maquinaSeleccionada == null && _maquinas.isNotEmpty) {
          _maquinaSeleccionada = _maquinas.first['id'];
        }
      });
    } catch (e) {
      _mostrarError('Error al cargar activos: $e');
    } finally {
      setState(() => _cargandoMaquinas = false);
    }
  }

  Future<void> _guardar() async {
    if (_maquinaSeleccionada == null) {
      _mostrarError('Seleccioná un activo');
      return;
    }
    if (_descripcionController.text.trim().isEmpty) {
      _mostrarError('Ingresá la descripción de la tarea');
      return;
    }
    if (_tipoIntervaloSeleccionado == null) {
      _mostrarError('Seleccioná un tipo de intervalo');
      return;
    }
    final valor = double.tryParse(_intervaloController.text.trim());
    if (valor == null || valor <= 0) {
      _mostrarError('Ingresá un intervalo válido mayor a 0');
      return;
    }

    setState(() => _cargando = true);
    try {
      final provider = context.read<PlanMantenimientoProvider>();
      final ok = _esEdicion
          ? await provider.actualizarPlan(
              id: widget.plan!.id,
              descripcionTarea: _descripcionController.text.trim(),
              tipoIntervalo: _tipoIntervaloSeleccionado!,
              intervaloValor: valor,
              procedimiento: _procedimientoController.text.trim().isEmpty
                  ? null
                  : _procedimientoController.text.trim(),
            )
          : await provider.crearPlan(
              maquinaId: _maquinaSeleccionada!,
              descripcionTarea: _descripcionController.text.trim(),
              tipoIntervalo: _tipoIntervaloSeleccionado!,
              intervaloValor: valor,
              procedimiento: _procedimientoController.text.trim().isEmpty
                  ? null
                  : _procedimientoController.text.trim(),
            );

      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esEdicion ? 'Plan actualizado correctamente' : 'Plan creado correctamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        _mostrarError(_esEdicion ? 'Error al actualizar el plan' : 'Error al crear el plan');
      }
    } finally {
      setState(() => _cargando = false);
    }
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.pagePadding(context);
    final tiposProvider = context.watch<TipoIntervaloProvider>();
    final tipos = tiposProvider.tipos;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _esEdicion ? 'Editar Plan' : 'Nuevo Plan',
          style: const TextStyle(fontSize: 17),
        ),
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: _cargandoMaquinas
          ? const Center(child: CircularProgressIndicator())
          : _maquinas.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.precision_manufacturing_outlined, size: 80, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('No hay activos disponibles', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ]),
                )
              : ListView(
                  padding: padding,
                  children: [
                    // Activo (no editable en modo edición)
                    DropdownButtonFormField<String>(
                      value: _maquinaSeleccionada,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Activo *',
                        labelStyle: const TextStyle(fontSize: 13),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.precision_manufacturing_outlined, size: 20),
                        helperText: _esEdicion ? 'El activo no puede modificarse' : null,
                        helperStyle: const TextStyle(fontSize: 10),
                        isDense: true,
                      ),
                      items: _maquinas.map((m) {
                        final sector = (m['sectores'] as Map?)?['nombre'] ?? '';
                        return DropdownMenuItem(
                          value: m['id'] as String,
                          child: Text(
                            '${m['nombre']} (${m['codigo']}) — $sector',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: _esEdicion ? null : (v) => setState(() => _maquinaSeleccionada = v),
                    ),
                    const SizedBox(height: 16),

                    // Descripción
                    TextField(
                      controller: _descripcionController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Tarea de mantenimiento *',
                        labelStyle: TextStyle(fontSize: 13),
                        border: OutlineInputBorder(),
                        hintText: 'Ej: Cambio de filtro de aceite',
                        prefixIcon: Icon(Icons.build_outlined, size: 20),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Cada cuánto (cifra) + Tipo de intervalo (dropdown) lado a lado
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cifra
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _intervaloController,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Cada cuánto *',
                              labelStyle: TextStyle(fontSize: 13),
                              border: OutlineInputBorder(),
                              hintText: 'Ej: 30',
                              prefixIcon: Icon(Icons.repeat_outlined, size: 20),
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Tipo de intervalo (dropdown)
                        Expanded(
                          flex: 3,
                          child: tiposProvider.cargando
                              ? const SizedBox(
                                  height: 48,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                )
                              : DropdownButtonFormField<String>(
                                  value: _tipoIntervaloSeleccionado,
                                  isExpanded: true,
                                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo *',
                                    labelStyle: TextStyle(fontSize: 13),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                                  ),
                                  items: tipos.map((t) {
                                    return DropdownMenuItem(
                                      value: t.codigo,
                                      child: Text(
                                        t.nombre,
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (v) => setState(() => _tipoIntervaloSeleccionado = v),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Procedimiento
                    TextField(
                      controller: _procedimientoController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Procedimiento / Guía de ejecución',
                        labelStyle: TextStyle(fontSize: 13),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        hintText: 'Describí los pasos a seguir, herramientas necesarias, advertencias de seguridad...',
                        prefixIcon: Icon(Icons.checklist_outlined, size: 20),
                      ),
                      maxLines: 8,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _cargando ? null : _guardar,
                        icon: _cargando
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_outlined, size: 20),
                        label: Text(_esEdicion ? 'Guardar cambios' : 'Guardar plan', style: const TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F4E79),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}