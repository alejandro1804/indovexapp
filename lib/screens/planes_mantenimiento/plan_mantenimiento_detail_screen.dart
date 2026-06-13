import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/plan_mantenimiento.dart';
import '../../providers/plan_mantenimiento_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';
import 'plan_mantenimiento_nuevo_screen.dart';

class PlanMantenimientoDetailScreen extends StatefulWidget {
  final PlanMantenimiento plan;

  const PlanMantenimientoDetailScreen({super.key, required this.plan});

  @override
  State<PlanMantenimientoDetailScreen> createState() => _PlanMantenimientoDetailScreenState();
}

class _PlanMantenimientoDetailScreenState extends State<PlanMantenimientoDetailScreen> {
  late PlanMantenimiento _plan;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
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

  Future<void> _editar() async {
    final actualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PlanMantenimientoNuevoScreen(plan: _plan)),
    );
    if (actualizado == true && mounted) {
      final provider = context.read<PlanMantenimientoProvider>();
      final nuevo = provider.planes.where((p) => p.id == _plan.id).firstOrNull;
      if (nuevo != null) setState(() => _plan = nuevo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.pagePadding(context);
    final usuario = context.read<AuthProvider>().usuario;
    final esAdminOEncargado = usuario?.esAdmin == true || usuario?.esEncargado == true;
    final color = _colorIntervalo(_plan.tipoIntervalo);
    final plan = _plan;

    return Scaffold(
      appBar: AppBar(
        title: Text(plan.descripcionTarea),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          if (esAdminOEncargado)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar plan',
              onPressed: _editar,
            ),
          if (esAdminOEncargado)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Desactivar plan',
              onPressed: () async {
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
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: padding,
        children: [
          // Header máquina e intervalo
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconoIntervalo(plan.tipoIntervalo), color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (plan.nombreMaquina != null)
                    Text(
                      plan.codigoMaquina != null
                          ? '${plan.nombreMaquina} (${plan.codigoMaquina})'
                          : plan.nombreMaquina!,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Cada ${plan.intervaloValor.toStringAsFixed(plan.intervaloValor.truncateToDouble() == plan.intervaloValor ? 0 : 1)} ${plan.unidadIntervalo}',
                    style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  if (plan.proximoValor != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Próximo: ${plan.proximoValor!.toStringAsFixed(plan.proximoValor!.truncateToDouble() == plan.proximoValor ? 0 : 1)} ${plan.unidadIntervalo}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Descripción de la tarea
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tarea', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Divider(),
                Text(plan.descripcionTarea, style: const TextStyle(fontSize: 14)),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Procedimiento
          if (plan.procedimiento != null && plan.procedimiento!.isNotEmpty)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.checklist_outlined, size: 18, color: Color(0xFF1F4E79)),
                    const SizedBox(width: 8),
                    const Text('Procedimiento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const Divider(),
                  Text(plan.procedimiento!, style: const TextStyle(fontSize: 14, height: 1.6)),
                ]),
              ),
            )
          else
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.checklist_outlined, size: 18, color: Color(0xFF1F4E79)),
                    const SizedBox(width: 8),
                    const Text('Procedimiento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const Divider(),
                  Text('Sin procedimiento cargado.', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                ]),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}