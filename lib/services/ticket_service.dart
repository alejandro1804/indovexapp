import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ticket.dart';

class TicketService {
  final _supabase = Supabase.instance.client;

  Future<List<Ticket>> obtenerTickets() async {
    final data = await _supabase
        .from('tickets')
        .select()
        .order('created_at', ascending: false);
    return (data as List).map((e) => Ticket.fromMap(e)).toList();
  }

  Future<List<Ticket>> obtenerTicketsPorEstado(String estado) async {
    final data = await _supabase
        .from('tickets')
        .select()
        .eq('estado', estado)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Ticket.fromMap(e)).toList();
  }

  Future<String> crearTicket({
    required String maquinaId,
    required String descripcion,
    String? fotoUrl,
  }) async {
    final ticketId = await _supabase.rpc('crear_ticket', params: {
      'p_maquina_id': maquinaId,
      'p_descripcion': descripcion,
      'p_foto_url': fotoUrl,
    });
    return ticketId as String;
  }

  Future<void> actualizarEstado(
    String ticketId,
    String nuevoEstado,
    String usuarioId, {
    String? comentario,
  }) async {
    final ticket = await _supabase
        .from('tickets')
        .select('estado')
        .eq('id', ticketId)
        .single();

    await _supabase
        .from('tickets')
        .update({'estado': nuevoEstado}).eq('id', ticketId);

    await _supabase.from('ticket_historial').insert({
      'ticket_id': ticketId,
      'usuario_id': usuarioId,
      'estado_anterior': ticket['estado'],
      'estado_nuevo': nuevoEstado,
      'comentario': comentario,
    });
  }

  Future<void> asignarTecnico(
    String ticketId,
    String tecnicoId,
    String usuarioId,
  ) async {
    await _supabase.from('tickets').update({
      'tecnico_id': tecnicoId,
      'estado': 'asignado',
    }).eq('id', ticketId);

    await _supabase.from('ticket_historial').insert({
      'ticket_id': ticketId,
      'usuario_id': usuarioId,
      'estado_anterior': 'abierto',
      'estado_nuevo': 'asignado',
      'comentario': 'Técnico asignado',
    });
  }
}