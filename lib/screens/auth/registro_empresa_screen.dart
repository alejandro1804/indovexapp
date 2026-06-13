import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:functions_client/functions_client.dart' show FunctionException;
import 'package:url_launcher/url_launcher.dart';
import '../../core/db_error_helper.dart';

class RegistroEmpresaScreen extends StatefulWidget {
  const RegistroEmpresaScreen({super.key});

  @override
  State<RegistroEmpresaScreen> createState() => _RegistroEmpresaScreenState();
}

class _RegistroEmpresaScreenState extends State<RegistroEmpresaScreen> {
  final _supabase = Supabase.instance.client;

  final _empresaNombre = TextEditingController();
  final _rut = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  final _emailContacto = TextEditingController();
  final _adminNombre = TextEditingController();
  final _adminEmail = TextEditingController();
  final _adminPassword = TextEditingController();

  bool _verPassword = false;
  bool _enviando = false;
  bool _aceptoTerminos = false;

  // URLs de documentos legales
  static const _urlTerminos = 'https://indovexapp.com/terminos.html';
  static const _urlPrivacidad = 'https://indovexapp.com/privacidad.html';

  Future<void> _abrirUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _registrar() async {
    final empresaNombre = normalizarTexto(_empresaNombre.text);
    final rut = normalizarTexto(_rut.text);
    final direccion = normalizarTexto(_direccion.text);
    final telefono = normalizarTexto(_telefono.text);
    final emailContacto = normalizarEmail(_emailContacto.text);
    final adminNombre = normalizarTexto(_adminNombre.text);
    final adminEmail = normalizarEmail(_adminEmail.text);
    final adminPassword = _adminPassword.text.trim();

    // Validacion basica
    if (empresaNombre.isEmpty ||
        adminNombre.isEmpty ||
        adminEmail.isEmpty ||
        adminPassword.isEmpty) {
      _mostrarError('Completá los campos obligatorios (*)');
      return;
    }
    if (adminPassword.length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    // Validación de formato de email
    if (!esEmailValido(adminEmail)) {
      _mostrarError('El email del administrador no tiene un formato válido.');
      return;
    }
    if (emailContacto.isNotEmpty && !esEmailValido(emailContacto)) {
      _mostrarError('El email de contacto no tiene un formato válido.');
      return;
    }

    // Validación de RUT (opcional, pero si se completa debe ser válido)
    if (rut.isNotEmpty && !esRutUyValido(rut)) {
      _mostrarError('El RUT ingresado no es válido. Verificá los 12 dígitos.');
      return;
    }

    // Validación de longitud de nombres
    if (empresaNombre.length > 100 || adminNombre.length > 100) {
      _mostrarError('El nombre no puede superar los 100 caracteres.');
      return;
    }

    // Validacion de términos
    if (!_aceptoTerminos) {
      _mostrarError('Debés aceptar los Términos y Condiciones para continuar');
      return;
    }

    setState(() => _enviando = true);
    try {
      final response = await _supabase.functions.invoke(
        'registrar_empresa',
        body: {
          'empresa_nombre': empresaNombre,
          'rut': rut,
          'direccion': direccion,
          'telefono': telefono,
          'email_contacto': emailContacto,
          'admin_nombre': adminNombre,
          'admin_email': adminEmail,
          'admin_password': adminPassword,
        },
      );

      final data = response.data;
      if (data != null && data['success'] == true) {
        if (!mounted) return;
        await _mostrarExitoYVolver();
      } else {
        final mensaje = (data?['error'] ?? 'Error desconocido al registrar').toString();
        _mostrarError(mensajeAmigableDesdeTexto(mensaje, entidad: 'empresa'));
      }
    } catch (e) {
      String mensaje = 'Error al registrar';
      if (e is FunctionException) {
        final details = e.details;
        if (details is Map && details['error'] != null) {
          mensaje = details['error'].toString();
        } else {
          mensaje = e.toString();
        }
      } else {
        mensaje = e.toString();
      }
      _mostrarError(mensajeAmigableDesdeTexto(mensaje, entidad: 'empresa'));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _mostrarExitoYVolver() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registro enviado'),
        content: const Text(
          'Tu empresa fue registrada y está pendiente de aprobación. '
          'Te avisaremos cuando esté activa y puedas ingresar.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Widget del checkbox con links
  Widget _checkboxTerminos() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: _aceptoTerminos,
          activeColor: const Color(0xFF1F4E79),
          onChanged: _enviando
              ? null
              : (val) => setState(() => _aceptoTerminos = val ?? false),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              children: [
                const TextSpan(text: 'Acepto los '),
                TextSpan(
                  text: 'Términos y Condiciones',
                  style: const TextStyle(
                    color: Color(0xFF1F4E79),
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _abrirUrl(_urlTerminos),
                ),
                const TextSpan(text: ' y la '),
                TextSpan(
                  text: 'Política de Privacidad',
                  style: const TextStyle(
                    color: Color(0xFF1F4E79),
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _abrirUrl(_urlPrivacidad),
                ),
                const TextSpan(text: ' de Indovex.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar empresa'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Datos de la empresa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F4E79),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _empresaNombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la empresa *',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 100,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rut,
                  decoration: const InputDecoration(
                    labelText: 'RUT',
                    border: OutlineInputBorder(),
                    hintText: 'Ej: 210000000001 (12 dígitos)',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _direccion,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 100,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _telefono,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  maxLength: 30,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailContacto,
                  decoration: const InputDecoration(
                    labelText: 'Email de contacto',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 255,
                ),

                const SizedBox(height: 24),
                const Text(
                  'Datos del administrador',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F4E79),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Esta será la cuenta principal de la empresa.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _adminNombre,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del administrador *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 100,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _adminEmail,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  maxLength: 255,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _adminPassword,
                  obscureText: !_verPassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _verPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                      ),
                      onPressed: () =>
                          setState(() => _verPassword = !_verPassword),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Checkbox términos
                _checkboxTerminos(),

                const SizedBox(height: 16),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _enviando ? null : _registrar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F4E79),
                      foregroundColor: Colors.white,
                    ),
                    child: _enviando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Registrar empresa',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}