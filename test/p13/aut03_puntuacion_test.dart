// Práctica 13 · AUT-03 (unitaria): calcularPuntuacion (lib/features/sudoku/sudoku_model.dart).
// Fórmula: 1000 - segundos - 50 * errores, con mínimo 0.
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/features/sudoku/sudoku_model.dart';

void main() {
  group('AUT-03: calcularPuntuacion', () {
    test('AUT-03: valores válidos', () {
      expect(calcularPuntuacion(0, 0), 1000);
      expect(calcularPuntuacion(100, 2), 800);
      expect(calcularPuntuacion(245, 2), 655);
    });

    test('AUT-03: bordes (1000, 0) -> 0; (999, 0) -> 1; (1001, 0) -> 0; (0, 20) -> 0', () {
      expect(calcularPuntuacion(1000, 0), 0);
      expect(calcularPuntuacion(999, 0), 1);
      expect(calcularPuntuacion(1001, 0), 0);
      expect(calcularPuntuacion(0, 20), 0);
      expect(calcularPuntuacion(0, 21), 0);
    });

    // Lo esperado: la puntuación siempre queda entre 0 y 1000 (1000 = partida perfecta).
    // Comportamiento real medido antes de escribir la prueba: (-5, 0) -> 1005,
    // (0, -2) -> 1100, (-100, -100) -> 6100. Esta prueba FALLA hoy a propósito
    // (no se ajustó para que pase).
    test('AUT-03: tiempo o errores negativos -> la puntuación no supera 1000', () {
      for (final (segundos, errores) in [(-5, 0), (0, -2), (-100, -100)]) {
        final p = calcularPuntuacion(segundos, errores);
        expect(p, inInclusiveRange(0, 1000), reason: 'calcularPuntuacion($segundos, $errores) = $p');
      }
    });

    test('AUT-03: tiempo muy grande -> 0 (sin desbordamiento)', () {
      expect(calcularPuntuacion(1 << 40, 0), 0);
      expect(calcularPuntuacion(9007199254740991, 0), 0); // 2^53 - 1
    });
  });
}
