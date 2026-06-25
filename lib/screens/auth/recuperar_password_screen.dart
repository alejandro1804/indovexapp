import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pantalla donde el usuario ingresa su email para recibir el link
/// de restablecimiento de contraseña (Supabase Auth nativo).
class RecuperarPasswordScreen extends StatefulWidget {
  const RecuperarPasswordScreen({super.key});

  @override
  State<RecuperarPasswordScreen> createState() => _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  final _supabase = Supabase.instance.client;
  final _emailController = TextEditingController();
  bool _enviando = false;
  bool _enviado = false;

  // A dónde vuelve el usuario tras hacer clic en el link del mail.
  static const _redirectTo = 'https://app.indovexapp.com';

  Future<void> _enviar() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _mostrarError('Ingresá un email válido');
      return;
    }

    setState(() => _enviando = true);
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: _redirectTo,
      );
      // Por seguridad, siempre mostramos éxito aunque el email no exista
      // (no revelamos si una cuenta está registrada o no).
      if (mounted) setState(() => _enviado = true);
    } catch (e) {
      _mostrarError('No se pudo enviar el correo. Intentá de nuevo más tarde.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar contraseña'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _enviado ? _buildEnviado() : _buildFormulario(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_reset_outlined, size: 64, color: Color(0xFF1F4E79)),
        const SizedBox(height: 16),
        const Text(
          'Ingresá el email con el que te registraste. Te enviaremos un enlace para definir una nueva contraseña.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _enviando ? null : _enviar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F4E79),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: _enviando
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Enviar enlace'),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver al inicio de sesión', style: TextStyle(color: Color(0xFF1F4E79))),
        ),
      ],
    );
  }

  Widget _buildEnviado() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text(
          'Si el email está registrado, vas a recibir un enlace para restablecer tu contraseña en los próximos minutos.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 8),
        const Text(
          'Revisá también la carpeta de spam o correo no deseado.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F4E79),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Volver al inicio de sesión'),
        ),
      ],
    );
  }
}