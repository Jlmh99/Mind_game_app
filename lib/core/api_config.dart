// URL del backend. Mientras no esté desplegado, usa tu máquina local:
//  - Emulador Android  -> http://10.0.2.2:8080   (10.0.2.2 = tu PC)
//  - Celular físico    -> http://IP-DE-TU-PC:8080 (misma red Wi-Fi)
// Cuando lo despliegues en Render, cambia solo esta línea por https://...onrender.com
//  - Celular por USB con "adb reverse tcp:8080 tcp:8080" -> http://localhost:8080
// PRESENTACIÓN: celular conectado por USB a la laptop con adb reverse.
// Para volver al emulador, regresa esta línea a 'http://10.0.2.2:8080'.
const String baseUrl = 'http://localhost:8080';

// Rutas reales del AuthController (Spring Boot)
const String rutaRegistro = '/api/auth/register';
const String rutaLogin = '/api/auth/login';
const String rutaVerificar = '/api/auth/verify';

// Rutas del PartidaController (requieren token JWT)
const String rutaPartidas = '/api/partidas';
const String rutaMisPartidas = '/api/partidas/me';

// Foto de perfil del usuario autenticado (GET y PUT, requiere token JWT)
const String rutaFotoPerfil = '/api/users/me/foto';
