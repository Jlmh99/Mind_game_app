/// El servidor rechazó la acción por permisos (HTTP 403 con un mensaje del
/// backend, por ejemplo "No tienes permiso para realizar esta acción").
///
/// Es distinto de SesionExpiradaException: aquí la sesión sigue siendo válida,
/// solo que este usuario no puede hacer esta acción en particular.
class PermisoDenegadoException implements Exception {
  const PermisoDenegadoException();

  @override
  String toString() => 'No tienes permiso para esta acción';
}

/// Respuesta HTTP con un código de error (4xx/5xx) que no es de sesión.
/// Guarda el código para reaccionar distinto (409 conflicto, 404 no existe...).
/// Nunca guarda el cuerpo de la respuesta (podría tener datos del servidor).
class ErrorHttpException implements Exception {
  final int codigo;
  const ErrorHttpException(this.codigo);

  bool get esConflicto => codigo == 409;
  bool get noEncontrado => codigo == 404;

  // Mismo texto que antes ("Error del servidor (N)"): AuthController lo usa
  // para reconocer errores de red/servidor.
  @override
  String toString() => 'Error del servidor ($codigo)';
}
