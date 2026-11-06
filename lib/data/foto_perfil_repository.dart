import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/providers.dart';

/// Foto de perfil en el backend (/api/users/me/foto).
/// El HTTP y el token los resuelve ApiClient (autenticado: true).
/// Puede lanzar SesionExpiradaException (401/403 o sin token).
class FotoPerfilRepository {
  final ApiClient api;
  FotoPerfilRepository(this.api);

  /// GET: devuelve los bytes de la foto o null si el usuario no tiene.
  Future<Uint8List?> obtener() async {
    final r = await api.get(rutaFotoPerfil, autenticado: true);
    if (r is Map<String, dynamic> && r.containsKey('foto')) {
      final foto = r['foto'];
      if (foto == null) return null;
      if (foto is String) return base64Decode(foto);
    }
    throw Exception('Respuesta inesperada del servidor');
  }

  /// PUT: envía la foto (ya comprimida) como `{ "foto": "<base64>" }`.
  Future<void> subir(Uint8List bytes) async {
    await api.put(
      rutaFotoPerfil,
      {'foto': base64Encode(bytes)},
      autenticado: true,
    );
  }
}

final fotoPerfilRepositoryProvider = Provider<FotoPerfilRepository>(
  (ref) => FotoPerfilRepository(ref.watch(apiClientProvider)),
);
