import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Vista 2 — Historial de pagos de una empresa (super admin).
/// Se abre desde EmpresasScreen con el botón "Ver pagos".
class PagosEmpresaScreen extends StatefulWidget {
  final String empresaId;
  final String empresaNombre;

  const PagosEmpresaScreen({
    super.key,
    required this.empresaId,
    required this.empresaNombre,
  });

  @override
  State<PagosEmpresaScreen> createState() => _PagosEmpresaScreenState();
}

class _PagosEmpresaScreenState extends State<PagosEmpresaScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _pagos = [];
  bool _cargando = true;

  // Resumen (se llena desde la primera fila de la RPC)
  double _totalCobrado = 0;
  int _cantAprobados = 0;
  int _cantSinFacturar = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await _supabase.rpc('sa_listar_pagos_empresa',
          params: {'p_empresa_id': widget.empresaId});
      final lista = List<Map<String, dynamic>>.from(data);
      setState(() {
        _pagos = lista;
        if (lista.isNotEmpty) {
          final r = lista.first;
          _totalCobrado = (r['total_cobrado'] as num?)?.toDouble() ?? 0;
          _cantAprobados = (r['cant_aprobados'] as num?)?.toInt() ?? 0;
          _cantSinFacturar = (r['cant_sin_facturar'] as num?)?.toInt() ?? 0;
        } else {
          _totalCobrado = 0;
          _cantAprobados = 0;
          _cantSinFacturar = 0;
        }
      });
    } catch (e) {
      _mostrarError('Error al cargar pagos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  void _mostrarExito(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
    );
  }

  String _tierPorMonto(dynamic monto) {
    final m = (monto as num?)?.toDouble() ?? 0;
    if (m >= 1100) return 'Pro';
    if (m >= 450) return 'Starter';
    return '—';
  }

  Future<void> _marcarFacturado(Map<String, dynamic> pago) async {
    final controller = TextEditingController(
        text: (pago['factura_numero'] ?? '').toString());
    final yaFacturado = pago['facturado'] == true;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(yaFacturado ? 'Editar facturación' : 'Marcar como facturado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Empresa: ${pago['empresa_nombre']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Monto: ${_montoFmt(pago['monto'])} ${pago['moneda'] ?? ''}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Número de factura / e-ticket (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          if (yaFacturado)
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Desmarcar', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (resultado == null) return;

    try {
      if (resultado == false) {
        await _supabase.rpc('marcar_pago_facturado', params: {
          'p_pago_id': pago['pago_id'],
          'p_facturado': false,
        });
        _mostrarExito('Pago desmarcado');
      } else {
        final numero = controller.text.trim();
        await _supabase.rpc('marcar_pago_facturado', params: {
          'p_pago_id': pago['pago_id'],
          'p_facturado': true,
          'p_factura_numero': numero.isEmpty ? null : numero,
        });
        _mostrarExito('Pago marcado como facturado');
      }
      await _cargar();
    } catch (e) {
      _mostrarError('Error al actualizar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pagos · ${widget.empresaNombre}',
            overflow: TextOverflow.ellipsis),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _resumen(),
                const Divider(height: 1),
                Expanded(
                  child: _pagos.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('Esta empresa no tiene pagos registrados',
                                  style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _cargar,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _pagos.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _cardPago(_pagos[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _resumen() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _statResumen('Total cobrado', '${_montoFmt(_totalCobrado)} UYU',
              Icons.payments, const Color(0xFF1F4E79)),
          _statResumen('Pagos aprobados', '$_cantAprobados',
              Icons.check_circle, Colors.green),
          _statResumen('Sin facturar', '$_cantSinFacturar',
              Icons.pending_actions,
              _cantSinFacturar > 0 ? Colors.orange : Colors.grey),
        ],
      ),
    );
  }

  Widget _statResumen(String label, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icono, size: 18, color: color),
            const SizedBox(height: 4),
            Text(valor,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: color),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _cardPago(Map<String, dynamic> p) {
    final estado = (p['estado'] ?? '').toString();
    final facturado = p['facturado'] == true;
    final aprobado = estado == 'approved';
    final tier = _tierPorMonto(p['monto']);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event, color: Color(0xFF1F4E79), size: 16),
                const SizedBox(width: 6),
                Text(_fechaCorta(p['fecha_pago']),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${_montoFmt(p['monto'])} ${p['moneda'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F4E79))),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _chipEstadoPago(estado),
                if (tier != '—') _chip(tier, Colors.indigo, Icons.workspace_premium),
                if (facturado)
                  _chip('Facturado', Colors.green, Icons.check_circle)
                else if (aprobado)
                  _chip('Sin facturar', Colors.orange, Icons.pending_actions),
              ],
            ),
            const SizedBox(height: 8),
            if (facturado && p['factura_numero'] != null &&
                p['factura_numero'].toString().isNotEmpty)
              _dato('Factura', p['factura_numero']),
            if (facturado && p['factura_fecha'] != null)
              _dato('Facturado el', _fechaCorta(p['factura_fecha'])),
            _dato('ID pago MP', p['mp_payment_id']),

            if (aprobado) ...[
              const SizedBox(height: 10),
              _botonAccion(
                facturado ? 'Editar facturación' : 'Marcar facturado',
                facturado ? Icons.edit : Icons.check_circle_outline,
                facturado ? const Color(0xFF1F4E79) : Colors.green,
                () => _marcarFacturado(p),
                outlined: facturado,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chipEstadoPago(String estado) {
    late Color color;
    late IconData icono;
    late String label;
    switch (estado) {
      case 'approved':
        color = Colors.green;
        icono = Icons.paid;
        label = 'Aprobado';
        break;
      case 'rejected':
        color = Colors.red;
        icono = Icons.cancel;
        label = 'Rechazado';
        break;
      case 'refunded':
        color = Colors.orange;
        icono = Icons.undo;
        label = 'Reembolsado';
        break;
      case 'charged_back':
        color = const Color(0xFFB71C1C);
        icono = Icons.gavel;
        label = 'Contracargo';
        break;
      case 'pending':
      case 'in_process':
        color = Colors.amber[800]!;
        icono = Icons.hourglass_empty;
        label = 'Pendiente';
        break;
      default:
        color = Colors.grey;
        icono = Icons.help_outline;
        label = estado.isEmpty ? '—' : estado;
    }
    return _chip(label, color, icono);
  }

  Widget _chip(String texto, Color color, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 12, color: color),
        const SizedBox(width: 4),
        Text(texto,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _botonAccion(String label, IconData icono, Color color, VoidCallback onTap,
      {bool outlined = false}) {
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton.icon(
              icon: Icon(icono, size: 16, color: color),
              label: Text(label, style: TextStyle(fontSize: 13, color: color)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onTap,
            )
          : ElevatedButton.icon(
              icon: Icon(icono, size: 16),
              label: Text(label, style: const TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onTap,
            ),
    );
  }

  Widget _dato(String label, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Expanded(
          child: Text('$valor',
              style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  String _montoFmt(dynamic monto) {
    final m = (monto as num?)?.toDouble();
    if (m == null) return '—';
    final entero = m.floor();
    final str = entero.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (mm) => '${mm[1]}.');
    return '\$$str';
  }

  String _fechaCorta(dynamic fecha) {
    if (fecha == null) return '—';
    final d = DateTime.tryParse(fecha.toString());
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}