import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sudoku_model.dart';

/// Provider del Sudoku. Es autoDispose: al salir de la pantalla nadie lo
/// escucha, Riverpod lo destruye y ref.onDispose cancela el cronómetro.
final sudokuControllerProvider =
    NotifierProvider.autoDispose<SudokuController, SudokuState>(
        SudokuController.new);

class SudokuController extends AutoDisposeNotifier<SudokuState> {
  Timer? _timer;
  final _random = Random();

  @override
  SudokuState build() {
    // Pase lo que pase, al destruir el provider se cancela el Timer.
    ref.onDispose(_detenerTimer);
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

    _revisarVictoria();
  }

  /// Borra el número de la celda seleccionada.
  void borrar() {
    if (!_puedeEditar()) return;
    final f = state.filaSel!, c = state.colSel!;
    if (state.tablero[f][c] == 0) return;

    final nuevo = copiarTablero(state.tablero);
    nuevo[f][c] = 0;
    state = state.copyWith(tablero: nuevo);
  }

  /// Vuelve al tablero inicial; tiempo y errores regresan a 0.
  void reiniciar() {
    state = SudokuState.nuevo(state.indiceTablero);
    _iniciarTimer();
  }

  /// Empieza otro tablero distinto al actual.
  void nuevo() {
    var indice = state.indiceTablero;
    if (tablerosSudoku.length > 1) {
      while (indice == state.indiceTablero) {
        indice = _random.nextInt(tablerosSudoku.length);
      }
    }
    state = SudokuState.nuevo(indice);
    _iniciarTimer();
  }

  // ---------------- Auxiliares ----------------

  /// Solo se edita si hay celda seleccionada, no es fija y el juego sigue.
  bool _puedeEditar() =>
      !state.terminado &&
      state.haySeleccion &&
      !state.esFija(state.filaSel!, state.colSel!);

  /// Si el tablero quedó lleno y sin conflictos, se termina y se para el tiempo.
  void _revisarVictoria() {
    if (estaCompleto(state.tablero)) {
      _detenerTimer();
      state = state.copyWith(terminado: true);
    }
  }
}
