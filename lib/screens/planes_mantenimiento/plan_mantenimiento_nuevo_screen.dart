import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/plan_mantenimiento_provider.dart';
import '../../providers/tipo_intervalo_provider.dart';
import '../../core/responsive.dart';

class PlanMantenimientoNuevoScreen extends StatefulWidget {
  const PlanMantenimientoNuevoScreen({super.key});

  @override
  State<PlanMantenimientoNuevoScreen> createState() => _PlanMantenimientoNuevoScreenState();
}

class _PlanMantenimientoNuevoScreenState extends State<PlanMantenimientoNuevoScreen> {
  final _supabase = Supabase.instance.client;
  final _descripcionController = TextEditingController();
  final _intervaloController = TextEditingController();
  final _procedimientoController = TextEditingController();

  List<Map<String, dynamic>> _maquinas = [];
  String? _maquinaSeleccionada;
  String? _tipoIntervaloSeleccionado;
  bool _cargando = false;
  bool _cargandoMaquinas = true;

  @override
  void initState() {
    super.initState();
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
        if (_maquinas.isNotEmpty) _maquinaSeleccionada = _maquinas.first['id'];
      });
    } catch (e) {
      _mostrarError('Error al cargar máquinas: $e');
    } finally {
      setState(() => _cargandoMaquinas = false);
    }
  }

  String get _unidadLabel {
    final tipos = context.read<TipoIntervaloProvider>().tipos;
    final tipo = tipos.where((t) => t.codigo == _tipoIntervaloSeleccionado).firstOrNull;
    return tipo?.nombre ?? '';
  }

  Future<void> _guardar() async {
    if (_maquinaSeleccionada == null) {
      _mostrarError('Seleccioná una máquina');
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
      final ok = await context.read<PlanMantenimientoProvider>().crearPlan(
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
          const SnackBar(
            content: Text('Plan creado correctamente'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        _mostrarError('Error al crear el plan');
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
        title: const Text('Nuevo Plan de Mantenimiento'),
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
                    Text('No hay máquinas disponibles', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                  ]),
                )
              : ListView(
                  padding: padding,
                  children: [
                    // Máquina
                    DropdownButtonFormField<String>(
                      value: _maquinaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Máquina *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                      ),
                      items: _maquinas.map((m) {
                        final sector = (m['sectores'] as Map?)?['nombre'] ?? '';
                        return DropdownMenuItem(
                          value: m['id'] as String,
                          child: Text('${m['nombre']} (${m['codigo']}) — $sector', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _maquinaSeleccionada = v),
                    ),
                    const SizedBox(height: 16),

                    // Descripción
                    TextField(
                      controller: _descripcionController,
                      decoration: const InputDecoration(
                        labelText: 'Tarea de mantenimiento *',
                        border: OutlineInputBorder(),
                        hintText: 'Ej: Cambio de filtro de aceite',
                        prefixIcon: Icon(Icons.build_outlined),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 16),

                    // Tipo intervalo desde DB
                    const Text('Tipo de intervalo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                    const SizedBox(height: 8),
                    tiposProvider.cargando
                        ? const Center(child: CircularProgressIndicator())
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: tipos.map((t) {
                              final seleccionado = _tipoIntervaloSeleccionado == t.codigo;
                              return ChoiceChip(
                                label: Text(t.nombre),
                                selected: seleccionado,
                                selectedColor: const Color(0xFF1F4E79).withOpacity(0.15),
                                labelStyle: TextStyle(
                                  color: seleccionado ? const Color(0xFF1F4E79) : Colors.grey[600],
                                  fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: seleccionado ? const Color(0xFF1F4E79) : Colors.grey[300]!,
                                ),
                                onSelected: (_) => setState(() => _tipoIntervaloSeleccionado = t.codigo),
                              );
                            }).toList(),
                          ),
                    const SizedBox(height: 16),

                    // Valor intervalo
                    TextField(
                      controller: _intervaloController,
                      decoration: InputDecoration(
                        labelText: 'Cada cuánto *',
                        border: const OutlineInputBorder(),
                        hintText: 'Ej: 30',
                        prefixIcon: const Icon(Icons.repeat_outlined),
                        suffixText: _unidadLabel,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),

                    // Procedimiento
                    TextField(
                      controller: _procedimientoController,
                      decoration: const InputDecoration(
                        labelText: 'Procedimiento / Guía de ejecución',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        hintText: 'Describí los pasos a seguir, herramientas necesarias, advertencias de seguridad...',
                        prefixIcon: Icon(Icons.checklist_outlined),
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
                            : const Icon(Icons.save_outlined),
                        label: const Text('Guardar plan', style: TextStyle(fontSize: 16)),
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