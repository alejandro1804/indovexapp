import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/maquina.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/adjuntos_section.dart';
import '../../widgets/foto_principal_widget.dart';
import '../../widgets/repuestos_maquina_section.dart';

class MaquinaDetailScreen extends StatefulWidget {
  final Maquina maquina;

  const MaquinaDetailScreen({super.key, required this.maquina});

  @override
  State<MaquinaDetailScreen> createState() => _MaquinaDetailScreenState();
}

class _MaquinaDetailScreenState extends State<MaquinaDetailScreen> {
  late Maquina _maquina;

  @override
  void initState() {
    super.initState();
    _maquina = widget.maquina;
  }

  bool get _puedeGestionar {
    final usuario = context.read<AuthProvider>().usuario;
    return usuario?.tienePermiso('gestionar_maquinas') ?? false;
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'operativa':
        return Colors.green;
      case 'en_mantenimiento':
        return Colors.orange;
      case 'fuera_de_servicio':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _labelEstado(String estado) {
    switch (estado) {
      case 'operativa':
        return 'Operativa';
      case 'en_mantenimiento':
        return 'En mantenimiento';
      case 'fuera_de_servicio':
        return 'Fuera de servicio';
      default:
        return estado;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_maquina.nombre, style: const TextStyle(fontSize: 18)),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Foto principal ──────────────────────────────────────────────
          Center(
            child: FotoPrincipalWidget(
              storagePath: _maquina.imagenUrl,
              tipo: 'maquina',
              empresaId: _maquina.empresaId,
              entidadId: _maquina.id,
              size: 120,
              puedeEditar: _puedeGestionar,
              onFotoActualizada: (nuevoPath) {
                // Actualizar el modelo local para reflejar el cambio sin recargar
                setState(() {
                  _maquina = Maquina(
                    id: _maquina.id,
                    empresaId: _maquina.empresaId,
                    sectorId: _maquina.sectorId,
                    nombre: _maquina.nombre,
                    codigo: _maquina.codigo,
                    estado: _maquina.estado,
                    descripcion: _maquina.descripcion,
                    imagenUrl: nuevoPath.isEmpty ? null : nuevoPath,
                  );
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Estado ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _colorEstado(_maquina.estado).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _colorEstado(_maquina.estado).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.circle,
                    color: _colorEstado(_maquina.estado), size: 12),
                const SizedBox(width: 8),
                Text(
                  _labelEstado(_maquina.estado),
                  style: TextStyle(
                    color: _colorEstado(_maquina.estado),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Información ─────────────────────────────────────────────────
          Card(
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Información',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Divider(),
                  _infoRow('Código', _maquina.codigo),
                  if (_maquina.descripcion != null &&
                      _maquina.descripcion!.isNotEmpty)
                    _infoRowVertical('Descripción', _maquina.descripcion!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Repuestos asociados ─────────────────────────────────────────
          RepuestosMaquinaSection(
            modo: 'desde_maquina',
            entidadId: _maquina.id,
          ),
          const SizedBox(height: 16),

          // ── Adjuntos (PDFs, manuales, etc.) ────────────────────────────
          AdjuntosSection(
            entidadTipo: 'maquina',
            entidadId: _maquina.id,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRowVertical(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: Text(
              value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}