import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/plan_mantenimiento_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/plan_mantenimiento.dart';
import '../../core/responsive.dart';
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

  // Filtra por nombre de máquina, código de máquina y descripción de la tarea
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes de Mantenimiento', style: TextStyle(fontSize: 17)),
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: (esAdminOEncargado && provider.mostrandoActivos)
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
                // Buscador por máquina / tarea
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
                              onPressed: () => setState(() {
                                _busqueda = '';
                                _busquedaController.clear();
                              }),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
                _buildToggleEstado(provider),
                Expanded(child: _buildLista(provider, esAdminOEncargado, padding)),
              ],
            ),
    );
  }

  // Toggle compacto: Activos / Inactivos
  Widget _buildToggleEstado(PlanMantenimientoProvider provider) {
    Widget opcion(String label, bool valorActivos) {
      final seleccionado = provider.mostrandoActivos == valorActivos;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (!seleccionado) provider.setMostrandoActivos(valorActivos);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: seleccionado ? const Color(0xFF1F4E79) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: seleccionado ? FontWeight.w600 : FontWeight.normal,
                color: seleccionado ? Colors.white : Colors.grey[600],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          opcion('Activos', true),
          opcion('Desactivados', false),
        ],
      ),
    );
  }

  Widget _buildLista(
    PlanMantenimientoProvider provider,
    bool esAdminOEncargado,
    EdgeInsets padding,
  ) {
    if (provider.planes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              provider.mostrandoActivos ? Icons.event_repeat_outlined : Icons.inbox_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              provider.mostrandoActivos
                  ? 'No hay planes de mantenimiento'
                  : 'No hay planes desactivados',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              provider.mostrandoActivos
                  ? 'Creá un plan para programar mantenimientos preventivos'
                  : 'Los planes que desactives aparecerán acá',
              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final planesFiltrados = _filtrar(provider.planes);

    if (planesFiltrados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_outlined, size: 70, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No hay planes para esa búsqueda',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {
                _busqueda = '';
                _busquedaController.clear();
              }),
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
            MaterialPageRoute(
              builder: (_) => PlanMantenimientoDetailScreen(plan: plan),
            ),
          ),
          child: _PlanCard(
            plan: plan,
            colorIntervalo: _colorIntervalo(plan.tipoIntervalo),
            iconoIntervalo: _iconoIntervalo(plan.tipoIntervalo),
            esAdminOEncargado: esAdminOEncargado,
            mostrandoActivos: provider.mostrandoActivos,
            onEditar: () => _editarPlan(plan),
            onDesactivar: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Desactivar plan'),
                  content: const Text('¿Seguro que querés desactivar este plan?'),
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
                      child: const Text('Desactivar'),
                    ),
                  ],
                ),
              );
              if (confirmar == true && context.mounted) {
                await context.read<PlanMantenimientoProvider>().desactivarPlan(plan.id);
              }
            },
            onReactivar: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Reactivar plan'),
                  content: const Text('¿Querés reactivar este plan? Volverá a la lista de planes activos.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F4E79),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reactivar'),
                    ),
                  ],
                ),
              );
              if (confirmar == true && context.mounted) {
                await context.read<PlanMantenimientoProvider>().reactivarPlan(plan.id);
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
  final bool mostrandoActivos;
  final VoidCallback onEditar;
  final VoidCallback onDesactivar;
  final VoidCallback onReactivar;

  const _PlanCard({
    required this.plan,
    required this.colorIntervalo,
    required this.iconoIntervalo,
    required this.esAdminOEncargado,
    required this.mostrandoActivos,
    required this.onEditar,
    required this.onDesactivar,
    required this.onReactivar,
  });

  String get _frecuenciaLabel => plan.frecuenciaLabel;

  String? get _proximoLabel => plan.proximoLabel;

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
              // Borde izquierdo de color según tipo de intervalo
              Container(width: 4, color: colorIntervalo),

              // Contenido principal
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila superior: ícono + nombre máquina + menú
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: colorIntervalo.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(iconoIntervalo, color: colorIntervalo, size: 18),
                          ),
                          const SizedBox(width: 10),
                          if (plan.nombreMaquina != null) ...[
                            Icon(
                              Icons.precision_manufacturing_outlined,
                              size: 12,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                plan.codigoMaquina != null
                                    ? '${plan.nombreMaquina} (${plan.codigoMaquina})'
                                    : plan.nombreMaquina!,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
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
                                        children: mostrandoActivos
                                            ? [
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.edit_outlined,
                                                    color: Color(0xFF1F4E79),
                                                  ),
                                                  title: const Text('Editar plan', style: TextStyle(fontSize: 13)),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    onEditar();
                                                  },
                                                ),
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.block,
                                                    color: Colors.red,
                                                  ),
                                                  title: const Text('Desactivar plan', style: TextStyle(fontSize: 13)),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    onDesactivar();
                                                  },
                                                ),
                                              ]
                                            : [
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.restore,
                                                    color: Color(0xFF1F4E79),
                                                  ),
                                                  title: const Text('Reactivar plan', style: TextStyle(fontSize: 13)),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    onReactivar();
                                                  },
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

                      // Descripción de la tarea — texto principal
                      Text(
                        plan.descripcionTarea,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Color(0xFF1A237E),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 10),

                      // Chip de frecuencia + próximo valor
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorIntervalo.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colorIntervalo.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(iconoIntervalo, size: 11, color: colorIntervalo),
                                const SizedBox(width: 4),
                                Text(
                                  _frecuenciaLabel,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: colorIntervalo,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_proximoLabel != null) ...[
                            const SizedBox(width: 10),
                            Icon(
                              Icons.schedule_outlined,
                              size: 12,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                'Próximo: $_proximoLabel',
                                style: TextStyle(fontSize: 8, color: Colors.grey[500]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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