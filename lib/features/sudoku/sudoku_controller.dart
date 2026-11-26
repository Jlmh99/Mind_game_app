import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../data/partidas_repository.dart';
import '../auth/auth_controller.dart';
import '../partidas/guardado_en_curso.dart';
import 'sudoku_model.dart';

/// Provider del Sudoku. Es autoDispose: al salir de la pantalla nadie lo
/// escucha, Riverpod lo destruye y ref.onDispose cancela el cronómetro.
final sudokuControllerProvider =
    NotifierProvider.autoDispose<SudokuController, SudokuState>(
        SudokuController.new);

class SudokuController extends AutoDisposeNotifier<SudokuState>
    implements ControladorConPartidaEnCurso<SudokuState> {
  Timer? _timer;
  final _random = Random();

  /// Partida en curso en Floor (Práctica 14). Inactivo si no hay DAO.
  late GuardadoEnCurso _guardado;

  /// true si en esta partida ya hubo jugadas (o se restauró una guardada):
  /// solo entonces vale la pena guardarla.
  bool _hayProgreso = false;

  /// Último estado conocido (para guardarlo al destruir el provider).
  SudokuState? _ultimo;

  @override
  SudokuState build() {
    final dao = ref.read(partidaEnCursoDaoProvider);
    _guardado = GuardadoEnCurso(
      dao: dao,
      // La sesión solo se lee si hay persistencia: las pruebas que montan el
      // juego sin base de datos siguen funcionando igual que antes.
      correo: dao == null ? null : ref.read(authControllerProvider).correo,
      juego: juegoSudoku,
    );
    listenSelf((_, nuevo) => _ultimo = nuevo);

    // Pase lo que pase, al destruir el provider se cancela el Timer
    // (y si la partida quedó a medias, se guarda).
    ref.onDispose(() {
      _detenerTimer();
      _guardarAlSalir();
    });
    _iniciarTimer();
    return SudokuState.nuevo(_random.nextInt(tablerosSudoku.length));
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

  // ---------------- Acciones del usuario ----------------

  /// Selecciona una celda (también las fijas, para resaltar números iguales).
  void seleccionar(int fila, int col) {
    if (state.terminado) return;
    state = state.copyWith(filaSel: fila, colSel: col);
  }

  /// Coloca [numero] (1-9) en la celda seleccionada.
  /// Si el número entra en conflicto con las reglas, cuenta como error.
  void colocar(int numero) {
    if (!_puedeEditar()) return;
    final f = state.filaSel!, c = state.colSel!;
    if (state.tablero[f][c] == numero) return; // mismo número: no cambia nada

    final nuevo = copiarTablero(state.tablero);
    nuevo[f][c] = numero;

    final esError = hayConflicto(nuevo, f, c);
    state = state.copyWith(
      tablero: nuevo,
      errores: esError ? state.errores + 1 : state.errores,
    );
    _hayProgreso = true;

    _revisarVictoria();
    guardarEnCurso(); // no hace nada si la partida terminó
  }

  /// Borra el número de la celda seleccionada.
  void borrar() {
    if (!_puedeEditar()) return;
    final f = state.filaSel!, c = state.colSel!;
    if (state.tablero[f][c] == 0) return;

    final nuevo = copiarTablero(state.tablero);
    nuevo[f][c] = 0;
    state = state.copyWith(tablero: nuevo);
    _hayProgreso = true;
    guardarEnCurso();
  }

  /// Vuelve al tablero inicial; tiempo y errores regresan a 0.
  /// La partida guardada (si había) ya no sirve: se borra.
  void reiniciar() {
    _empezarDeCero(state.indiceTablero);
  }

  /// Empieza otro tablero distinto al actual.
  void nuevo() {
    var indice = state.indiceTablero;
    if (tablerosSudoku.length > 1) {
      while (indice == state.indiceTablero) {
        indice = _random.nextInt(tablerosSudoku.length);
      }
    }
    _empezarDeCero(indice);
  }

  // ---------------- Partida en curso (Práctica 14) ----------------

  @override
  bool get persistenciaActiva => _guardado.activo;

  @override
  Future<SudokuState?> partidaGuardada() async {
    final datos = await _guardado.leer();
    if (datos == null) return null;
    try {
      return SudokuState.fromJson(datos);
    } on FormatException {
      await _guardado.borrar(); // corrupta: se descarta
      return null;
    }
  }

  @override
  void restaurar(SudokuState guardada) {
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

  // ---------------- Auxiliares ----------------

  void _empezarDeCero(int indice) {
    _hayProgreso = false;
    unawaited(_guardado.borrar());
    state = SudokuState.nuevo(indice);
    _iniciarTimer();
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

  /// Solo se edita si hay celda seleccionada, no es fija y el juego sigue.
  bool _puedeEditar() =>
      !state.terminado &&
      state.haySeleccion &&
      !state.esFija(state.filaSel!, state.colSel!);

  /// Si el tablero quedó lleno y sin conflictos, se termina, se para el tiempo
  /// y se borra la partida guardada (ya no hay nada que continuar).
  void _revisarVictoria() {
    if (estaCompleto(state.tablero)) {
      _detenerTimer();
      state = state.copyWith(terminado: true);
      unawaited(borrarEnCurso());
    }
  }
}
