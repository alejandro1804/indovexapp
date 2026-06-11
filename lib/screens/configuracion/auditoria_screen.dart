import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/audit_log_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/audit_log.dart';
import '../../services/auditoria_pdf_service.dart';
import 'auditoria_detalle_screen.dart';

class AuditoriaScreen extends StatefulWidget {
  const AuditoriaScreen({super.key});

  @override
  State<AuditoriaScreen> createState() => _AuditoriaScreenState();
}

class _AuditoriaScreenState extends State<AuditoriaScreen> {
  final _supabase = Supabase.instance.client;
  List<String> _tablasDisponibles = [];
  String _nombreEmpresa = 'Empresa';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<AuditLogProvider>();
      await provider.cargarLogs();
      final tablas = await provider.obtenerTablasDisponibles();
      await _cargarNombreEmpresa();
      if (mounted) setState(() => _tablasDisponibles = tablas);
    });
  }

  Future<void> _cargarNombreEmpresa() async {
    try {
      final empresaId = context.read<AuthProvider>().usuario?.empresaId;
      if (empresaId == null) return;
      final data = await _supabase
          .from('empresas')
          .select('nombre')
          .eq('id', empresaId)
          .single();
      if (mounted) _nombreEmpresa = data['nombre'] ?? 'Empresa';
    } catch (e) {
      // mantiene el valor por defecto
    }
  }

  Color _colorOperacion(String op) {
    switch (op) {
      case 'INSERT': return Colors.green;
      case 'UPDATE': return Colors.orange;
      case 'DELETE': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _iconoOperacion(String op) {
    switch (op) {
      case 'INSERT': return Icons.add_circle_outline;
      case 'UPDATE': return Icons.edit_outlined;
      case 'DELETE': return Icons.delete_outline;
      default: return Icons.help_outline;
    }
  }

  String _formatoFecha(DateTime fechaUtc) {
    final local = fechaUtc.toLocal();
    final f = '${local.year}-${_dos(local.month)}-${_dos(local.day)}';
    final h = '${_dos(local.hour)}:${_dos(local.minute)}:${_dos(local.second)}';
    final offset = local.timeZoneOffset;
    final signo = offset.isNegative ? '-' : '+';
    return '$f $h (UTC$signo${offset.inHours.abs()})';
  }

  String _dos(int n) => n.toString().padLeft(2, '0');

  Future<void> _seleccionarRangoFechas() async {
    final provider = context.read<AuditLogProvider>();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDateRange: provider.desde != null && provider.hasta != null
          ? DateTimeRange(start: provider.desde!, end: provider.hasta!)
          : null,
    );
    if (rango != null) {
      provider.setRangoFechas(rango.start, rango.end);
    }
  }

  Future<void> _exportarPdf() async {
    final provider = context.read<AuditLogProvider>();
    try {
      await AuditoriaPdfService.generarYCompartir(
        logs: provider.logs,
        nombreEmpresa: _nombreEmpresa,
        filtroTabla: provider.filtroTabla,
        filtroOperacion: provider.filtroOperacion,
        desde: provider.desde,
        hasta: provider.hasta,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar PDF: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuditLogProvider>();

    final operaciones = {
      'todos': 'Todas',
      'INSERT': 'Creación',
      'UPDATE': 'Modificación',
      'DELETE': 'Eliminación',
    };

    final tablasMap = <String, String>{'todos': 'Todas las tablas'};
    for (final t in _tablasDisponibles) {
      tablasMap[t] = AuditLog(
        id: 0, tabla: t, operacion: '', registroId: '',
        createdAt: DateTime.now(),
      ).tablaLabel;
    }

    final hayFiltros = provider.filtroTabla != 'todos' ||
        provider.filtroOperacion != 'todos' ||
        provider.desde != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoría'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar PDF',
            onPressed: provider.logs.isEmpty ? null : _exportarPdf,
          ),
          if (hayFiltros)
            IconButton(
              icon: const Icon(Icons.filter_alt_off_outlined),
              tooltip: 'Limpiar filtros',
              onPressed: () => provider.limpiarFiltros(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _buildFiltro('Tabla', provider.filtroTabla, tablasMap,
                    (v) => provider.setFiltroTabla(v)),
                const SizedBox(width: 8),
                _buildFiltro('Operación', provider.filtroOperacion, operaciones,
                    (v) => provider.setFiltroOperacion(v)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _seleccionarRangoFechas,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: provider.desde != null
                          ? const Color(0xFF1F4E79).withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: provider.desde != null
                            ? const Color(0xFF1F4E79)
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.date_range_outlined, size: 16,
                          color: provider.desde != null ? const Color(0xFF1F4E79) : Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        provider.desde != null
                            ? '${_dos(provider.desde!.day)}/${_dos(provider.desde!.month)} - ${_dos(provider.hasta!.day)}/${_dos(provider.hasta!.month)}'
                            : 'Fechas',
                        style: TextStyle(
                          fontSize: 12,
                          color: provider.desde != null ? const Color(0xFF1F4E79) : Colors.grey[600],
                          fontWeight: provider.desde != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.grey[100],
            child: Text(
              '${provider.logs.length} evento${provider.logs.length != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: provider.cargando
                ? const Center(child: CircularProgressIndicator())
                : provider.logs.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.history_outlined, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No hay eventos de auditoría', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        ]),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.logs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final log = provider.logs[index];
                          final color = _colorOperacion(log.operacion);
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => AuditoriaDetalleScreen(log: log)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: color.withOpacity(0.1),
                                    child: Icon(_iconoOperacion(log.operacion), color: color, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [
                                        Text(log.operacionLabel,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(log.tablaLabel,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                      ]),
                                      const SizedBox(height: 2),
                                      Text(
                                        log.nombreUsuario ?? 'Sistema',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                      Text(
                                        _formatoFecha(log.createdAt),
                                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                      ),
                                    ]),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.grey),
                                ]),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltro(String titulo, String valorActual, Map<String, String> opciones, ValueChanged<String> onSelect) {
    final activo = valorActual != 'todos';
    return PopupMenuButton<String>(
      onSelected: onSelect,
      itemBuilder: (context) => opciones.entries
          .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFF1F4E79).withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? const Color(0xFF1F4E79) : Colors.grey[300]!),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            activo ? (opciones[valorActual] ?? titulo) : titulo,
            style: TextStyle(
              fontSize: 12,
              color: activo ? const Color(0xFF1F4E79) : Colors.grey[600],
              fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, size: 18, color: activo ? const Color(0xFF1F4E79) : Colors.grey[600]),
        ]),
      ),
    );
  }
}