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
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  void _mostrarExito(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
  }

  Future<void> _formularioPlan({Map<String, dynamic>? plan}) async {
    final esNuevo = plan == null;
    final nombreCtrl = TextEditingController(text: plan?['nombre'] ?? '');
    final descCtrl = TextEditingController(text: plan?['descripcion'] ?? '');
    final precioCtrl = TextEditingController(
        text: plan != null ? (plan['precio'] as num).toString() : '');
    final storageCtrl = TextEditingController(
        text: plan != null ? plan['storage_mb_limit'].toString() : '500');
    final mpCtrl = TextEditingController(text: plan?['mp_plan_id'] ?? '');
    String ciclo = plan?['ciclo'] ?? 'mensual';

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(esNuevo ? 'Nuevo plan' : 'Editar plan'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precioCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Precio (UYU) *', border: OutlineInputBorder(), prefixText: '\$ '),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: ciclo,
                decoration: const InputDecoration(labelText: 'Ciclo *', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                  DropdownMenuItem(value: 'anual', child: Text('Anual')),
                ],
                onChanged: (v) => setD(() => ciclo = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: storageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Almacenamiento (MB) *', border: OutlineInputBorder(), suffixText: 'MB'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mpCtrl,
                decoration: const InputDecoration(
                    labelText: 'MercadoPago Plan ID',
                    border: OutlineInputBorder(),
                    helperText: 'ID del plan en MercadoPago'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79)),
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
    final storage = int.tryParse(storageCtrl.text.trim());

    if (nombre.isEmpty || precio == null || storage == null) {
      _mostrarError('Completá nombre, precio y almacenamiento con valores válidos');
      return;
    }

    final datos = {
      'nombre': nombre,
      'descripcion': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      'precio': precio,
      'ciclo': ciclo,
      'storage_mb_limit': storage,
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
      _mostrarError('Error al guardar: $e');
    }
  }

  Future<void> _toggleActivo(Map<String, dynamic> plan) async {
    try {
      await _supabase
          .from('planes')
          .update({'activo': !(plan['activo'] as bool)})
          .eq('id', plan['id']);
      await _cargar();
    } catch (e) {
      _mostrarError('Error: $e');
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
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
    final tieneMp = (p['mp_plan_id'] as String?)?.isNotEmpty == true;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
            color: activo ? const Color(0xFF1F4E79).withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
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
            // Estado activo/inactivo
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
                    fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79))),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('/ $ciclo', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _chip(Icons.storage, '${p['storage_mb_limit']} MB', Colors.teal),
            tieneMp
                ? _chip(Icons.link, 'MercadoPago OK', Colors.green)
                : _chip(Icons.link_off, 'Sin MP Plan ID', Colors.orange),
          ]),
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
        Text(texto, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}