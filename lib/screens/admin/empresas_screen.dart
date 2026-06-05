import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmpresasScreen extends StatefulWidget {
  const EmpresasScreen({super.key});

  @override
  State<EmpresasScreen> createState() => _EmpresasScreenState();
}

class _EmpresasScreenState extends State<EmpresasScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _empresas = [];
  bool _cargando = true;

  // Filtro activo: 'todas' | 'activa' | 'pendiente' | 'suspendida'
  String _filtro = 'todas';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await _supabase.rpc('listar_todas_empresas');
      setState(() {
        _empresas = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      _mostrarError('Error al cargar empresas: $e');
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

  // Empresas filtradas según el filtro activo
  List<Map<String, dynamic>> get _empresasFiltradas {
    if (_filtro == 'todas') return _empresas;
    return _empresas.where((e) => e['estado'] == _filtro).toList();
  }

  // Calcula los días restantes de trial (puede ser negativo si venció)
  int? _diasTrial(dynamic trialVence) {
    if (trialVence == null) return null;
    final vence = DateTime.tryParse(trialVence.toString());
    if (vence == null) return null;
    return vence.difference(DateTime.now()).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Empresas'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _barraFiltros(),
                const Divider(height: 1),
                Expanded(
                  child: _empresasFiltradas.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.business_outlined, size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('No hay empresas en esta vista',
                                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _cargar,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _empresasFiltradas.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _cardEmpresa(_empresasFiltradas[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  // ── Barra de filtros ──────────────────────────────────────
  Widget _barraFiltros() {
    final filtros = {
      'todas': 'Todas',
      'activa': 'Activas',
      'pendiente': 'Pendientes',
      'suspendida': 'Suspendidas',
    };
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filtros.entries.map((f) {
            final activo = _filtro == f.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.value),
                selected: activo,
                onSelected: (_) => setState(() => _filtro = f.key),
                selectedColor: const Color(0xFF1F4E79),
                labelStyle: TextStyle(
                  color: activo ? Colors.white : Colors.black87,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Card de empresa ───────────────────────────────────────
  Widget _cardEmpresa(Map<String, dynamic> e) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business, color: Color(0xFF1F4E79)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e['empresa_nombre'] ?? 'Sin nombre',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Chips de estado y pago
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chipEstado(e['estado']),
                _chipPago(e),
              ],
            ),
            const Divider(height: 20),

            if (e['rut'] != null && e['rut'].toString().isNotEmpty)
              _dato('RUT', e['rut']),
            if (e['email_contacto'] != null && e['email_contacto'].toString().isNotEmpty)
              _dato('Email', e['email_contacto']),
            _dato('Registrada', _fechaCorta(e['created_at'])),
          ],
        ),
      ),
    );
  }

  // ── Chip de estado (activa / pendiente / suspendida) ──────
  Widget _chipEstado(dynamic estado) {
    final e = (estado ?? '').toString();
    late Color color;
    late IconData icono;
    switch (e) {
      case 'activa':
        color = Colors.green;
        icono = Icons.check_circle;
        break;
      case 'pendiente':
        color = Colors.orange;
        icono = Icons.hourglass_empty;
        break;
      case 'suspendida':
        color = Colors.red;
        icono = Icons.block;
        break;
      default:
        color = Colors.grey;
        icono = Icons.help_outline;
    }
    return _chip(e.isEmpty ? '—' : e, color, icono);
  }

  // ── Chip de pago (pago / trial / trial vencido) ───────────
  Widget _chipPago(Map<String, dynamic> e) {
    final tieneSuscripcion = e['tiene_suscripcion'] == true;
    if (tieneSuscripcion) {
      return _chip('Pago activo', Colors.blue, Icons.paid);
    }

    final dias = _diasTrial(e['trial_vence']);
    if (dias == null) {
      return _chip('Sin plan', Colors.grey, Icons.help_outline);
    }
    if (dias < 0) {
      return _chip('Trial vencido', Colors.red, Icons.timer_off);
    }
    return _chip('Trial · $dias días', Colors.teal, Icons.schedule);
  }

  Widget _chip(String texto, Color color, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 5),
          Text(texto,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _fechaCorta(dynamic fecha) {
    if (fecha == null) return '—';
    final d = DateTime.tryParse(fecha.toString());
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Widget _dato(String label, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Expanded(child: Text('$valor', style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}