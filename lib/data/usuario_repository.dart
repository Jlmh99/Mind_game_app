import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/providers.dart';

/// Datos del usuario autenticado según el servidor (GET /api/users/me).
/// Sirve para mostrar el id y el rol en "Mi perfil" y comprobar que dos
/// dispositivos con cuentas distintas se identifican distinto.
class UsuarioActual {
  final int id;
  final String username;
  final String email;
  final String rol;

  const UsuarioActual(
      {required this.id, required this.username, required this.email, required this.rol});

  factory UsuarioActual.fromJson(Map<String, dynamic> j) => UsuarioActual(
        id: (j['id'] as num).toInt(),
        username: (j['username'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        rol: (j['rol'] ?? 'USER').toString(),
      );
}

class UsuarioRepository {
  final ApiClient api;
  UsuarioRepository(this.api);

  Future<UsuarioActual> actual() async {
    final r = await api.get(rutaUsuarioActual, autenticado: true);
    if (r is Map<String, dynamic> && r['id'] != null) return UsuarioActual.fromJson(r);
    throw Exception('Respuesta inesperada del servidor');
  }
}

final usuarioRepositoryProvider = Provider<UsuarioRepository>(
  (ref) => UsuarioRepository(ref.watch(apiClientProvider)),
);
