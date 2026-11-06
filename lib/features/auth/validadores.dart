// Validaciones de los formularios de login y registro (código seguro).
//
// SEGURIDAD: validar en el cliente NO reemplaza la validación del servidor,
// pero evita enviar datos vacíos, enormes o mal formados, y da una mejor
// experiencia al usuario. El backend sigue siendo quien decide.

/// Longitudes máximas: limitan lo que se envía al servidor y evitan
/// entradas desmedidas (por ejemplo, pegar textos gigantes).
const int maxUsuario = 30;
const int maxCorreo = 100;
const int maxPassword = 64;

/// Longitud mínima de la contraseña al crear una cuenta.
const int minPassword = 8;

/// Formato básico de correo: algo@algo.algo, sin espacios.
final RegExp _formatoCorreo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Nombre de usuario: obligatorio y máximo 30 caracteres.
/// Se usa trim() para rechazar un usuario formado solo por espacios.
String? validarUsuario(String? valor) {
  final texto = (valor ?? '').trim();
  if (texto.isEmpty) return 'Ingresa tu nombre de usuario';
  if (texto.length > maxUsuario) return 'Máximo $maxUsuario caracteres';
  return null;
}

/// Correo: obligatorio, máximo 100 caracteres y con formato válido.
String? validarCorreo(String? valor) {
  final texto = (valor ?? '').trim();
  if (texto.isEmpty) return 'Ingresa tu correo';
  if (texto.length > maxCorreo) return 'Máximo $maxCorreo caracteres';
  if (!_formatoCorreo.hasMatch(texto)) return 'Ingresa un correo válido';
  return null;
}

/// Contraseña en el LOGIN: obligatoria y máximo 64 caracteres.
/// No se exige mínimo aquí: quien valida la contraseña real es el servidor,
/// y así no se bloquea a cuentas antiguas con contraseñas más cortas.
///
/// La contraseña NO se recorta con trim() al enviarla (un espacio puede ser
/// parte legítima de ella); trim() solo se usa para rechazar "solo espacios".
String? validarPasswordLogin(String? valor) {
  final texto = valor ?? '';
  if (texto.trim().isEmpty) return 'Ingresa tu contraseña';
  if (texto.length > maxPassword) return 'Máximo $maxPassword caracteres';
  return null;
}

/// Contraseña en el REGISTRO: además, mínimo 8 caracteres.
String? validarPasswordRegistro(String? valor) {
  final error = validarPasswordLogin(valor);
  if (error != null) return error;
  if ((valor ?? '').length < minPassword) return 'Mínimo $minPassword caracteres';
  return null;
}
