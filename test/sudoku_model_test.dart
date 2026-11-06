import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/features/sudoku/sudoku_controller.dart';
import 'package:mindgames_app/features/sudoku/sudoku_model.dart';

/// Resuelve un tablero por backtracking. Solo se usa en las pruebas para
/// obtener la solución y poder "jugar" una partida completa.
bool resolver(List<List<int>> t) {
  for (var f = 0; f < 9; f++) {
    for (var c = 0; c < 9; c++) {
      if (t[f][c] != 0) continue;
      for (var n = 1; n <= 9; n++) {
        t[f][c] = n;
        if (!hayConflicto(t, f, c) && resolver(t)) return true;
      }
      t[f][c] = 0;
      return false;
    }
  }
  return true;
}

/// Crea un contenedor de Riverpod y mantiene vivo el provider autoDispose.
ProviderContainer crearContenedor() {
  final contenedor = ProviderContainer();
  contenedor.listen(sudokuControllerProvider, (_, _) {});
  return contenedor;
}

void main() {
  group('reglas del Sudoku (modelo)', () {
    test('los tableros predefinidos no tienen conflictos iniciales', () {
      for (final t in tablerosSudoku) {
        for (var f = 0; f < 9; f++) {
          for (var c = 0; c < 9; c++) {
            expect(hayConflicto(t, f, c), isFalse);
          }
        }
      }
    });

    test('detecta conflictos en fila, columna y bloque', () {
      final t = copiarTablero(tablerosSudoku[0]);
      t[0][2] = 5; // ya hay un 5 en la fila 0
      expect(hayConflicto(t, 0, 2), isTrue);

      final t2 = copiarTablero(tablerosSudoku[0]);
      t2[2][0] = 6; // ya hay un 6 en la columna 0
      expect(hayConflicto(t2, 2, 0), isTrue);

      final t3 = copiarTablero(tablerosSudoku[0]);
      t3[1][1] = 9; // ya hay un 9 en el bloque superior izquierdo
      expect(hayConflicto(t3, 1, 1), isTrue);
    });

    test('estaCompleto solo es true con el tablero lleno y válido', () {
      final t = copiarTablero(tablerosSudoku[0]);
      expect(estaCompleto(t), isFalse); // tiene vacíos
      expect(resolver(t), isTrue);
      expect(estaCompleto(t), isTrue);
    });

    test('puntuación = max(0, 1000 - segundos - 50 * errores)', () {
      expect(calcularPuntuacion(120, 2), 780);
      expect(calcularPuntuacion(0, 0), 1000);
      expect(calcularPuntuacion(900, 5), 0); // nunca negativa
    });

    test('formatoTiempo usa m:ss', () {
      expect(formatoTiempo(0), '0:00');
      expect(formatoTiempo(65), '1:05');
    });
  });

  group('SudokuController', () {
    testWidgets('las celdas fijas no se pueden editar', (tester) async {
      final contenedor = crearContenedor();
      final ctrl = contenedor.read(sudokuControllerProvider.notifier);
      final inicial = contenedor.read(sudokuControllerProvider).inicial;

      // Busca una celda fija e intenta cambiarla.
      final f = inicial.indexWhere((fila) => fila.any((v) => v != 0));
      final c = inicial[f].indexWhere((v) => v != 0);
      ctrl.seleccionar(f, c);
      ctrl.colocar(inicial[f][c] == 1 ? 2 : 1);
      ctrl.borrar();

      expect(contenedor.read(sudokuControllerProvider).tablero[f][c],
          inicial[f][c]);
      contenedor.dispose();
    });

    testWidgets('un número en conflicto cuenta como error', (tester) async {
      final contenedor = crearContenedor();
      final ctrl = contenedor.read(sudokuControllerProvider.notifier);
      final inicial = contenedor.read(sudokuControllerProvider).inicial;

      // Celda vacía de la fila 0 y un número que ya existe en esa fila.
      final c = inicial[0].indexOf(0);
      final repetido = inicial[0].firstWhere((v) => v != 0);
      ctrl.seleccionar(0, c);
      ctrl.colocar(repetido);

      final estado = contenedor.read(sudokuControllerProvider);
      expect(estado.errores, 1);
      expect(estado.esConflicto(0, c), isTrue);
      contenedor.dispose();
    });

    testWidgets('el cronómetro avanza, se detiene al ganar y se cancela al salir',
        (tester) async {
      final contenedor = crearContenedor();
      final ctrl = contenedor.read(sudokuControllerProvider.notifier);

      await tester.pump(const Duration(seconds: 3));
      expect(contenedor.read(sudokuControllerProvider).segundos, 3);

      // Llena el tablero con la solución correcta.
      final solucion =
          copiarTablero(contenedor.read(sudokuControllerProvider).inicial);
      resolver(solucion);
      final inicial = contenedor.read(sudokuControllerProvider).inicial;
      for (var f = 0; f < 9; f++) {
        for (var c = 0; c < 9; c++) {
          if (inicial[f][c] == 0) {
            ctrl.seleccionar(f, c);
            ctrl.colocar(solucion[f][c]);
          }
        }
      }

      final alGanar = contenedor.read(sudokuControllerProvider);
      expect(alGanar.terminado, isTrue);
      expect(alGanar.errores, 0);
      expect(alGanar.puntuacion, 1000 - 3);

      // El tiempo ya no avanza después de ganar.
      await tester.pump(const Duration(seconds: 5));
      expect(contenedor.read(sudokuControllerProvider).segundos, 3);

      // Al destruir el provider no deben quedar Timers pendientes
      // (testWidgets falla si queda alguno activo).
      contenedor.dispose();
    });

    testWidgets('al destruir el provider se cancela el Timer', (tester) async {
      final contenedor = crearContenedor();
      await tester.pump(const Duration(seconds: 2));
      contenedor.dispose(); // simula salir de la pantalla a mitad del juego
    });
  });
}
