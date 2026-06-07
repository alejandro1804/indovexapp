import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class PlanesScreen extends StatefulWidget {
  final bool bloqueante;

  const PlanesScreen({super.key, this.bloqueante = false});

  @override
  State<PlanesScreen> createState() => _PlanesScreenState();
}

class _PlanesScreenState extends State<PlanesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _planes = [];
  bool _cargandoPlanes = true;
  bool _procesando = false;
  String? _planProcesando;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPlanes();
  }

  Future<void> _cargarPlanes() async {
    if (mounted) setState(() => _cargandoPlanes = true);
    try {
      final data = await _supabase
          .from('planes')
          .select()
          .eq('activo', true)
          .order('orden');
      if (!mounted) return;
      setState(() => _planes = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudieron cargar los planes.');
    } finally {
      if (mounted) setState(() => _cargandoPlanes = false);
    }
  }

  Future<void> _suscribirse(Map<String, dynamic> plan) async {
    setState(() {
      _procesando = true;
      _planProcesando = plan['id'].toString();
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final usuario = authProvider.usuario;
      if (usuario == null) return;

      final supabase = authProvider.supabase;

      final response = await supabase.functions.invoke(
        'crear-suscripcion',
        body: {
          'empresa_id': usuario.empresaId,
          'plan': plan['ciclo'],       // 'mensual' | 'anual'
          'plan_id': plan['id'],       // por si la Edge Function lo usa
        },
      );

      if (response.data == null || response.data['link'] == null) {
        setState(() => _error = 'No se pudo generar el link de pago.');
        return;
      }

      final link = response.data['link'] as String;
      final uri = Uri.parse(link);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        setState(() => _error = 'No se pudo abrir el link de pago.');
      }
    } catch (e) {
      setState(() => _error = 'Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _procesando = false;
          _planProcesando = null;
        });
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // Formatea 1500 -> $1.500
  String _formatPrecio(num precio) {
    final entero = precio.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) buffer.write('.');
      buffer.write(entero[i]);
    }
    return '\$${buffer.toString()}';
  }

  String _periodoLabel(String ciclo) {
    return ciclo == 'anual' ? 'por año' : 'por mes';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final dias = authProvider.diasRestantesTrial;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: widget.bloqueante
          ? AppBar(
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
              title: const Text('Indovex', style: TextStyle(fontWeight: FontWeight.bold)),
              automaticallyImplyLeading: false,
              actions: [
                TextButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                  label: const Text('Salir', style: TextStyle(color: Colors.white70)),
                ),
              ],
            )
          : AppBar(
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
              title: const Text('Planes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: _cargandoPlanes
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  // Mensaje trial
                  if (widget.bloqueante)
                    _aviso(
                      Colors.red,
                      Icons.lock_outline,
                      'Tu período de prueba ha vencido. Elegí un plan para seguir usando Indovex.',
                    )
                  else
                    _aviso(
                      Colors.orange,
                      Icons.warning_amber_rounded,
                      dias == 0
                          ? 'Tu período de prueba vence hoy.'
                          : 'Te quedan $dias día${dias == 1 ? '' : 's'} de prueba.',
                    ),

                  const SizedBox(height: 32),
                  const Text(
                    'Elegí tu plan',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todos los planes incluyen acceso completo a Indovex',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Planes dinámicos
                  if (_planes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No hay planes disponibles en este momento.',
                          style: TextStyle(color: Colors.grey[600])),
                    )
                  else
                    ..._planes.map((plan) {
                      // El plan anual se marca como destacado
                      final destacado = plan['ciclo'] == 'anual';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildTarjetaPlan(plan, destacado),
                      );
                    }),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
                    ),
                  ],

                  const SizedBox(height: 32),
                  Text(
                    'Los pagos se procesan de forma segura a través de MercadoPago.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _aviso(MaterialColor color, IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[200]!),
      ),
      child: Row(
        children: [
          Icon(icono, color: color[700], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto, style: TextStyle(color: color[700], fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaPlan(Map<String, dynamic> plan, bool destacado) {
    final titulo = plan['nombre'] as String? ?? 'Plan';
    final precio = _formatPrecio(plan['precio'] as num);
    final periodo = _periodoLabel(plan['ciclo'] as String? ?? 'mensual');
    final descripcion = plan['descripcion'] as String? ?? '';
    final icono = (plan['ciclo'] == 'anual') ? Icons.star_outline : Icons.calendar_month;
    final estaProcesandoEste = _procesando && _planProcesando == plan['id'].toString();
    final sinMp = (plan['mp_plan_id'] as String?)?.isEmpty ?? true;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: destacado ? const Color(0xFF1F4E79) : Colors.grey[200]!,
          width: destacado ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (destacado)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF1F4E79),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: const Text(
                'MÁS POPULAR',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(icono, size: 36, color: const Color(0xFF1F4E79)),
                const SizedBox(height: 12),
                Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79))),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(precio, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79))),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(periodo, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (descripcion.isNotEmpty)
                  Text(descripcion, style: TextStyle(fontSize: 13, color: Colors.grey[600]), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_procesando || sinMp) ? null : () => _suscribirse(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F4E79),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: estaProcesandoEste
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            sinMp ? 'No disponible' : 'Suscribirme al $titulo',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                if (sinMp)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Este plan aún no está habilitado para pago.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}