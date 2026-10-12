import 'package:flutter/material.dart';
import 'reporte_historial_maquina_screen.dart';

/// Índice del módulo Reportes.
///
/// Criterio de orden:
/// - Cada reporte vive en su propia pantalla dentro de lib/screens/reportes/
///   (reporte_<nombre>_screen.dart).
/// - Su PDF va en lib/services/ (<nombre>_pdf_service.dart).
/// - Para habilitarlo acá, se agrega un método estático que devuelve la
///   pantalla y se lo pasa en `pantalla:` (ver _historialMaquina).
class ReportesScreen extends StatelessWidget {
  const ReportesScreen({super.key});

  static Widget _historialMaquina(BuildContext context) =>
      const ReporteHistorialMaquinaScreen();

  static const List<_Reporte> _reportes = [
    _Reporte(
      titulo: 'Historial de un activo',
      descripcion: 'Tickets, planes, lecturas y adjuntos de un activo, '
          'listo para exportar a PDF.',
      icono: Icons.precision_manufacturing_outlined,
      pantalla: _historialMaquina,
    ),
    _Reporte(
      titulo: 'Resumen mensual',
      descripcion: 'Tickets abiertos y cerrados, preventivo vs. correctivo, '
          'MTTR y pendientes del período.',
      icono: Icons.calendar_month_outlined,
    ),
    _Reporte(
      titulo: 'Mis pendientes',
      descripcion: 'Tus tickets asignados, ordenados por prioridad.',
      icono: Icons.assignment_ind_outlined,
    ),
    _Reporte(
      titulo: 'Cumplimiento de planes',
      descripcion: 'Mantenimientos programados contra los realmente '
          'ejecutados.',
      icono: Icons.event_available_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final reporte in _reportes) _ReporteCard(reporte: reporte),
            ],
          ),
        ),
      ),
    );
  }
}

class _Reporte {
  const _Reporte({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    this.pantalla,
  });

  final String titulo;
  final String descripcion;
  final IconData icono;

  /// Constructor de la pantalla del reporte. Mientras sea null, la entrada
  /// se muestra deshabilitada con la leyenda "Próximamente".
  final WidgetBuilder? pantalla;
}

class _ReporteCard extends StatelessWidget {
  const _ReporteCard({required this.reporte});

  final _Reporte reporte;

  @override
  Widget build(BuildContext context) {
    final pantalla = reporte.pantalla;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: pantalla != null,
        leading: Icon(reporte.icono),
        title: Text(reporte.titulo),
        subtitle: Text(reporte.descripcion),
        trailing: pantalla == null
            ? const Text('Próximamente')
            : const Icon(Icons.chevron_right),
        onTap: pantalla == null
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: pantalla),
                ),
      ),
    );
  }
}