// URL del backend. Mientras no esté desplegado, usa tu máquina local:
//  - Emulador Android  -> http://10.0.2.2:8080   (10.0.2.2 = tu PC)
//  - Celular físico    -> http://IP-DE-TU-PC:8080 (misma red Wi-Fi)
// Cuando lo despliegues en Render, cambia solo esta línea por https://...onrender.com
const String baseUrl = 'http://10.0.2.2:8080';

// Rutas reales del AuthController (Spring Boot)
const String rutaRegistro = '/api/auth/register';
const String rutaLogin = '/api/auth/login';
const String rutaVerificar = '/api/auth/verify';
