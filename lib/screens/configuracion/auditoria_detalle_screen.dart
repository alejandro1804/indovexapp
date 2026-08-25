import 'package:flutter/material.dart';
import '../../models/audit_log.dart';

class AuditoriaDetalleScreen extends StatelessWidget {
  final AuditLog log;

  const AuditoriaDetalleScreen({super.key, required this.log});

  Color _colorOperacion(String op) {
    switch (op) {
      case 'INSERT': return Colors.green;
      case 'UPDATE': return Colors.orange;
      case 'DELETE': return Colors.red;
      default: return Colors.grey;
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

  // Determina qué campos cambiaron entre antes y después
  List<String> _camposModificados() {
    if (log.datosAntes == null || log.datosDespues == null) return [];
    final cambios = <String>[];
    final todasLasClaves = {...log.datosAntes!.keys, ...log.datosDespues!.keys};
    for (final k in todasLasClaves) {
      final antes = log.datosAntes![k];
      final despues = log.datosDespues![k];
      if (antes.toString() != despues.toString()) {
        cambios.add(k);
      }
    }
    return cambios;
  }

  String _formatoValor(dynamic valor) {
    if (valor == null) return '(vacío)';
    if (valor is String && valor.isEmpty) return '(vacío)';
    return valor.toString();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorOperacion(log.operacion);
    final camposModificados = _camposModificados();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de auditoría', style: TextStyle(fontSize: 17)),
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Encabezado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(log.operacionLabel,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(log.tablaLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: 12),
              _metaRow('Usuario', log.nombreUsuario ?? 'Sistema'),
              _metaRow('Fecha', _formatoFecha(log.createdAt)),
              _metaRow('ID registro', log.registroId),
              if (log.ip != null) _metaRow('IP', log.ip!),
            ]),
          ),
          const SizedBox(height: 16),

          // Contenido según operación
          if (log.operacion == 'UPDATE')
            _buildCambios(camposModificados)
          else if (log.operacion == 'INSERT')
            _buildSnapshot('Datos creados', log.datosDespues)
          else if (log.operacion == 'DELETE')
            _buildSnapshot('Datos eliminados', log.datosAntes),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCambios(List<String> campos) {
    if (campos.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No se registraron cambios de valores.', style: TextStyle(color: Colors.grey, fontSize: 11)),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Cambios realizados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const Divider(),
          ...campos.map((campo) {
            final antes = _formatoValor(log.datosAntes?[campo]);
            final despues = _formatoValor(log.datosDespues?[campo]);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(campo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Antes', style: TextStyle(fontSize: 9, color: Colors.red[700])),
                        Text(antes, style: const TextStyle(fontSize: 11)),
                      ]),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Después', style: TextStyle(fontSize: 9, color: Colors.green[700])),
                        Text(despues, style: const TextStyle(fontSize: 11)),
                      ]),
                    ),
                  ),
                ]),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _buildSnapshot(String titulo, Map<String, dynamic>? datos) {
    if (datos == null || datos.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Sin datos disponibles.', style: TextStyle(color: Colors.grey, fontSize: 11)),
        ),
      );
    }

    final claves = datos.keys.toList()..sort();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const Divider(),
          ...claves.map((k) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 130,
                    child: Text(k, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ),
                  Expanded(
                    child: Text(_formatoValor(datos[k]), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  ),
                ]),
              )),
        ]),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600]))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}