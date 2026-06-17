import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/plan_mantenimiento_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/plan_mantenimiento.dart';
import '../../core/responsive.dart';
import '../../services/planes_pdf_service.dart';
import 'plan_mantenimiento_nuevo_screen.dart';
import 'plan_mantenimiento_detail_screen.dart';

class PlanesMantenimientoScreen extends StatefulWidget {
  const PlanesMantenimientoScreen({super.key});

  @override
  State<PlanesMantenimientoScreen> createState() => _PlanesMantenimientoScreenState();
}

class _PlanesMantenimientoScreenState extends State<PlanesMantenimientoScreen> {
  final _busquedaController = TextEditingController();
  String _busqueda = '';
  bool _exportando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanMantenimientoProvider>().cargarPlanes();
    });
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  List<PlanMantenimiento> _filtrar(List<PlanMantenimiento> planes) {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return planes;
    return planes.where((p) {
      final maquina = (p.nombreMaquina ?? '').toLowerCase();
      final codigo = (p.codigoMaquina ?? '').toLowerCase();
      final tarea = p.descripcionTarea.toLowerCase();
      return maquina.contains(q) || codigo.contains(q) || tarea.contains(q);
    }).toList();
  }

  bool get _puedeExportarPdf {
    final usuario = context.read<AuthProvider>().usuario;
    return usuario?.tienePermiso('exportar_pdf_planes') ?? false;
  }

  Future<void> _exportarPdf(List<PlanMantenimiento> planesFiltrados) async {
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;
    setState(() => _exportando = true);
    try {
      await PlanesPdfService.generarYCompartir(
        planes: planesFiltrados,
        nombreEmpresa: usuario.empresaId,
        busqueda: _busqueda,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Color _colorIntervalo(String tipo) {
    switch (tipo) {
      case 'dias':   return const Color(0xFF1976D2);
      case 'horas':  return const Color(0xFFE65100);
      case 'ciclos': return const Color(0xFF6A1B9A);
      case 'm3':     return const Color(0xFF00695C);
      default:       return const Color(0xFF37474F);
    }
  }

  IconData _iconoIntervalo(String tipo) {
    switch (tipo) {
      case 'dias':   return Icons.calendar_today_outlined;
      case 'horas':  return Icons.timer_outlined;
      case 'ciclos': return Icons.loop_outlined;
      case 'm3':     return Icons.water_outlined;
      default:       return Icons.event_repeat_outlined;
    }
  }

  Future<void> _editarPlan(PlanMantenimiento plan) async {
    final actualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PlanMantenimientoNuevoScreen(plan: plan)),
    );
    if (actualizado == true && context.mounted) {
      context.read<PlanMantenimientoProvider>().cargarPlanes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlanMantenimientoProvider>();
    final usuario = context.read<AuthProvider>().usuario;
    final padding = Responsive.pagePadding(context);
    final esAdminOEncargado = usuario?.esAdmin == true || usuario?.esEncargado == true;
    final planesFiltrados = _filtrar(provider.planes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes de Mantenimiento', style: TextStyle(fontSize: 17)),
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          if (_puedeExportarPdf)
            _exportando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  )
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Exportar PDF',
                    onPressed: provider.planes.isEmpty ? null : () => _exportarPdf(planesFiltrados),
                  ),
        ],
      ),
      floatingActionButton: esAdminOEncargado
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlanMantenimientoNuevoScreen()),
                );
                if (context.mounted) {
                  context.read<PlanMantenimientoProvider>().cargarPlanes();
                }
              },
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
              extendedPadding: const EdgeInsets.symmetric(horizontal: 14),
              extendedIconLabelSpacing: 6,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nuevo plan', style: TextStyle(fontSize: 12)),
            )
          : null,
      body: provider.cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: TextField(
                    controller: _busquedaController,
                    onChanged: (v) => setState(() => _busqueda = v),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Buscar por máquina o tarea...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      suffixIcon: _busqueda.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => setState(() { _busqueda = ''; _busquedaController.clear(); }),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                  ),
                ),
                // Contador
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: Colors.grey[100],
                  child: Row(children: [
                    Text('${planesFiltrados.length} plan${planesFiltrados.length != 1 ? 'es' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const Spacer(),
                    if (_busqueda.trim().isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() { _busqueda = ''; _busquedaController.clear(); }),
                        child: Row(children: [
                          Icon(Icons.filter_alt_off_outlined, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('Limpiar búsqueda', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                        ]),
                      ),
                  ]),
                ),
                Expanded(child: _buildLista(provider, planesFiltrados, esAdminOEncargado, padding)),
              ],
            ),
    );
  }

  Widget _buildLista(
    PlanMantenimientoProvider provider,
    List<PlanMantenimiento> planesFiltrados,
    bool esAdminOEncargado,
    EdgeInsets padding,
  ) {
    if (provider.planes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_repeat_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No hay planes de mantenimiento', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Creá un plan para programar mantenimientos preventivos', style: TextStyle(fontSize: 10, color: Colors.grey[400]), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (planesFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_outlined, size: 70, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No hay planes para esa búsqueda', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() { _busqueda = ''; _busquedaController.clear(); }),
              child: const Text('Limpiar búsqueda'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: planesFiltrados.length,
      itemBuilder: (context, index) {
        final plan = planesFiltrados[index];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlanMantenimientoDetailScreen(plan: plan)),
          ),
          child: _PlanCard(
            plan: plan,
            colorIntervalo: _colorIntervalo(plan.tipoIntervalo),
            iconoIntervalo: _iconoIntervalo(plan.tipoIntervalo),
            esAdminOEncargado: esAdminOEncargado,
            onEditar: () => _editarPlan(plan),
            onDesactivar: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Desactivar plan'),
                  content: const Text('¿Seguro que querés desactivar este plan?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Desactivar'),
                    ),
                  ],
                ),
              );
              if (confirmar == true && context.mounted) {
                await context.read<PlanMantenimientoProvider>().desactivarPlan(plan.id);
              }
            },
          ),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanMantenimiento plan;
  final Color colorIntervalo;
  final IconData iconoIntervalo;
  final bool esAdminOEncargado;
  final VoidCallback onEditar;
  final VoidCallback onDesactivar;

  const _PlanCard({
    required this.plan,
    required this.colorIntervalo,
    required this.iconoIntervalo,
    required this.esAdminOEncargado,
    required this.onEditar,
    required this.onDesactivar,
  });

  String get _frecuenciaLabel {
    final valor = plan.intervaloValor.truncateToDouble() == plan.intervaloValor
        ? plan.intervaloValor.toInt().toString()
        : plan.intervaloValor.toStringAsFixed(1);
    return 'Cada $valor ${plan.unidadIntervalo}';
  }

  String? get _proximoLabel {
    if (plan.proximoValor == null) return null;
    final valor = plan.proximoValor!.truncateToDouble() == plan.proximoValor
        ? plan.proximoValor!.toInt().toString()
        : plan.proximoValor!.toStringAsFixed(1);
    return '$valor ${plan.unidadIntervalo}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: colorIntervalo),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(color: colorIntervalo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(iconoIntervalo, color: colorIntervalo, size: 18),
                          ),
                          const SizedBox(width: 10),
                          if (plan.nombreMaquina != null) ...[
                            Icon(Icons.precision_manufacturing_outlined, size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                plan.codigoMaquina != null ? '${plan.nombreMaquina} (${plan.codigoMaquina})' : plan.nombreMaquina!,
                                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ] else
                            const Spacer(),
                          if (esAdminOEncargado)
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 20,
                                icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (_) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(Icons.edit_outlined, color: Color(0xFF1F4E79)),
                                            title: const Text('Editar plan', style: TextStyle(fontSize: 13)),
                                            onTap: () { Navigator.pop(context); onEditar(); },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.block, color: Colors.red),
                                            title: const Text('Desactivar plan', style: TextStyle(fontSize: 13)),
                                            onTap: () { Navigator.pop(context); onDesactivar(); },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        plan.descripcionTarea,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF1A237E), height: 1.3),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: colorIntervalo.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: colorIntervalo.withOpacity(0.3), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(iconoIntervalo, size: 11, color: colorIntervalo),
                                const SizedBox(width: 4),
                                Text(_frecuenciaLabel, style: TextStyle(fontSize: 9, color: colorIntervalo, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          if (_proximoLabel != null) ...[
                            const SizedBox(width: 10),
                            Icon(Icons.schedule_outlined, size: 12, color: Colors.grey[400]),
                            const SizedBox(width: 3),
                            Flexible(child: Text('Próximo: $_proximoLabel', style: TextStyle(fontSize: 8, color: Colors.grey[500]), overflow: TextOverflow.ellipsis)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}