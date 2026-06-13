import 'package:postgrest/postgrest.dart';

/// Normaliza un texto: quita espacios al inicio/final y colapsa
/// espacios múltiples internos a uno solo.
/// Ej: "  Depósito   A  " -> "Depósito A"
String normalizarTexto(String texto) {
  return texto.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Convierte errores de Postgres/Supabase en mensajes amigables para el usuario.
///
/// Uso:
/// ```dart
/// try {
///   await _supabase.from('sectores').insert({...});
/// } catch (e) {
///   _mostrarError(mensajeAmigableDb(e, entidad: 'sector'));
/// }
/// ```
String mensajeAmigableDb(Object error, {required String entidad, String campos = 'nombre'}) {
  if (error is PostgrestException) {
    // 23505 = unique_violation
    if (error.code == '23505') {
      return 'Ya existe un $entidad con ese $campos en tu empresa. '
          'Probá con otro valor.';
    }
    // 23503 = foreign_key_violation
    if (error.code == '23503') {
      return 'No se puede completar la operación: hay datos relacionados '
          'que lo impiden.';
    }
    // 23502 = not_null_violation
    if (error.code == '23502') {
      return 'Falta completar un campo obligatorio.';
    }
  }
  return 'Ocurrió un error inesperado. Intentá nuevamente.';
}

/// Para errores que llegan como texto plano desde Edge Functions
/// (ej. `data['error']`), detecta si el mensaje corresponde a una
/// violación de unicidad y devuelve un mensaje amigable.
String mensajeAmigableDesdeTexto(String mensajeOriginal, {required String entidad}) {
  final m = mensajeOriginal.toLowerCase();
  if (m.contains('duplicate key') || m.contains('23505') || m.contains('already registered') || m.contains('ya existe')) {
    return 'Ya existe un $entidad con esos datos en tu empresa. '
        'Probá con otro nombre o email.';
  }
  return mensajeOriginal;
}

/// Normaliza un email: trim + colapsa espacios + lowercase.
/// (Los emails son case-insensitive por convención y no deberían
/// llevar tildes; si las tiene, es un error de tipeo que el
/// validador detectará por separado).
String normalizarEmail(String email) {
  return normalizarTexto(email).toLowerCase();
}

/// Valida formato básico de email (algo@algo.algo).
/// Coincide con el CHECK constraint aplicado en la base de datos.
bool esEmailValido(String email) {
  if (email.isEmpty) return false;
  final regex = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
  return regex.hasMatch(email);
}

/// Valida un RUT uruguayo (12 dígitos). El dígito verificador es el
/// último (posición 12), calculado sobre los primeros 11 dígitos con
/// la serie de pesos [4,3,2,9,8,7,6,5,4,3,2] (módulo 11).
/// Coincide con la función rut_uy_valido aplicada como CHECK en la DB.
bool esRutUyValido(String rut) {
  if (!RegExp(r'^[0-9]{12}$').hasMatch(rut)) return false;

  const pesos = [4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  int suma = 0;
  for (int i = 0; i < 11; i++) {
    suma += int.parse(rut[i]) * pesos[i];
  }
  final resto = suma % 11;
  final verificador = (11 - resto) % 11;

  return int.parse(rut[11]) == verificador;
}