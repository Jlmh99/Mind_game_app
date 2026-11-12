import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sesion_expirada_exception.dart';
import '../../data/usuario_repository.dart';
import '../auth/auth_controller.dart';

class UsuarioActualState {
  final UsuarioActual? usuario; // id, username, email y rol según el servidor
  final bool cargando;
  final String? error; // mensaje genérico

  const UsuarioActualState({this.usuario, this.cargando = false, this.error});
}

final usuarioActualProvider =
    NotifierProvider<UsuarioActualController, UsuarioActualState>(
        UsuarioActualController.new);

/// Pide GET /api/users/me para mostrar el id y el rol en "Mi perfil".
class UsuarioActualController extends Notifier<UsuarioActualState> {
  @override
  UsuarioActualState build() {
    // Si cambia la cuenta, se olvidan los datos anteriores.
    ref.watch(authControllerProvider.select((s) => s.correo));
    return const UsuarioActualState();
  }

  Future<void> cargar() async {
    state = UsuarioActualState(usuario: state.usuario, cargando: true);
    try {
      final usuario = await ref.read(usuarioRepositoryProvider).actual();
      state = UsuarioActualState(usuario: usuario);
    } on SesionExpiradaException {
      await ref.read(authControllerProvider.notifier).sesionExpirada();
    } catch (_) {
      state = UsuarioActualState(
          usuario: state.usuario, error: 'No se pudieron cargar tus datos');
    }
  }
}
