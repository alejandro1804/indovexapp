import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GestionPlanesScreen extends StatefulWidget {
  const GestionPlanesScreen({super.key});

  @override
  State<GestionPlanesScreen> createState() => _GestionPlanesScreenState();
}

class _GestionPlanesScreenState extends State<GestionPlanesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _planes = [];
  bool _cargando = true;

  // Límites por tier. Espejo de fn_limites_plan() en la base.
  // Se muestran como referencia: no son editables acá porque la
  // fuente de verdad es la función SQL.
  static const _limitesPorTier = {
    'starter': {'usuarios': 10, 'maquinas': 50, 'storage': 200},
    'pro': {'usuarios': 20, 'maquinas': 200, 'storage': 800},
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (mounted) setState(() => _cargando = true);
    try {
      final data = await _supabase.from('planes').select().order('orden');
      if (!mounted) return;
      setState(() => _planes = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      _mostrarError('Error al cargar planes: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
  }

  void _mostrarExito(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating));
  }

  Future<void> _formularioPlan({Map<String, dynamic>? plan}) async {
    final esNuevo = plan == null;
    final nombreCtrl = TextEditingController(text: plan?['nombre'] ?? '');
    final descCtrl = TextEditingController(text: plan?['descripcion'] ?? '');
    final precioCtrl = TextEditingController(
        text: plan != null ? (plan['precio'] as num).toString() : '');
    final mpCtrl = TextEditingController(text: plan?['mp_plan_id'] ?? '');
    String ciclo = plan?['ciclo'] ?? 'mensual';
    String tier = plan?['tier'] ?? 'starter';

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(esNuevo ? 'Nuevo plan' : 'Editar plan'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nombre *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                    labelText: 'Descripción', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: tier,
                decoration: const InputDecoration(
                  labelText: 'Tier *',
                  border: OutlineInputBorder(),
                  helperText: 'Define los límites de uso de la empresa',
                ),
                items: const [
                  DropdownMenuItem(value: 'starter', child: Text('Starter')),
                  DropdownMenuItem(value: 'pro', child: Text('Pro')),
                ],
                onChanged: (v) => setD(() => tier = v!),
              ),
              const SizedBox(height: 8),
              _resumenLimites(tier),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: ciclo,
                decoration: const InputDecoration(
                    labelText: 'Ciclo *', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                  DropdownMenuItem(value: 'anual', child: Text('Anual')),
                ],
                onChanged: (v) => setD(() => ciclo = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precioCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Precio (UYU) *',
                    border: OutlineInputBorder(),
                    prefixText: '\$ '),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mpCtrl,
                decoration: const InputDecoration(
                    labelText: 'MercadoPago Plan ID',
                    border: OutlineInputBorder(),
                    helperText: 'Sin este ID, el plan no se puede contratar'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (guardar != true) return;

    final nombre = nombreCtrl.text.trim();
    final precio = double.tryParse(precioCtrl.text.trim());

    if (nombre.isEmpty || precio == null) {
      _mostrarError('Completá nombre y precio con valores válidos');
      return;
    }

    final datos = {
      'nombre': nombre,
      'descripcion': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      'precio': precio,
      'ciclo': ciclo,
      'tier': tier,
      'mp_plan_id': mpCtrl.text.trim().isEmpty ? null : mpCtrl.text.trim(),
    };

    try {
      if (esNuevo) {
        datos['orden'] = _planes.length + 1;
        await _supabase.from('planes').insert(datos);
        _mostrarExito('Plan creado');
      } else {
        await _supabase.from('planes').update(datos).eq('id', plan['id']);
        _mostrarExito('Plan actualizado');
      }
      await _cargar();
    } catch (e) {
      // El índice único impide dos planes activos con el mismo tier+ciclo
      final msg = e.toString().contains('uq_planes_tier_ciclo_activo')
          ? 'Ya existe un plan activo para ese tier y ciclo'
          : 'Error al guardar: $e';
      _mostrarError(msg);
    }
  }

  /// Muestra los límites que el tier aplica. Solo informativo:
  /// los valores reales viven en fn_limites_plan() en la base.
  Widget _resumenLimites(String tier) {
    final lim = _limitesPorTier[tier];
    if (lim == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${lim['maquinas']} activos · ${lim['usuarios']} usuarios · ${lim['storage']} MB',
            style: TextStyle(fontSize: 11, color: Colors.blue[900]),
          ),
        ),
      ]),
    );
  }

  Future<void> _toggleActivo(Map<String, dynamic> plan) async {
    try {
      await _supabase
          .from('planes')
          .update({'activo': !(plan['activo'] as bool)})
          .eq('id', plan['id']);
      await _cargar();
    } catch (e) {
      final msg = e.toString().contains('uq_planes_tier_ciclo_activo')
          ? 'Ya hay otro plan activo para ese tier y ciclo'
          : 'Error: $e';
      _mostrarError(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planes'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _planes.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(Icons.sell_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No hay planes definidos',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                    ]),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _planes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _cardPlan(_planes[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _formularioPlan(),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _cardPlan(Map<String, dynamic> p) {
    final activo = p['activo'] as bool;
    final precio = (p['precio'] as num).toStringAsFixed(0);
    final ciclo = p['ciclo'] as String;
    final tier = p['tier'] as String? ?? '';
    final tieneMp = (p['mp_plan_id'] as String?)?.isNotEmpty == true;
    final lim = _limitesPorTier[tier];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: activo
                ? const Color(0xFF1F4E79).withOpacity(0.3)
                : Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(p['nombre'] ?? '',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: activo ? Colors.black87 : Colors.grey)),
            ),
            Switch(
              value: activo,
              activeColor: const Color(0xFF1F4E79),
              onChanged: (_) => _toggleActivo(p),
            ),
          ]),
          if (p['descripcion'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(p['descripcion'],
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
          const SizedBox(height: 4),
          Row(children: [
            Text('\$$precio',
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F4E79))),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('/ $ciclo',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _chip(Icons.layers, tier.toUpperCase(), const Color(0xFF1F4E79)),
            if (lim != null) ...[
              _chip(Icons.precision_manufacturing, '${lim['maquinas']} act', Colors.blueGrey),
              _chip(Icons.people_outline, '${lim['usuarios']} usr', Colors.blueGrey),
              _chip(Icons.storage, '${lim['storage']} MB', Colors.teal),
            ],
            tieneMp
                ? _chip(Icons.link, 'MercadoPago OK', Colors.green)
                : _chip(Icons.link_off, 'Sin MP Plan ID', Colors.orange),
          ]),
          if (!tieneMp)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Este plan no se puede contratar hasta cargar su ID de MercadoPago.',
                style: TextStyle(fontSize: 11, color: Colors.orange[800]),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Editar plan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1F4E79),
                side: const BorderSide(color: Color(0xFF1F4E79)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _formularioPlan(plan: p),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(IconData icono, String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 13, color: color),
        const SizedBox(width: 4),
        Text(texto,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}