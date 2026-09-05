import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class PlanesScreen extends StatelessWidget {
  final bool bloqueante;

  const PlanesScreen({super.key, this.bloqueante = false});

  Future<void> _abrirWeb() async {
    final uri = Uri.parse('https://indovexapp.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final navigator = Navigator.of(context);
    await context.read<AuthProvider>().logout();
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final dias = authProvider.diasRestantesTrial;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
        title: const Text('IndovexApp', style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: !bloqueante,
        actions: bloqueante
            ? [
                TextButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                  label: const Text('Salir', style: TextStyle(color: Colors.white70)),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícono
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: bloqueante
                        ? Colors.red[50]
                        : Colors.orange[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    bloqueante ? Icons.lock_outline : Icons.warning_amber_rounded,
                    size: 40,
                    color: bloqueante ? Colors.red[400] : Colors.orange[700],
                  ),
                ),

                const SizedBox(height: 28),

                // Título
                Text(
                  bloqueante
                      ? 'Tu período de prueba ha vencido'
                      : dias == 0
                          ? 'Tu período de prueba vence hoy'
                          : 'Te quedan $dias día${dias == 1 ? '' : 's'} de prueba',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F4E79),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Descripción
                Text(
                  'Podés conocer más sobre IndovexApp en nuestro sitio web.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Botón principal
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _abrirWeb,
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text(
                      'Ir a indovexapp.com',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F4E79),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Texto de apoyo
                Text(
                  'Si ya sos cliente, tu acceso se actualiza automáticamente.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Si no es bloqueante, opción de volver
                if (!bloqueante) ...[
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Volver',
                      style: TextStyle(color: Color(0xFF1F4E79)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}