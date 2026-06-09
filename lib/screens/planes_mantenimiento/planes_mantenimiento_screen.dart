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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanMantenimientoProvider>().cargarPlanes();
    });
  }

  Color _colorIntervalo(String tipo) {
    switch (tipo) {
      case 'dias': return Colors.blue;
      case 'horas': return Colors.orange;
      case 'ciclos': return Colors.purple;
      case 'm3': return Colors.teal;
      default: return Colors.indigo;
    }
  }

  IconData _iconoIntervalo(String tipo) {
    switch (tipo) {
      case 'dias': return Icons.calendar_today_outlined;
      case 'horas': return Icons.timer_outlined;
      case 'ciclos': return Icons.loop_outlined;
      case 'm3': return Icons.water_outlined;
      default: return Icons.event_repeat_outlined;
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
        title: const Text('Planes de Mantenimiento'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
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
              icon: const Icon(Icons.add),
              label: const Text('Nuevo plan'),
            )
          : null,
      body: provider.cargando
          ? const Center(child: CircularProgressIndicator())
          : provider.planes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_repeat_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No hay planes de mantenimiento', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text('Creá un plan para programar mantenimientos preventivos', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: padding,
                  itemCount: provider.planes.length,
                  itemBuilder: (context, index) {
                    final plan = provider.planes[index];
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
                      ),
                    );
                  },
                ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanMantenimiento plan;
  final Color colorIntervalo;
  final IconData iconoIntervalo;
  final bool esAdminOEncargado;
  final VoidCallback onDesactivar;

  const _PlanCard({
    required this.plan,
    required this.colorIntervalo,
    required this.iconoIntervalo,
    required this.esAdminOEncargado,
    required this.onDesactivar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorIntervalo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(iconoIntervalo, color: colorIntervalo, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (plan.nombreMaquina != null)
                        Row(
                          children: [
                            Icon(Icons.precision_manufacturing_outlined, size: 13, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              plan.codigoMaquina != null
                                  ? '${plan.nombreMaquina} (${plan.codigoMaquina})'
                                  : plan.nombreMaquina!,
                              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      const SizedBox(height: 2),
                      Text(
                        plan.descripcionTarea,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cada ${plan.intervaloValor.toStringAsFixed(plan.intervaloValor.truncateToDouble() == plan.intervaloValor ? 0 : 1)} ${plan.unidadIntervalo}',
                        style: TextStyle(color: colorIntervalo, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (esAdminOEncargado)
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (_) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.block, color: Colors.red),
                                title: const Text('Desactivar plan'),
                                onTap: () {
                                  Navigator.pop(context);
                                  onDesactivar();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            if (plan.proximoValor != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule_outlined, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Próximo: ${plan.proximoValor!.toStringAsFixed(plan.proximoValor!.truncateToDouble() == plan.proximoValor ? 0 : 1)} ${plan.unidadIntervalo}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}