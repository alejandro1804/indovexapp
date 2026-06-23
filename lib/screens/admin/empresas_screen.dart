import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import 'empresa_detalle_admin_screen.dart';

class EmpresasScreen extends StatefulWidget {
  const EmpresasScreen({super.key});

  @override
  State<EmpresasScreen> createState() => _EmpresasScreenState();
}

class _EmpresasScreenState extends State<EmpresasScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _empresas = [];
  bool _cargando = true;
  String _filtro = 'todas';

  final Map<String, Map<String, dynamic>> _storage = {};
  final Set<String> _cargandoStorage = {};

  String _miEmpresaId = '';

  @override
  void initState() {
    super.initState();
    final usuario = context.read<AuthProvider>().usuario;
    _miEmpresaId = usuario?.empresaId ?? '';
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await _supabase.rpc('listar_todas_empresas');
      setState(() {
        _empresas = List<Map<String, dynamic>>.from(data);
        _storage.clear();
      });
    } catch (e) {
      _mostrarError('Error al cargar empresas: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarStorage(String empresaId) async {
    if (_storage.containsKey(empresaId) || _cargandoStorage.contains(empresaId)) return;
    setState(() => _cargandoStorage.add(empresaId));
    try {
      final data = await _supabase.rpc('uso_storage_empresa', params: {'p_empresa_id': empresaId});
      if (mounted) {
        setState(() {
          _storage[empresaId] = Map<String, dynamic>.from(data);
          _cargandoStorage.remove(empresaId);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoStorage.remove(empresaId));
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

  List<Map<String, dynamic>> get _empresasFiltradas {
    if (_filtro == 'todas') return _empresas;
    return _empresas.where((e) => e['estado'] == _filtro).toList();
  }

  int? _diasTrial(dynamic trialVence) {
    if (trialVence == null) return null;
    final vence = DateTime.tryParse(trialVence.toString());
    if (vence == null) return null;
    return vence.difference(DateTime.now()).inDays;
  }

  Future<void> _aprobarEmpresa(Map<String, dynamic> empresa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar empresa'),
        content: Text(
          '¿Confirmás la aprobación de "${empresa['empresa_nombre']}"?\n\n'
          'Se crearán los roles base y el usuario admin quedará habilitado.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aprobar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      // Llama a la Edge Function que aprueba Y envía el email de bienvenida
      await _supabase.functions.invoke(
        'aprobar-empresa',
        body: {'empresa_id': empresa['empresa_id']},
      );
      _mostrarExito('Empresa aprobada correctamente');
      await _cargar();
    } catch (e) {
      _mostrarError('Error al aprobar: $e');
    }
  }

  Future<void> _suspenderEmpresa(Map<String, dynamic> empresa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspender empresa'),
        content: Text('¿Suspender "${empresa['empresa_nombre']}"? El acceso quedará bloqueado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Suspender', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _supabase.from('empresas').update({'estado': 'suspendida'}).eq('id', empresa['empresa_id']);
      _mostrarExito('Empresa suspendida');
      await _cargar();
    } catch (e) {
      _mostrarError('Error al suspender: $e');
    }
  }

  Future<void> _reactivarEmpresa(Map<String, dynamic> empresa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivar empresa'),
        content: Text('¿Reactivar "${empresa['empresa_nombre']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reactivar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _supabase.from('empresas').update({'estado': 'activa'}).eq('id', empresa['empresa_id']);
      _mostrarExito('Empresa reactivada');
      await _cargar();
    } catch (e) {
      _mostrarError('Error al reactivar: $e');
    }
  }

  Future<void> _editarLimiteStorage(Map<String, dynamic> empresa) async {
    final limite = empresa['storage_mb_limit'] ?? 500;
    final controller = TextEditingController(text: limite.toString());

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Límite de almacenamiento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Empresa: ${empresa['empresa_nombre']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Límite en MB',
                suffixText: 'MB',
                border: OutlineInputBorder(),
                helperText: 'Ej: 500 MB · 2048 = 2 GB',
              ),
            ),
          ],
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
    );

    if (confirmar != true) return;
    final nuevoLimite = int.tryParse(controller.text.trim());
    if (nuevoLimite == null || nuevoLimite <= 0) {
      _mostrarError('Ingresá un número válido mayor a 0');
      return;
    }
    try {
      await _supabase
          .from('empresas')
          .update({'storage_mb_limit': nuevoLimite})
          .eq('id', empresa['empresa_id']);
      _mostrarExito('Límite actualizado a $nuevoLimite MB');
      _storage.remove(empresa['empresa_id'].toString());
      await _cargar();
    } catch (e) {
      _mostrarError('Error al actualizar límite: $e');
    }
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
                            padding: const EdgeInsets.all(12),
                            itemCount: _empresasFiltradas.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _cardEmpresa(_empresasFiltradas[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _barraFiltros() {
    final filtros = {
      'todas': 'Todas',
      'activa': 'Activas',
      'pendiente': 'Pendientes',
      'suspendida': 'Suspendidas',
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

  Widget _cardEmpresa(Map<String, dynamic> e) {
    final estado = (e['estado'] ?? '').toString();
    final empresaId = e['empresa_id'].toString();
    final esMiEmpresa = empresaId == _miEmpresaId;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        onExpansionChanged: (expanded) {
          if (expanded) _cargarStorage(empresaId);
        },
        title: Row(
          children: [
            const Icon(Icons.business, color: Color(0xFF1F4E79), size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                e['empresa_nombre'] ?? 'Sin nombre',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (esMiEmpresa)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F4E79).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1F4E79).withOpacity(0.3)),
                ),
                child: const Text('Mi empresa',
                    style: TextStyle(
                        fontSize: 9, color: Color(0xFF1F4E79), fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _chipEstado(e['estado']),
              _chipPago(e),
            ],
          ),
        ),
        children: [
          const Divider(height: 12),

          if (e['rut'] != null && e['rut'].toString().isNotEmpty)
            _dato('RUT', e['rut']),
          if (e['email_contacto'] != null && e['email_contacto'].toString().isNotEmpty)
            _dato('Email', e['email_contacto']),
          _dato('Registrada', _fechaCorta(e['created_at'])),

          const SizedBox(height: 10),
          _seccionStorage(empresaId, e),
          const SizedBox(height: 10),

          // ── Ver empresa (siempre visible si está activa o suspendida) ──
          if (estado == 'activa' || estado == 'suspendida') ...[
            _botonAccion(
              'Ver empresa',
              Icons.open_in_new,
              const Color(0xFF1F4E79),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmpresaDetalleAdminScreen(
                    empresaId: empresaId,
                    empresaNombre: e['empresa_nombre'] ?? '',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],

          // ── Aprobar ──
          if (estado == 'pendiente')
            _botonAccion('Aprobar empresa', Icons.check_circle_outline, Colors.green,
                () => _aprobarEmpresa(e)),

          // ── Suspender (no disponible para mi empresa) ──
          if (estado == 'activa' && !esMiEmpresa) ...[
            const SizedBox(height: 6),
            _botonAccion('Suspender', Icons.block, Colors.red,
                () => _suspenderEmpresa(e), outlined: true),
          ],

          if (estado == 'activa' && esMiEmpresa) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Esta es tu empresa — no puede suspenderse',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ),
              ]),
            ),
          ],

          // ── Reactivar ──
          if (estado == 'suspendida') ...[
            const SizedBox(height: 6),
            _botonAccion('Reactivar', Icons.restart_alt, Colors.green,
                () => _reactivarEmpresa(e)),
          ],
        ],
      ),
    );
  }

  Widget _seccionStorage(String empresaId, Map<String, dynamic> empresa) {
    final cargando = _cargandoStorage.contains(empresaId);
    final datos = _storage[empresaId];
    final limiteActual = empresa['storage_mb_limit'] ?? 500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.storage, size: 13, color: Colors.grey),
          const SizedBox(width: 4),
          const Text('Almacenamiento',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: () => _editarLimiteStorage(empresa),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.edit, size: 11, color: Color(0xFF1F4E79)),
            const SizedBox(width: 3),
            Text('Límite: $limiteActual MB — tocá para editar',
                style: const TextStyle(fontSize: 11, color: Color(0xFF1F4E79))),
          ]),
        ),
        const SizedBox(height: 8),
        if (cargando)
          const LinearProgressIndicator()
        else if (datos == null)
          Text('Expandí para cargar', style: TextStyle(fontSize: 11, color: Colors.grey[400]))
        else ...[
          _barraStorage(datos),
          const SizedBox(height: 6),
          _desgloseStorage(datos),
        ],
      ],
    );
  }

  Widget _barraStorage(Map<String, dynamic> datos) {
    final usado = (datos['usado_mb'] as num).toDouble();
    final limite = (datos['limite_mb'] as num).toDouble();
    final porcentaje = (datos['porcentaje'] as num? ?? 0).toDouble();
    final progreso = (porcentaje / 100).clamp(0.0, 1.0);

    Color color;
    if (porcentaje >= 90) {
      color = Colors.red;
    } else if (porcentaje >= 70) {
      color = Colors.orange;
    } else {
      color = Colors.teal;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progreso,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 7,
        ),
      ),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${usado.toStringAsFixed(1)} MB usados',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        Text('${porcentaje.toStringAsFixed(1)}% / $limite MB',
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    ]);
  }

  Widget _desgloseStorage(Map<String, dynamic> datos) {
    final desglose = datos['desglose'] as Map<String, dynamic>;
    final items = [
      ('Máquinas', desglose['maquina']),
      ('Repuestos', desglose['repuesto']),
      ('Tickets', desglose['ticket']),
    ];
    return Row(
      children: items.map((item) {
        final mb = (item.$2 as num? ?? 0).toDouble();
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.$1, style: const TextStyle(fontSize: 9, color: Colors.grey)),
              Text('${mb.toStringAsFixed(1)} MB',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
        );
      }).toList(),
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

  Widget _chipPago(Map<String, dynamic> e) {
    final tieneSuscripcion = e['tiene_suscripcion'] == true;
    if (tieneSuscripcion) return _chip('Pago activo', Colors.blue, Icons.paid);
    final dias = _diasTrial(e['trial_vence']);
    if (dias == null) return _chip('Sin plan', Colors.grey, Icons.help_outline);
    if (dias < 0) return _chip('Trial vencido', Colors.red, Icons.timer_off);
    return _chip('Trial · $dias días', Colors.teal, Icons.schedule);
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

  String _fechaCorta(dynamic fecha) {
    if (fecha == null) return '—';
    final d = DateTime.tryParse(fecha.toString());
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
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
}