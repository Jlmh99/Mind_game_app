import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sesion_expirada_exception.dart';
import '../../data/partidas_repository.dart';
import '../auth/auth_controller.dart';
import 'cola_puntuaciones.dart';

/// Resultado de intentar guardar una partida (para decidir qué mostrar).
/// pendiente: no se pudo enviar (sin red o 5xx) y quedó en la cola del
/// teléfono para reenviarse al reconectar (Práctica 14).
enum ResultadoGuardado { guardada, pendiente, fallo, sesionExpirada }

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
    // Si ya hay puntuaciones esperando en la cola, esta se pone al final y se
    // envía con la misma sincronización: así solo la cola envía (un POST a la
    // vez) y el servidor las recibe en el orden en que se jugaron.
    final cola = ref.read(colaPuntuacionesProvider.notifier);
    if (cola.activa && await cola.pendientesActuales() > 0) {
      return _guardarDetrasDeLaCola(cola, juego, tiempoSegundos, puntuacion);
    }
    try {
      final partida = await _repo.guardar(
        juego: juego,
        tiempoSegundos: tiempoSegundos,
        puntuacion: puntuacion,
      );
      state = state.copyWith(partidas: [partida, ...state.partidas]);
      // Hay conexión: se aprovecha para reenviar lo que estuviera en la cola.
      unawaited(ref.read(colaPuntuacionesProvider.notifier).sincronizar());
      return ResultadoGuardado.guardada;
    } on SesionExpiradaException {
      // Como antes: se cierra la sesión. La cola offline NO se toca.
      await ref.read(authControllerProvider.notifier).sesionExpirada();
      return ResultadoGuardado.sesionExpirada;
    } catch (e) {
      // Sin red o 5xx: se guarda en el teléfono para reenviarla al reconectar
      // (si hay cola). 400/422 y demás rechazos: fallo, sin encolar.
      if (seDebeEncolar(clasificarFalloGuardado(e)) && cola.activa) {
        await cola.encolar(juego: juego, tiempoSegundos: tiempoSegundos, puntuacion: puntuacion);
        return ResultadoGuardado.pendiente;
      }
      return ResultadoGuardado.fallo;
    }
  }

  Future<ResultadoGuardado> _guardarDetrasDeLaCola(
      ColaPuntuacionesController cola, String juego, int tiempoSegundos, int puntuacion) async {
    final id = await cola.encolar(juego: juego, tiempoSegundos: tiempoSegundos, puntuacion: puntuacion);
    // Si ya había una sincronización en curso, espera a esa (y repasa la cola).
    // OJO: después de este await no se usa ref: si la sincronización cerró la
    // sesión (401/403), este provider queda pendiente de reconstruirse.
    final r = await cola.sincronizar();
    if (r.sesionExpirada) {
      return ResultadoGuardado.sesionExpirada; // la partida queda en la cola
    }
    return switch (id == null ? null : cola.destinoDe(id)) {
      DestinoPendiente.enviada => ResultadoGuardado.guardada, // la lista ya se refrescó
      DestinoPendiente.descartada => ResultadoGuardado.fallo,
      null => ResultadoGuardado.pendiente,
    };
  }
}
