import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pantalla donde el usuario ingresa su email para recibir una contraseña
/// temporal. Usa la Edge Function propia `recuperar-password`, que envía el
/// correo desde soporte@indovexapp.com vía ZeptoMail (con el mismo diseño
/// que el resto de los emails del sistema), en lugar del mail por defecto
/// de Supabase Auth.
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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _mostrarError('Ingresá un email válido');
      return;
    }

    setState(() => _enviando = true);
    try {
      // Quien pide recuperar la contraseña no debería tener sesión abierta.
      // Si quedó una vieja o vencida en el navegador, el SDK la adjunta a la
      // llamada y la función falla del lado del servidor. Se limpia antes.
      if (_supabase.auth.currentSession != null) {
        await _supabase.auth.signOut();
      }

      await _supabase.functions.invoke(
        'recuperar-password',
        body: {'email': email},
      );
      // La función siempre responde igual, exista o no el email: por
      // seguridad no revelamos si la cuenta está registrada.
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
          'Ingresá el email con el que te registraste. Te enviaremos una contraseña temporal para que puedas volver a entrar.',
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
              : const Text('Enviar contraseña temporal'),
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
          'Si el email está registrado, vas a recibir una contraseña temporal en los próximos minutos. Al ingresar con ella, el sistema te va a pedir que definas una nueva.',
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