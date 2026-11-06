import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/jwt_utils.dart';
import '../../core/providers.dart';
import '../../data/auth_repository.dart';

enum AuthStatus { cargando, noAutenticado, esperandoCodigo, autenticado }

class AuthState {
  final AuthStatus status;
  final String? correo;
  final String? rol; // 'USER', 'ADMIN'... (viene del backend al hacer login)
  final bool enProceso;
  final String? error;

  const AuthState({
    this.status = AuthStatus.cargando,
    this.correo,
    this.rol,
    this.enProceso = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? correo,
    String? rol,
    bool? enProceso,
    String? error, // null limpia el error
  }) =>
      AuthState(
        status: status ?? this.status,
        correo: correo ?? this.correo,
        rol: rol ?? this.rol,
        enProceso: enProceso ?? this.enProceso,
        error: error,
      );
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    Future.microtask(restaurarSesion);
    return const AuthState();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> restaurarSesion() async {
    final s = await _repo.sesionGuardada();
    if (s == null) {
      state = const AuthState(status: AuthStatus.noAutenticado);
      return;
    }
    // Si el JWT guardado ya venció, no tiene caso entrar: se borra y al login.
    if (tokenExpirado(s.token)) {
      await sesionExpirada();
      return;
    }
    state = AuthState(
      status: AuthStatus.autenticado,
      correo: s.correo,
      rol: s.rol,
    );
  }

  /// Estado "autenticado" tomando el rol de la sesión que el repositorio
  /// acaba de guardar en Floor (así no duplicamos la lectura de la respuesta).
  Future<AuthState> _estadoAutenticado(String correo) async {
    final s = await _repo.sesionGuardada();
    return AuthState(
      status: AuthStatus.autenticado,
      correo: correo,
      rol: s?.rol,
    );
  }

  Future<void> login(String correo, String password) async {
    state = state.copyWith(enProceso: true);
    try {
      final pideCodigo = await _repo.login(correo, password);
      state = pideCodigo
          ? AuthState(status: AuthStatus.esperandoCodigo, correo: correo)
          : await _estadoAutenticado(correo);
    } catch (e) {
      state = state.copyWith(enProceso: false, error: _msg(e));
    }
  }

  Future<bool> registrar(String username, String correo, String password) async {
    state = state.copyWith(enProceso: true);
    try {
      await _repo.registrar(username, correo, password);
      state = state.copyWith(enProceso: false);
      return true;
    } catch (e) {
      state = state.copyWith(enProceso: false, error: _msg(e));
      return false;
    }
  }

  Future<void> verificarCodigo(String codigo) async {
    final correo = state.correo ?? '';
    state = state.copyWith(enProceso: true);
    try {
      await _repo.verificarCodigo(correo, codigo);
      state = await _estadoAutenticado(correo);
    } catch (e) {
      state = state.copyWith(enProceso: false, error: _msg(e));
    }
  }

  void volverALogin() =>
      state = const AuthState(status: AuthStatus.noAutenticado);

  Future<void> cerrarSesion() async {
    await _repo.cerrarSesion();
    state = const AuthState(status: AuthStatus.noAutenticado);
  }

  /// Se llama cuando cualquier petición autenticada lanza
  /// SesionExpiradaException (401/403 o token vencido).
  /// Borra la sesión local y regresa al login mostrando el motivo.
  ///
  /// Uso desde otro controller:
  ///   try { ... } on SesionExpiradaException {
  ///     await ref.read(authControllerProvider.notifier).sesionExpirada();
  ///   }
  Future<void> sesionExpirada() async {
    await _repo.cerrarSesion();
    state = const AuthState(
      status: AuthStatus.noAutenticado,
      error: 'Tu sesión expiró',
    );
  }
}
