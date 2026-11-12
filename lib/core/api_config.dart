// URL del backend desplegado en Render (HTTPS: el tráfico va cifrado).
//
// Para volver a probar con el backend local:
//  - Emulador Android -> http://10.0.2.2:8080 (10.0.2.2 = tu PC)
//  - Celular por USB con "adb reverse tcp:8080 tcp:8080" -> http://localhost:8080
// OJO: con http:// local también hay que volver a poner
// android:usesCleartextTraffic="true" en AndroidManifest.xml.
const String baseUrl = 'https://juegos-mentales-1jma.onrender.com';

// Rutas reales del AuthController (Spring Boot)
const String rutaRegistro = '/api/auth/register';
const String rutaLogin = '/api/auth/login';
const String rutaVerificar = '/api/auth/verify';

// Rutas del PartidaController (requieren token JWT)
const String rutaPartidas = '/api/partidas';
const String rutaMisPartidas = '/api/partidas/me';

// Foto de perfil del usuario autenticado (GET y PUT, requiere token JWT)
const String rutaFotoPerfil = '/api/users/me/foto';

// Perfil del usuario autenticado (id, username, email, rol)
const String rutaUsuarioActual = '/api/users/me';

// Incidencias (requieren token JWT; los permisos los decide el backend)
const String rutaIncidencias = '/api/incidencias';
const String rutaAgentes = '/api/incidencias/agentes';
