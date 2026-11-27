// Práctica 14: toJson / fromJson de SudokuState y CrucigramaState (ida y vuelta
// pasando por texto JSON, como queda en Floor).
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/features/crucigrama/crucigrama_model.dart';
import 'package:mindgames_app/features/sudoku/sudoku_model.dart';

Map<String, dynamic> porTexto(Map<String, dynamic> j) => jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

/// Primera celda vacía (editable) del tablero.
(int, int) primeraVacia(List<List<int>> t) {
  for (var f = 0; f < 9; f++) {
    for (var c = 0; c < 9; c++) {
      if (t[f][c] == 0) return (f, c);
    }
  }
  throw StateError('sin celdas vacías');
}

void main() {
  group('P14 serialización: SudokuState', () {
    test('P14-SER: ida y vuelta conserva tablero, selección, tiempo, errores e índice', () {
      final base = SudokuState.nuevo(1);
      final (f, c) = primeraVacia(base.tablero);
      final tablero = copiarTablero(base.tablero)..[f][c] = 7;
      final original = base.copyWith(tablero: tablero, filaSel: f, colSel: c, segundos: 125, errores: 3);

      final copia = SudokuState.fromJson(porTexto(original.toJson()));

      expect(copia.indiceTablero, 1);
      expect(copia.tablero, original.tablero);
      expect(copia.tablero[f][c], 7);
      expect(copia.filaSel, f);
      expect(copia.colSel, c);
      expect(copia.segundos, 125);
      expect(copia.errores, 3);
      expect(copia.terminado, isFalse);
      // El tablero inicial NO viaja en el JSON: se reconstruye de la constante.
      expect(original.toJson().containsKey('inicial'), isFalse);
      expect(copia.inicial, tablerosSudoku[1]);
      expect(copia.esFija(f, c), isFalse); // la celda que escribió el usuario sigue editable
    });

    test('P14-SER: sin selección se conserva como null', () {
      final copia = SudokuState.fromJson(porTexto(SudokuState.nuevo(0).toJson()));
      expect(copia.filaSel, isNull);
      expect(copia.colSel, isNull);
    });

    test('P14-SER: datos corruptos -> FormatException (índice inexistente o número fijo cambiado)', () {
      final j = porTexto(SudokuState.nuevo(0).toJson());
      expect(() => SudokuState.fromJson({...j, 'indiceTablero': 999}), throwsFormatException);

      // Cambiar un número fijo del tablero original no es válido.
      final tablero = (j['tablero'] as List).map((f) => List<int>.from(f as List)).toList();
      final (f, c) = () {
        for (var f = 0; f < 9; f++) {
          for (var c = 0; c < 9; c++) {
            if (tablerosSudoku[0][f][c] != 0) return (f, c);
          }
        }
        throw StateError('sin fijas');
      }();
      tablero[f][c] = tablerosSudoku[0][f][c] == 9 ? 1 : tablerosSudoku[0][f][c] + 1;
      expect(() => SudokuState.fromJson({...j, 'tablero': tablero}), throwsFormatException);
    });
  });

  group('P14 serialización: CrucigramaState', () {
    test('P14-SER: ida y vuelta conserva letras, bloques (null), selección, orientación, tiempo y errores', () {
      final tablero = copiarTableroCrucigrama(tableroInicialCrucigrama)
        ..[0][1] = 'A'
        ..[0][2] = 'X'; // letra equivocada: también se guarda tal cual
      final original = CrucigramaState(
        tablero: tablero,
        filaSel: 0,
        colSel: 2,
        orientacion: Orientacion.vertical,
        segundos: 47,
        errores: 2,
      );

      final copia = CrucigramaState.fromJson(porTexto(original.toJson()));

      expect(copia.tablero, original.tablero);
      expect(copia.esBloque(1, 1), isTrue); // los bloques negros siguen siendo null
      expect(copia.filaSel, 0);
      expect(copia.colSel, 2);
      expect(copia.orientacion, Orientacion.vertical);
      expect(copia.segundos, 47);
      expect(copia.errores, 2);
      expect(copia.terminado, isFalse);
    });

    test('P14-SER: datos corruptos -> FormatException (bloque negro con letra o letra fija cambiada)', () {
      final j = porTexto(CrucigramaState.nuevo().toJson());
      final conLetraEnBloque = (j['tablero'] as List).map((f) => List<String?>.from(f as List)).toList()
        ..[1][1] = 'Z';
      expect(() => CrucigramaState.fromJson({...j, 'tablero': conLetraEnBloque}), throwsFormatException);

      final fijaCambiada = (j['tablero'] as List).map((f) => List<String?>.from(f as List)).toList()
        ..[0][0] = 'Q'; // la 'C' inicial es fija
      expect(() => CrucigramaState.fromJson({...j, 'tablero': fijaCambiada}), throwsFormatException);
    });
  });
}
