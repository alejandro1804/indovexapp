import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> _registrar() async {
    // Validacion basica
    if (_empresaNombre.text.trim().isEmpty ||
        _adminNombre.text.trim().isEmpty ||
        _adminEmail.text.trim().isEmpty ||
        _adminPassword.text.trim().isEmpty) {
      _mostrarError('Completá los campos obligatorios (*)');
      return;
    }
    if (_adminPassword.text.trim().length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() => _enviando = true);
    try {
      final response = await _supabase.functions.invoke(
        'registrar_empresa',
        body: {
          'empresa_nombre': _empresaNombre.text.trim(),
          'rut': _rut.text.trim(),
          'direccion': _direccion.text.trim(),
          'telefono': _telefono.text.trim(),
          'email_contacto': _emailContacto.text.trim(),
          'admin_nombre': _adminNombre.text.trim(),
          'admin_email': _adminEmail.text.trim(),
          'admin_password': _adminPassword.text.trim(),
        },
      );

      final data = response.data;
      if (data != null && data['success'] == true) {
        if (!mounted) return;
        await _mostrarExitoYVolver();
      } else {
        final mensaje = data?['error'] ?? 'Error desconocido al registrar';
        _mostrarError(mensaje.toString());
      }
    } catch (e) {
      _mostrarError('Error al registrar: $e');
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context); // volver al login
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
                const Text('Datos de la empresa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79))),
                const SizedBox(height: 12),
                TextField(controller: _empresaNombre, decoration: const InputDecoration(labelText: 'Nombre de la empresa *', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _rut, decoration: const InputDecoration(labelText: 'RUT', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: _direccion, decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _telefono, decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                TextField(controller: _emailContacto, decoration: const InputDecoration(labelText: 'Email de contacto', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),

                const SizedBox(height: 24),
                const Text('Datos del administrador', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79))),
                const SizedBox(height: 4),
                Text('Esta será la cuenta principal de la empresa.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 12),
                TextField(controller: _adminNombre, decoration: const InputDecoration(labelText: 'Nombre del administrador *', border: OutlineInputBorder()), textCapitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                TextField(controller: _adminEmail, decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder()), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(
                  controller: _adminPassword,
                  obscureText: !_verPassword,
                  decoration: InputDecoration(
                    labelText: 'Contraseña *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey),
                      onPressed: () => setState(() => _verPassword = !_verPassword),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _enviando ? null : _registrar,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
                    child: _enviando
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Registrar empresa', style: TextStyle(fontSize: 16)),
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