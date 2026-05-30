import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/proveedor.dart';

class ProveedorService {
  final _supabase = Supabase.instance.client;

  Future<List<Proveedor>> obtenerProveedores() async {
    final data = await _supabase
        .from('proveedores')
        .select()
        .eq('activo', true)
        .order('nombre');
    return (data as List).map((e) => Proveedor.fromMap(e)).toList();
  }
}
