import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'crucigrama_model.dart';

/// Provider del Crucigrama. Es autoDispose (igual que el Sudoku): al salir de
/// la pantalla Riverpod lo destruye y ref.onDispose cancela el cronómetro.
final crucigramaControllerProvider =
    NotifierProvider.autoDispose<CrucigramaController, CrucigramaState>(
        CrucigramaController.new);

class CrucigramaController extends AutoDisposeNotifier<CrucigramaState> {
  Timer? _timer;

  @override
  CrucigramaState build() {
    ref.onDispose(_detenerTimer);
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

    if (crucigramaCompleto(state.tablero)) {
      _detenerTimer();
      state = state.copyWith(terminado: true);
    }
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
  }

  /// Vuelve al tablero inicial; tiempo y errores regresan a 0
  /// (equivale a generarNuevo() de la web, que solo tiene un crucigrama).
  void reiniciar() {
    state = CrucigramaState.nuevo();
    _iniciarTimer();
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
