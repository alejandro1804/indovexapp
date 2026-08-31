import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../core/responsive.dart';

/// Perfil de la empresa: permite al admin ver y actualizar los datos de
/// identidad y contacto capturados en el registro.
///
/// Campos editables: nombre, rut, direccion, telefono, email_contacto.
/// El resto (plan, estado de suscripción, fecha de alta) se muestra como
/// informativo de solo lectura. La base rechaza cualquier intento de tocar
/// columnas sensibles (trigger trg_proteger_columnas_empresa), así que la UI
/// solo expone lo que corresponde.
class PerfilEmpresaScreen extends StatefulWidget {
  const PerfilEmpresaScreen({super.key});

  @override
  State<PerfilEmpresaScreen> createState() => _PerfilEmpresaScreenState();
}

class _PerfilEmpresaScreenState extends State<PerfilEmpresaScreen> {
  final _supabase = Supabase.instance.client;

  final _nombreController = TextEditingController();
  final _rutController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();

  Map<String, dynamic>? _empresa;
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _rutController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) {
      setState(() => _cargando = false);
      return;
    }
    try {
      final data = await _supabase
          .from('empresas')
          .select()
          .eq('id', usuario.empresaId)
          .maybeSingle();
      if (data != null) {
        _nombreController.text = data['nombre'] as String? ?? '';
        _rutController.text = data['rut'] as String? ?? '';
        _direccionController.text = data['direccion'] as String? ?? '';
        _telefonoController.text = data['telefono'] as String? ?? '';
        _emailController.text = data['email_contacto'] as String? ?? '';
      }
      setState(() => _empresa = data);
    } catch (e) {
      _mostrarError('Error al cargar el perfil: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    final nombre = _nombreController.text.trim();
    if (nombre.isEmpty) {
      _mostrarError('El nombre de la empresa es obligatorio');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    try {
      // Solo se envían las columnas seguras. La base bloquea el resto.
      await _supabase.from('empresas').update({
        'nombre': nombre,
        'rut': _vacioANull(_rutController.text),
        'direccion': _vacioANull(_direccionController.text),
        'telefono': _vacioANull(_telefonoController.text),
        'email_contacto': _vacioANull(_emailController.text),
      }).eq('id', usuario.empresaId);

      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text('Perfil de empresa actualizado'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
      await _cargar();
    } catch (e) {
      _mostrarError('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String? _vacioANull(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
  }

  String _labelPlan(String? plan) {
    switch (plan) {
      case 'trial': return 'Prueba (trial)';
      case 'starter': return 'Starter';
      case 'pro': return 'Pro';
      case 'interno': return 'Interno';
      default: return plan ?? '-';
    }
  }

  String _fecha(String? iso) {
    if (iso == null) return '-';
    final d = DateTime.tryParse(iso);
    if (d == null) return '-';
    final l = d.toLocal();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${dos(l.month)}-${dos(l.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil de empresa', style: TextStyle(fontSize: 17)),
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _empresa == null
              ? const Center(child: Text('No se pudo cargar el perfil'))
              : ListView(
                  padding: padding,
                  children: [
                    // Datos editables
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Datos de la empresa',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Divider(),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _nombreController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre / Razón social *',
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.words,
                            maxLength: 100,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _rutController,
                            decoration: const InputDecoration(
                              labelText: 'RUT',
                              border: OutlineInputBorder(),
                              hintText: 'Identificación fiscal',
                            ),
                            maxLength: 20,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _direccionController,
                            decoration: const InputDecoration(
                              labelText: 'Dirección',
                              border: OutlineInputBorder(),
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            maxLength: 200,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _telefonoController,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                            maxLength: 30,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email de contacto',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            maxLength: 100,
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Datos informativos (solo lectura)
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Suscripción',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const Divider(),
                          _infoRow('Plan', _labelPlan(_empresa!['plan'] as String?)),
                          if (_empresa!['suscripcion_estado'] != null)
                            _infoRow('Estado de suscripción', _empresa!['suscripcion_estado'] as String),
                          if (_empresa!['trial_vence'] != null)
                            _infoRow('Prueba vence', _fecha(_empresa!['trial_vence'] as String?)),
                          _infoRow('Alta', _fecha(_empresa!['created_at'] as String?)),
                          const SizedBox(height: 8),
                          Text(
                            'El plan y los límites se gestionan desde la suscripción y no se editan aquí.',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: const Text('Guardar cambios', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1F4E79),
                            foregroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 150, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
      ]),
    );
  }
}