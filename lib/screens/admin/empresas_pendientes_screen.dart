import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmpresasPendientesScreen extends StatefulWidget {
  const EmpresasPendientesScreen({super.key});

  @override
  State<EmpresasPendientesScreen> createState() => _EmpresasPendientesScreenState();
}

class _EmpresasPendientesScreenState extends State<EmpresasPendientesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _empresas = [];
  bool _cargando = true;
  String? _procesandoId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await _supabase.rpc('listar_empresas_pendientes');
      setState(() {
        _empresas = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      _mostrarError('Error al cargar empresas: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _aprobar(Map<String, dynamic> empresa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprobar empresa'),
        content: Text(
          '¿Aprobar a "${empresa['empresa_nombre']}"?\n\n'
          'Se activará la empresa, se crearán sus roles base, y '
          '${empresa['admin_nombre'] ?? 'su administrador'} podrá ingresar como admin.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _procesandoId = empresa['empresa_id']);
    try {
      await _supabase.rpc('aprobar_empresa', params: {'p_empresa_id': empresa['empresa_id']});
      _mostrarExito('Empresa "${empresa['empresa_nombre']}" aprobada');
      await _cargar();
    } catch (e) {
      _mostrarError('Error al aprobar: $e');
    } finally {
      if (mounted) setState(() => _procesandoId = null);
    }
  }

  void _mostrarExito(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
  }

  void _mostrarError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Empresas pendientes'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _empresas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No hay empresas pendientes', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _empresas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final e = _empresas[index];
                      final procesando = _procesandoId == e['empresa_id'];
                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.business, color: Color(0xFF1F4E79)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      e['empresa_nombre'] ?? 'Sin nombre',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (e['rut'] != null && e['rut'].toString().isNotEmpty)
                                _dato('RUT', e['rut']),
                              if (e['direccion'] != null && e['direccion'].toString().isNotEmpty)
                                _dato('Dirección', e['direccion']),
                              if (e['telefono'] != null && e['telefono'].toString().isNotEmpty)
                                _dato('Teléfono', e['telefono']),
                              if (e['email_contacto'] != null && e['email_contacto'].toString().isNotEmpty)
                                _dato('Email empresa', e['email_contacto']),
                              const Divider(height: 20),
                              const Text('Administrador', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79))),
                              const SizedBox(height: 4),
                              _dato('Nombre', e['admin_nombre'] ?? '—'),
                              _dato('Email', e['admin_email'] ?? '—'),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: procesando ? null : () => _aprobar(e),
                                  icon: procesando
                                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.check),
                                  label: Text(procesando ? 'Aprobando...' : 'Aprobar'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _dato(String label, dynamic valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Expanded(child: Text('$valor', style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}