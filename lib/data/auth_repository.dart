import '../core/api_client.dart';
import '../core/api_config.dart';
import 'local/app_database.dart';
import 'local/sesion.dart';

class AuthRepository {
  final AppDatabase db;
  final ApiClient api;
  AuthRepository(this.db, this.api);

  // --- Práctica 3: consumo de servicio web con http ---
  // Las peticiones HTTP las hace ApiClient (timeout y normalización incluidos).
  // Las rutas de auth son públicas, por eso no se marcan como autenticadas.
  // ApiClient devuelve dynamic; aquí siempre esperamos un objeto (Map).
  Future<Map<String, dynamic>> _post(
      String ruta, Map<String, dynamic> cuerpo) async {
    final r = await api.post(ruta, cuerpo);
    if (r is Map<String, dynamic>) return r;
    throw Exception('Respuesta inesperada del servidor');
  }

  Future<void> registrar(String username, String email, String password) async {
    final r = await _post(rutaRegistro,
        {'username': username, 'email': email, 'password': password});
    if (r['mensaje'] != 'Usuario registrado correctamente') {
      throw Exception(r['mensaje']);
    }
  }

  /// Devuelve true si el backend pide código 2FA (la cuenta tiene 2FA activo).
  /// Devuelve false si el login fue directo y la sesión ya quedó guardada.
  Future<bool> login(String email, String password) async {
    final r = await _post(rutaLogin, {'email': email, 'password': password});
    final mensaje = r['mensaje'];
    if (mensaje == '2FA requerido') return true;
    if (mensaje == 'Login correcto') {
      await _guardarSesion(r);
      return false;
    }
    throw Exception(mensaje ?? 'No fue posible iniciar sesión');
  }

  /// Verifica el código enviado por correo y guarda la sesión local.
  Future<void> verificarCodigo(String email, String codigo) async {
    final r = await _post(rutaVerificar, {'email': email, 'codigo': codigo});
    if (r['mensaje'] != 'Login correcto') {
      throw Exception(r['mensaje'] ?? 'Código inválido');
    }
    await _guardarSesion(r);
  }

  // --- Práctica 4: persistencia local con Floor ---
  Future<void> _guardarSesion(Map<String, dynamic> r) async {
    await db.sesionDao.guardar(Sesion(
      correo: (r['email'] ?? '').toString(),
      token: (r['token'] ?? '').toString(),
      rol: (r['rol'] ?? 'USER').toString(),
    ));
  }

  Future<Sesion?> sesionGuardada() => db.sesionDao.obtener();

  Future<void> cerrarSesion() => db.sesionDao.limpiar();
}
