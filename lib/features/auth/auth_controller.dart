import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
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

  // ---------------- Mensajes genéricos (SEGURIDAD) ----------------
  // Nunca se muestra al usuario el texto del servidor ni detalles técnicos
  // (códigos HTTP, excepciones). Así no se revela, por ejemplo, si un correo
  // está registrado ("Usuario no encontrado" vs "Contraseña incorrecta"),
  // lo que ayudaría a un atacante a adivinar cuentas.
  // OJO: los textos que el repositorio compara con el backend ("Login correcto",
  // "2FA requerido"...) NO se tocan; aquí solo se traduce el error final.

  static const mensajeCredenciales = 'Credenciales inválidas';
  static const mensajeRegistro = 'No se pudo completar el registro';
  static const mensajeCodigo = 'Código inválido';
  static const mensajeConexion = 'No se pudo conectar, intenta de nuevo';

  /// true si el error vino de la red o del servidor (sin conexión, timeout,
  /// HTTP 4xx/5xx o respuesta inesperada) y no de las credenciales.
  bool _esErrorDeConexion(Object e) {
    if (e is TimeoutException ||
        e is SocketException ||
        e is HandshakeException ||
        e is http.ClientException) {
      return true;
    }
    // Mensajes que generan ApiClient y AuthRepository para fallas HTTP.
    final texto = e.toString();
    return texto.contains('Error del servidor') ||
        texto.contains('Respuesta inesperada del servidor');
  }

  /// Elige el mensaje genérico: de conexión, o [mensajeLogico] para todo lo demás.
  String _mensajeGenerico(Object e, String mensajeLogico) =>
      _esErrorDeConexion(e) ? mensajeConexion : mensajeLogico;

  /// Borra el error mostrado (por ejemplo, al pasar de login a registro).
  void limpiarError() {
    // copyWith sin "error" lo deja en null (ver AuthState.copyWith).
    if (state.error != null) state = state.copyWith();
  }

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
      state = state.copyWith(
          enProceso: false, error: _mensajeGenerico(e, mensajeCredenciales));
    }
  }

  Future<bool> registrar(String username, String correo, String password) async {
    state = state.copyWith(enProceso: true);
    try {
      await _repo.registrar(username, correo, password);
      state = state.copyWith(enProceso: false);
      return true;
    } catch (e) {
      // Genérico también para "El usuario ya existe": no se confirma qué
      // correos/usuarios están registrados.
      state = state.copyWith(
          enProceso: false, error: _mensajeGenerico(e, mensajeRegistro));
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
      state = state.copyWith(
          enProceso: false, error: _mensajeGenerico(e, mensajeCodigo));
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
