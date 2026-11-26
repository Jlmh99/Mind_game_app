import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../data/partidas_repository.dart';
import '../auth/auth_controller.dart';
import '../partidas/guardado_en_curso.dart';
import 'crucigrama_model.dart';

/// Provider del Crucigrama. Es autoDispose (igual que el Sudoku): al salir de
/// la pantalla Riverpod lo destruye y ref.onDispose cancela el cronómetro.
final crucigramaControllerProvider =
    NotifierProvider.autoDispose<CrucigramaController, CrucigramaState>(
        CrucigramaController.new);

class CrucigramaController extends AutoDisposeNotifier<CrucigramaState>
    implements ControladorConPartidaEnCurso<CrucigramaState> {
  Timer? _timer;

  /// Partida en curso en Floor (Práctica 14). Inactivo si no hay DAO.
  late GuardadoEnCurso _guardado;

  /// true si en esta partida ya hubo jugadas (o se restauró una guardada).
  bool _hayProgreso = false;

  /// Último estado conocido (para guardarlo al destruir el provider).
  CrucigramaState? _ultimo;

  @override
  CrucigramaState build() {
    final dao = ref.read(partidaEnCursoDaoProvider);
    _guardado = GuardadoEnCurso(
      dao: dao,
      // La sesión solo se lee si hay persistencia (pruebas sin BD: igual que antes).
      correo: dao == null ? null : ref.read(authControllerProvider).correo,
      juego: juegoCrucigrama,
    );
    listenSelf((_, nuevo) => _ultimo = nuevo);
    ref.onDispose(() {
      _detenerTimer();
      _guardarAlSalir();
    });
    _iniciarTimer();
    return CrucigramaState.nuevo();
  }

  // ---------------- Cronómetro ----------------

  void _iniciarTimer() {
    _detenerTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(segundos: state.segundos + 1);
    });
  }

  void _detenerTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ---------------- Selección ----------------

  /// Toca una casilla. Si ya estaba seleccionada, cambia la dirección
  /// (solo si por ahí pasa una palabra en la otra dirección).
  void seleccionarCasilla(int fila, int col) {
    if (state.terminado || state.esBloque(fila, col)) return;

    final orientaciones = palabrasEn(fila, col).map((p) => p.orientacion).toSet();
    final mismaCasilla = state.filaSel == fila && state.colSel == col;

    var orientacion = state.orientacion;
    if (mismaCasilla) {
      final otra = _contraria(orientacion);
      if (orientaciones.contains(otra)) orientacion = otra;
    } else if (!orientaciones.contains(orientacion)) {
      // La casilla no tiene palabra en la dirección actual: usamos la que tenga.
      orientacion = orientaciones.first;
    }

    state = state.copyWith(filaSel: fila, colSel: col, orientacion: orientacion);
  }

  /// Toca una pista: selecciona su palabra y se coloca en la primera
  /// casilla vacía editable (o en la primera editable si ya está llena).
  void seleccionarPalabra(PalabraCrucigrama p) {
    if (state.terminado) return;
    final editables =
        p.posiciones.where((pos) => !state.esFija(pos.$1, pos.$2)).toList();
    final destino = editables.firstWhere(
      (pos) => (state.tablero[pos.$1][pos.$2] ?? '').isEmpty,
      orElse: () => editables.isNotEmpty ? editables.first : p.posiciones.first,
    );
    state = state.copyWith(
      filaSel: destino.$1,
      colSel: destino.$2,
      orientacion: p.orientacion,
    );
  }

  // ---------------- Escritura ----------------

  /// Escribe [letra] en la casilla seleccionada y avanza a la siguiente
  /// casilla de la palabra. Si la letra no coincide, cuenta como error.
  void escribir(String letra) {
    if (state.terminado || !state.haySeleccion) return;
    letra = letra.toUpperCase();

    // Si la casilla seleccionada es fija, se escribe en la siguiente editable.
    Posicion? destino = (state.filaSel!, state.colSel!);
    if (state.esFija(destino.$1, destino.$2)) destino = _siguiente(destino);
    if (destino == null) return;
    final (f, c) = destino;

    final nuevo = copiarTableroCrucigrama(state.tablero);
    final cambio = nuevo[f][c] != letra;
    nuevo[f][c] = letra;

    final esError = cambio && hayError(nuevo, f, c);
    final siguiente = _siguiente(destino) ?? destino;

    state = state.copyWith(
      tablero: nuevo,
      errores: esError ? state.errores + 1 : state.errores,
      filaSel: siguiente.$1,
      colSel: siguiente.$2,
    );
    _hayProgreso = true;

    // Terminado: se para el tiempo y se borra la partida guardada.
    if (crucigramaCompleto(state.tablero)) {
      _detenerTimer();
      state = state.copyWith(terminado: true);
      unawaited(borrarEnCurso());
    }
    guardarEnCurso(); // no hace nada si la partida terminó
  }

  /// Borra la letra de la casilla seleccionada; si ya está vacía,
  /// retrocede a la casilla anterior de la palabra y la borra.
  void borrar() {
    if (state.terminado || !state.haySeleccion) return;
    Posicion? destino = (state.filaSel!, state.colSel!);

    final vacia = (state.tablero[destino.$1][destino.$2] ?? '').isEmpty;
    if (vacia || state.esFija(destino.$1, destino.$2)) {
      destino = _anterior(destino);
    }
    if (destino == null) return;

    final nuevo = copiarTableroCrucigrama(state.tablero);
    nuevo[destino.$1][destino.$2] = '';
    state = state.copyWith(
      tablero: nuevo,
      filaSel: destino.$1,
      colSel: destino.$2,
    );
    _hayProgreso = true;
    guardarEnCurso();
  }

  /// Vuelve al tablero inicial; tiempo y errores regresan a 0
  /// (equivale a generarNuevo() de la web, que solo tiene un crucigrama).
  /// La partida guardada (si había) ya no sirve: se borra.
  void reiniciar() {
    _hayProgreso = false;
    unawaited(_guardado.borrar());
    state = CrucigramaState.nuevo();
    _iniciarTimer();
  }

  // ---------------- Partida en curso (Práctica 14) ----------------

  @override
  bool get persistenciaActiva => _guardado.activo;

  @override
  Future<CrucigramaState?> partidaGuardada() async {
    final datos = await _guardado.leer();
    if (datos == null) return null;
    try {
      return CrucigramaState.fromJson(datos);
    } on FormatException {
      await _guardado.borrar(); // corrupta: se descarta
      return null;
    }
  }

  @override
  void restaurar(CrucigramaState guardada) {
    _guardado.cancelar(); // ninguna jugada previa debe pisar la guardada
    state = guardada;
    _hayProgreso = true;
    _iniciarTimer(); // continúa desde guardada.segundos
  }

  @override
  Future<void> guardarEnCurso({bool inmediato = false}) async {
    if (!_hayProgreso || state.terminado) return;
    if (inmediato) {
      await _guardado.guardarAhora(state.toJson(), state.segundos, state.errores);
    } else {
      _guardado.programar(() =>
          (estado: state.toJson(), segundos: state.segundos, errores: state.errores));
    }
  }

  @override
  Future<void> borrarEnCurso() => _guardado.borrar();

  @override
  void pausar() => _detenerTimer();

  @override
  void reanudar() {
    if (!state.terminado && _timer == null) _iniciarTimer();
  }

  /// Al destruir el provider (salir del juego): si la partida quedó a medias
  /// se guarda ya; si no, solo se cancela lo pendiente.
  void _guardarAlSalir() {
    final e = _ultimo;
    if (_hayProgreso && e != null && !e.terminado) {
      unawaited(_guardado.guardarAhora(e.toJson(), e.segundos, e.errores));
    } else {
      _guardado.cancelar();
    }
  }

  // ---------------- Auxiliares ----------------

  Orientacion _contraria(Orientacion o) => o == Orientacion.horizontal
      ? Orientacion.vertical
      : Orientacion.horizontal;

  /// Siguiente casilla editable de la palabra seleccionada (null si no hay).
  Posicion? _siguiente(Posicion desde) {
    final p = state.palabraSeleccionada;
    if (p == null) return null;
    final i = p.posiciones.indexOf(desde);
    for (final pos in p.posiciones.skip(i + 1)) {
      if (!state.esFija(pos.$1, pos.$2)) return pos;
    }
    return null;
  }

  /// Casilla editable anterior de la palabra seleccionada (null si no hay).
  Posicion? _anterior(Posicion desde) {
    final p = state.palabraSeleccionada;
    if (p == null) return null;
    final i = p.posiciones.indexOf(desde);
    for (final pos in p.posiciones.take(i).toList().reversed) {
      if (!state.esFija(pos.$1, pos.$2)) return pos;
    }
    return null;
  }
}
