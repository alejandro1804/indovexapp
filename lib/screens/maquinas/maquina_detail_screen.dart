import 'package:flutter/material.dart';
import '../../models/maquina.dart';
import '../../widgets/adjuntos_section.dart';

class MaquinaDetailScreen extends StatelessWidget {
  final Maquina maquina;

  const MaquinaDetailScreen({super.key, required this.maquina});

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'operativa': return Colors.green;
      case 'en_mantenimiento': return Colors.orange;
      case 'fuera_de_servicio': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _labelEstado(String estado) {
    switch (estado) {
      case 'operativa': return 'Operativa';
      case 'en_mantenimiento': return 'En mantenimiento';
      case 'fuera_de_servicio': return 'Fuera de servicio';
      default: return estado;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(maquina.nombre),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Estado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _colorEstado(maquina.estado).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _colorEstado(maquina.estado).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, color: _colorEstado(maquina.estado), size: 12),
                const SizedBox(width: 8),
                Text(
                  _labelEstado(maquina.estado),
                  style: TextStyle(
                    color: _colorEstado(maquina.estado),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Información
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(),
                  _infoRow('Código', maquina.codigo),
                  if (maquina.descripcion != null && maquina.descripcion!.isNotEmpty)
                    _infoRow('Descripción', maquina.descripcion!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Acciones rápidas
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.confirmation_number_outlined),
                  label: const Text('Ver Tickets'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1F4E79),
                    side: const BorderSide(color: Color(0xFF1F4E79)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Repuestos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1F4E79),
                    side: const BorderSide(color: Color(0xFF1F4E79)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Adjuntos
          AdjuntosSection(
            entidadTipo: 'maquina',
            entidadId: maquina.id,
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
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}