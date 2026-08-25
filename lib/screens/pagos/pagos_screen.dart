import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _pagos = [];
  bool _cargando = true;
  String _filtro = 'por_facturar';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await _supabase.rpc('sa_listar_pagos');
      setState(() {
        _pagos = List<Map<String, dynamic>>.from(data);
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

  List<Map<String, dynamic>> get _pagosFiltrados {
    switch (_filtro) {
      case 'por_facturar':
        return _pagos
            .where((p) => p['estado'] == 'approved' && p['facturado'] != true)
            .toList();
      case 'facturados':
        return _pagos.where((p) => p['facturado'] == true).toList();
      case 'rechazados':
        return _pagos.where((p) => p['estado'] != 'approved').toList();
      case 'todos':
      default:
        return _pagos;
    }
  }

  // Deriva el tier a partir del monto cobrado (empresas.plan no lo distingue).
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

    if (resultado == null) return; // canceló

    try {
      if (resultado == false) {
        // Desmarcar
        await _supabase.rpc('marcar_pago_facturado', params: {
          'p_pago_id': pago['pago_id'],
          'p_facturado': false,
        });
        _mostrarExito('Pago desmarcado');
      } else {
        // Marcar (con número opcional)
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
    final pendientes = _pagos
        .where((p) => p['estado'] == 'approved' && p['facturado'] != true)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagos'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        actions: [
          if (pendientes > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$pendientes por facturar',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _barraFiltros(),
                const Divider(height: 1),
                Expanded(
                  child: _pagosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('No hay pagos en esta vista',
                                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _cargar,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _pagosFiltrados.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _cardPago(_pagosFiltrados[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _barraFiltros() {
    final filtros = {
      'por_facturar': 'Por facturar',
      'facturados': 'Facturados',
      'rechazados': 'Rechazados',
      'todos': 'Todos',
    };
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filtros.entries.map((f) {
            final activo = _filtro == f.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.value, style: const TextStyle(fontSize: 12)),
                selected: activo,
                onSelected: (_) => setState(() => _filtro = f.key),
                selectedColor: const Color(0xFF1F4E79),
                labelStyle: TextStyle(
                  color: activo ? Colors.white : Colors.black87,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
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
            // Encabezado: empresa + monto
            Row(
              children: [
                const Icon(Icons.business, color: Color(0xFF1F4E79), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    p['empresa_nombre'] ?? 'Sin nombre',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${_montoFmt(p['monto'])} ${p['moneda'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F4E79)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Chips: estado del pago, tier, facturado
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

            _dato('Fecha del cobro', _fechaCorta(p['fecha_pago'])),
            if (facturado && p['factura_numero'] != null &&
                p['factura_numero'].toString().isNotEmpty)
              _dato('Factura', p['factura_numero']),
            if (facturado && p['factura_fecha'] != null)
              _dato('Facturado el', _fechaCorta(p['factura_fecha'])),
            _dato('ID pago MP', p['mp_payment_id']),

            // Acción: solo para pagos aprobados (los rechazados no se facturan)
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