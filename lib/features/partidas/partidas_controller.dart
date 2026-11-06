import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sesion_expirada_exception.dart';
import '../../data/partidas_repository.dart';
import '../auth/auth_controller.dart';

/// Resultado de intentar guardar una partida (para decidir qué mostrar).
enum ResultadoGuardado { guardada, fallo, sesionExpirada }

class PartidasState {
  final List<Partida> partidas; // de la más reciente a la más antigua
  final bool cargando;
  final String? error; // mensaje genérico para la pantalla

  const PartidasState({
    this.partidas = const [],
    this.cargando = false,
    this.error,
  });

  PartidasState copyWith({
    List<Partida>? partidas,
    bool? cargando,
    String? error, // null limpia el error
  }) =>
      PartidasState(
        partidas: partidas ?? this.partidas,
        cargando: cargando ?? this.cargando,
        error: error,
      );
}

final partidasControllerProvider =
    NotifierProvider<PartidasController, PartidasState>(PartidasController.new);

/// Guarda y lista las partidas del usuario autenticado.
/// No es autoDispose: se usa desde Sudoku, Crucigrama y Perfil, y así la
/// lista recién guardada sigue disponible al abrir "Mi perfil".
class PartidasController extends Notifier<PartidasState> {
  PartidasRepository get _repo => ref.read(partidasRepositoryProvider);

  @override
  PartidasState build() {
    // Si cambia el usuario (logout, sesión expirada, otro login) se reinicia
    // el estado para no mostrar partidas de otra cuenta.
    ref.watch(authControllerProvider.select((s) => s.correo));
    return const PartidasState();
  }

  /// Carga las partidas del servidor (GET /api/partidas/me).
  Future<void> cargar() async {
    state = state.copyWith(cargando: true);
    try {
      final partidas = await _repo.misPartidas();
      state = PartidasState(partidas: partidas);
    } on SesionExpiradaException {
      // Tal como indica AuthController.sesionExpirada(): borra sesión y va al login.
      await ref.read(authControllerProvider.notifier).sesionExpirada();
    } catch (_) {
      // Mensaje genérico: no mostramos detalles técnicos ni la respuesta.
      state = state.copyWith(
          cargando: false, error: 'No se pudieron cargar tus partidas');
    }
  }

  /// Guarda una partida terminada (POST /api/partidas) y la agrega al inicio
  /// de la lista local para que "Mi perfil" la muestre sin recargar.
  Future<ResultadoGuardado> guardar({
    required String juego,
    required int tiempoSegundos,
    required int puntuacion,
  }) async {
    try {
      final partida = await _repo.guardar(
        juego: juego,
        tiempoSegundos: tiempoSegundos,
        puntuacion: puntuacion,
      );
      state = state.copyWith(partidas: [partida, ...state.partidas]);
      return ResultadoGuardado.guardada;
    } on SesionExpiradaException {
      await ref.read(authControllerProvider.notifier).sesionExpirada();
      return ResultadoGuardado.sesionExpirada;
    } catch (_) {
      return ResultadoGuardado.fallo;
    }
  }
}
