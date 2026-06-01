import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';

class CambiarPasswordScreen extends StatefulWidget {
  const CambiarPasswordScreen({super.key});

  @override
  State<CambiarPasswordScreen> createState() => _CambiarPasswordScreenState();
}

class _CambiarPasswordScreenState extends State<CambiarPasswordScreen> {
  final _supabase = Supabase.instance.client;
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _verPassword = false;
  bool _guardando = false;

  Future<void> _guardar() async {
    final pass = _passwordController.text.trim();
    final confirmar = _confirmarController.text.trim();

    if (pass.length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (pass != confirmar) {
      _mostrarError('Las contraseñas no coinciden');
      return;
    }

    setState(() => _guardando = true);
    try {
      // 1. Actualizar la contraseña en Supabase Auth
      await _supabase.auth.updateUser(UserAttributes(password: pass));

      // 2. Marcar primer_login = false en la tabla usuarios
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('usuarios').update({'primer_login': false}).eq('id', userId);

      // 3. Recargar el usuario en el provider
      if (!mounted) return;
      await context.read<AuthProvider>().cargarUsuario();

      // 4. Ir a la pantalla principal
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      _mostrarError('Error al cambiar la contraseña: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarError(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    // PopScope evita que el usuario salga con el botón atrás
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cambiar contraseña'),
          backgroundColor: const Color(0xFF1F4E79),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false, // sin flecha de atrás
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: const Color(0xFF1F4E79)),
                  const SizedBox(height: 16),
                  const Text(
                    'Por seguridad, definí tu nueva contraseña antes de continuar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_verPassword,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _verPassword = !_verPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmarController,
                    obscureText: !_verPassword,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _guardando ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F4E79),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _guardando
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar y continuar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}