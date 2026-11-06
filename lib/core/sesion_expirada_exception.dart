/// Se lanza cuando una petición autenticada ya no es válida:
///  - el servidor respondió 401 (no autorizado) o 403 (prohibido), o
///  - no hay token guardado en la sesión local.
///
/// Quien la capture debe llamar a AuthController.sesionExpirada(), que borra
/// la sesión local y regresa al login con el mensaje "Tu sesión expiró".
class SesionExpiradaException implements Exception {
  const SesionExpiradaException();

  @override
  String toString() => 'Tu sesión expiró';
}
