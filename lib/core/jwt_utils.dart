import 'dart:convert';

// Utilidades para leer el JWT que entrega el backend.
// Un JWT tiene 3 partes separadas por puntos: encabezado.payload.firma
// El payload es JSON codificado en base64url; ahí viene "exp" (segundos
// desde 1970). Aquí SOLO lo decodificamos: la firma la valida el servidor.

/// Devuelve la fecha de expiración del token, o null si no se puede leer.
DateTime? expiracionJwt(String token) {
  final partes = token.split('.');
  if (partes.length != 3) return null;
  try {
    // normalize agrega el relleno '=' que base64url suele omitir.
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(partes[1])));
    final datos = jsonDecode(payload);
    final exp = datos is Map ? datos['exp'] : null;
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
  } catch (_) {
    return null; // payload mal formado
  }
}

/// true si el token ya expiró. Un token ilegible o sin "exp" se considera
/// expirado: el backend siempre lo incluye, así que si falta algo anda mal.
bool tokenExpirado(String token) {
  final exp = expiracionJwt(token);
  if (exp == null) return true;
  return !DateTime.now().isBefore(exp);
}
