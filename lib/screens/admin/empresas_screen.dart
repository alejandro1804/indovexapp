import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../services/export_empresa_service.dart';
import 'empresa_detalle_admin_screen.dart';
import '../pagos/pagos_empresa_screen.dart';

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

  // Días que faltan para que la purga quede habilitada. Negativo = ya vencido.
  int? _diasParaPurga(dynamic fechaPurga) {
    if (fechaPurga == null) return null;
    final fecha = DateTime.tryParse(fechaPurga.toString());
    if (fecha == null) return null;
    final hoy = DateTime.now();
    return DateTime(fecha.year, fecha.month, fecha.day)
        .difference(DateTime(hoy.year, hoy.month, hoy.day))
        .inDays;
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

  // ── SITUACIÓN 2: suspender por falta de pago (vía RPC, activa plazos) ──
  Future<void> _suspenderEmpresa(Map<String, dynamic> empresa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspender empresa'),
        content: Text(
          '¿Suspender "${empresa['empresa_nombre']}"?\n\n'
          'El acceso quedará bloqueado, pero los datos se conservan. '
          'Si no se reactiva, quedará habilitada para purga al vencer el plazo de conservación.',
        ),
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
      await _supabase.rpc('sa_suspender_empresa',
          params: {'p_empresa_id': empresa['empresa_id']});
      _mostrarExito('Empresa suspendida');
      await _cargar();
    } catch (e) {
      _mostrarError('Error al suspender: $e');
    }
  }

  // ── SITUACIÓN 1: baja voluntaria (vía RPC) ──
  Future<void> _darDeBajaEmpresa(Map<String, dynamic> empresa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dar de baja (voluntaria)'),
        content: Text(
          '¿Iniciar la baja voluntaria de "${empresa['empresa_nombre']}"?\n\n'
          'El acceso se bloquea y comienza el plazo para exportar sus datos. '
          'Recordá generar y entregar el backup antes de purgar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A4C93)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dar de baja', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _supabase.rpc('sa_solicitar_baja',
          params: {'p_empresa_id': empresa['empresa_id']});
      _mostrarExito('Baja iniciada');
      await _cargar();
    } catch (e) {
      _mostrarError('Error al dar de baja: $e');
    }
  }

  // ── Reactivar (vía RPC, limpia plazos) ──
  Future<void> _reactivarEmpresa(Map<String, dynamic> empresa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivar empresa'),
        content: Text('¿Reactivar "${empresa['empresa_nombre']}"? Se restablece el acceso y se cancelan los plazos de purga.'),
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
      await _supabase.rpc('sa_reactivar_empresa',
          params: {'p_empresa_id': empresa['empresa_id']});
      _mostrarExito('Empresa reactivada');
      await _cargar();
    } catch (e) {
      _mostrarError('Error al reactivar: $e');
    }
  }

  // ── Gestión de plazos configurables ──
  Future<void> _gestionarPlazos() async {
    List<Map<String, dynamic>> plazos = [];
    try {
      final data = await _supabase.rpc('get_config_plazos');
      plazos = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      _mostrarError('Error al cargar plazos: $e');
      return;
    }

    final controllers = {
      for (final p in plazos)
        p['clave'].toString(): TextEditingController(text: p['dias'].toString())
    };

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Plazos de conservación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in plazos) ...[
              Text(p['descripcion'] ?? p['clave'],
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 4),
              TextField(
                controller: controllers[p['clave'].toString()],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  suffixText: 'días',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
            ],
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

    if (guardar != true) return;
    try {
      for (final p in plazos) {
        final clave = p['clave'].toString();
        final nuevo = int.tryParse(controllers[clave]!.text.trim());
        if (nuevo == null || nuevo < 0) continue;
        if (nuevo != p['dias']) {
          await _supabase.rpc('set_config_plazo',
              params: {'p_clave': clave, 'p_dias': nuevo});
        }
      }
      _mostrarExito('Plazos actualizados');
    } catch (e) {
      _mostrarError('Error al guardar plazos: $e');
    }
  }

  // ── Export de datos (portabilidad / baja voluntaria) ──
  Future<void> _exportarDatos(Map<String, dynamic> empresa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exportar datos'),
        content: Text(
          'Se generará un archivo ZIP con todos los registros de '
          '"${empresa['empresa_nombre']}" (tickets, activos, repuestos, '
          'auditoría, etc.) en formato CSV, más los enlaces de descarga de '
          'sus archivos adjuntos (válidos 5 días).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exportar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final servicio = ExportEmpresaService(_supabase);
      final archivos = await servicio.exportar(
        empresaId: empresa['empresa_id'].toString(),
        empresaNombre: empresa['empresa_nombre'] ?? 'empresa',
      );
      if (mounted) Navigator.pop(context); // cerrar spinner
      _mostrarExito('Export generado — $archivos archivo(s) incluido(s)');
    } catch (e) {
      if (mounted) Navigator.pop(context); // cerrar spinner
      _mostrarError('Error al exportar: $e');
    }
  }

  // ── Purga definitiva (IRREVERSIBLE) — doble confirmación por nombre ──
  Future<void> _purgarEmpresa(Map<String, dynamic> empresa) async {
    final nombre = (empresa['empresa_nombre'] ?? '').toString();
    final controller = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final coincide = controller.text.trim() == nombre;
          return AlertDialog(
            // FIX: sin esto, cuando el teclado se abre (por el TextField de
            // confirmación) el contenido no puede achicarse ni scrollear y
            // se desborda, superponiendo los botones con el texto.
            scrollable: true,
            title: Row(children: const [
              Icon(Icons.warning_amber, color: Color(0xFFB71C1C)),
              SizedBox(width: 8),
              Text('Purga definitiva'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vas a ELIMINAR de forma permanente e irreversible todos los '
                  'datos y archivos de "$nombre".\n\n'
                  'Los registros de auditoría se conservarán anonimizados. '
                  'Esta acción NO se puede deshacer.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text('Para confirmar, escribí el nombre exacto de la empresa:',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  onChanged: (_) => setLocal(() {}),
                  decoration: InputDecoration(
                    hintText: nombre,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB71C1C),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                onPressed: coincide ? () => Navigator.pop(ctx, true) : null,
                child: const Text('Purgar definitivamente',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );

    if (confirmar != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await _supabase.functions.invoke(
        'purgar-empresa',
        body: {'empresa_id': empresa['empresa_id']},
      );
      if (mounted) Navigator.pop(context); // cerrar spinner

      final data = res.data as Map<String, dynamic>?;
      if (data != null && data['ok'] == true) {
        _mostrarExito('Empresa "$nombre" purgada definitivamente');
        await _cargar();
      } else {
        final err = data?['error'] ?? 'Respuesta inesperada';
        _mostrarError('Error al purgar: $err');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // cerrar spinner
      _mostrarError('Error al purgar: $e');
    }
  }

  Future<void> _editarLimiteStorage(Map<String, dynamic> empresa) async {
    final limite = empresa['storage_mb_limit'] ?? 500;
    final controller = TextEditingController(text: limite.toString());

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.timer_outlined),
            tooltip: 'Plazos de conservación',
            onPressed: _gestionarPlazos,
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
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
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
      'en_baja': 'En baja',
      'a_purgar': 'A purgar',
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
    final puedeVerDetalle =
        estado == 'activa' || estado == 'suspendida' || estado == 'en_baja' || estado == 'a_purgar';

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
                  color: const Color(0xFF1F4E79).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1F4E79).withValues(alpha: 0.3)),
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

          // Aviso de plazo de purga (suspendida o en_baja)
          if (estado == 'suspendida' || estado == 'en_baja' || estado == 'a_purgar')
            _avisoPurga(e, estado),

          const SizedBox(height: 10),
          _seccionStorage(empresaId, e),
          const SizedBox(height: 10),

          // ── Ver empresa ──
          if (puedeVerDetalle) ...[
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

          // ── Ver pagos (historial de la empresa) ──
          _botonAccion(
            'Ver pagos',
            Icons.receipt_long,
            const Color(0xFF1F4E79),
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PagosEmpresaScreen(
                  empresaId: empresaId,
                  empresaNombre: e['empresa_nombre'] ?? '',
                ),
              ),
            ),
            outlined: true,
          ),
          const SizedBox(height: 6),

          // ── Aprobar ──
          if (estado == 'pendiente')
            _botonAccion('Aprobar empresa', Icons.check_circle_outline, Colors.green,
                () => _aprobarEmpresa(e)),

          // ── Acciones para empresa ACTIVA (no mi empresa) ──
          if (estado == 'activa' && !esMiEmpresa) ...[
            const SizedBox(height: 6),
            _botonAccion('Suspender', Icons.block, Colors.red,
                () => _suspenderEmpresa(e), outlined: true),
            const SizedBox(height: 6),
            _botonAccion('Dar de baja', Icons.logout, const Color(0xFF6A4C93),
                () => _darDeBajaEmpresa(e), outlined: true),
            const SizedBox(height: 6),
            _botonAccion('Exportar datos', Icons.download, const Color(0xFF1F4E79),
                () => _exportarDatos(e), outlined: true),
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
                  child: Text('Esta es tu empresa — no puede suspenderse ni darse de baja',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ),
              ]),
            ),
          ],

          // ── Exportar disponible en suspendida / en_baja / a_purgar ──
          if (estado == 'suspendida' || estado == 'en_baja' || estado == 'a_purgar') ...[
            const SizedBox(height: 6),
            _botonAccion('Exportar datos', Icons.download, const Color(0xFF1F4E79),
                () => _exportarDatos(e), outlined: true),
          ],

          // ── Reactivar (desde suspendida, en_baja o a_purgar) ──
          if (estado == 'suspendida' || estado == 'en_baja' || estado == 'a_purgar') ...[
            const SizedBox(height: 6),
            _botonAccion('Reactivar', Icons.restart_alt, Colors.green,
                () => _reactivarEmpresa(e)),
          ],

          // ── Purgar definitivamente (IRREVERSIBLE) ──
          // Solo disponible cuando el plazo de conservación venció y el cron
          // (fn_marcar_empresas_a_purgar) pasó la empresa a estado 'a_purgar'.
          // El RPC sa_purgar_datos_empresa además valida este estado del lado
          // del servidor, así que aunque el botón no aparezca, la regla es firme.
          if (estado == 'a_purgar') ...[
            const SizedBox(height: 6),
            _botonAccion('Purgar definitivamente', Icons.delete_forever,
                const Color(0xFFB71C1C), () => _purgarEmpresa(e), outlined: true),
          ],
        ],
      ),
    );
  }

  Widget _avisoPurga(Map<String, dynamic> e, String estado) {
    final dias = _diasParaPurga(e['fecha_purga_programada']);
    if (dias == null) return const SizedBox.shrink();

    final vencido = dias <= 0;
    final color = vencido ? const Color(0xFFB71C1C) : Colors.orange[800]!;
    final texto = vencido
        ? '⚠ Plazo cumplido — purga habilitada'
        : 'Purga disponible en $dias día${dias != 1 ? 's' : ''}';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(vencido ? Icons.warning_amber : Icons.schedule, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(texto,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ),
      ]),
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
      ('Activos', desglose['maquina']),
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
    late String label;
    switch (e) {
      case 'activa':
        color = Colors.green;
        icono = Icons.check_circle;
        label = 'activa';
        break;
      case 'pendiente':
        color = Colors.orange;
        icono = Icons.hourglass_empty;
        label = 'pendiente';
        break;
      case 'suspendida':
        color = Colors.red;
        icono = Icons.block;
        label = 'suspendida';
        break;
      case 'en_baja':
        color = const Color(0xFF6A4C93);
        icono = Icons.logout;
        label = 'en baja';
        break;
      case 'a_purgar':
        color = const Color(0xFFB71C1C);
        icono = Icons.warning_amber;
        label = 'a purgar';
        break;
      default:
        color = Colors.grey;
        icono = Icons.help_outline;
        label = e.isEmpty ? '—' : e;
    }
    return _chip(label, color, icono);
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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