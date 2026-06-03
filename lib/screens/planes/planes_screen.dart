import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class PlanesScreen extends StatefulWidget {
  final bool bloqueante;

  const PlanesScreen({super.key, this.bloqueante = false});

  @override
  State<PlanesScreen> createState() => _PlanesScreenState();
}

class _PlanesScreenState extends State<PlanesScreen> {
  bool _cargando = false;
  String? _error;

  Future<void> _suscribirse(String plan) async {
    setState(() {
      _cargando = true;
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
          'plan': plan,
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
      setState(() => _cargando = false);
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // Mensaje trial vencido o por vencer
            if (widget.bloqueante)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: Colors.red[700], size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tu período de prueba ha vencido. Elegí un plan para seguir usando Indovex.',
                        style: TextStyle(color: Colors.red[700], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dias == 0
                            ? 'Tu período de prueba vence hoy.'
                            : 'Te quedan $dias día${dias == 1 ? '' : 's'} de prueba.',
                        style: TextStyle(color: Colors.orange[700], fontSize: 14),
                      ),
                    ),
                  ],
                ),
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

            // Plan mensual
            _buildTarjetaPlan(
              titulo: 'Plan Mensual',
              precio: '\$1.500',
              periodo: 'por mes',
              descripcion: 'Ideal para empezar. Cancelá cuando quieras.',
              icono: Icons.calendar_month,
              plan: 'mensual',
              destacado: false,
            ),

            const SizedBox(height: 16),

            // Plan anual
            _buildTarjetaPlan(
              titulo: 'Plan Anual',
              precio: '\$15.000',
              periodo: 'por año',
              descripcion: '2 meses gratis vs el plan mensual.',
              icono: Icons.star_outline,
              plan: 'anual',
              destacado: true,
            ),

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

  Widget _buildTarjetaPlan({
    required String titulo,
    required String precio,
    required String periodo,
    required String descripcion,
    required IconData icono,
    required String plan,
    required bool destacado,
  }) {
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
                '⭐ MÁS POPULAR',
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
                Text(descripcion, style: TextStyle(fontSize: 13, color: Colors.grey[600]), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _cargando ? null : () => _suscribirse(plan),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F4E79),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _cargando
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('Suscribirme al plan $titulo', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}