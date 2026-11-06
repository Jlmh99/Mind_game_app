import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/features/crucigrama/crucigrama_controller.dart';
import 'package:mindgames_app/features/crucigrama/crucigrama_model.dart';

/// Busca una palabra del crucigrama por su texto.
PalabraCrucigrama palabra(String texto) =>
    palabrasCrucigrama.firstWhere((p) => p.palabra == texto);

/// Contenedor de Riverpod que mantiene vivo el provider autoDispose.
ProviderContainer crearContenedor() {
  final contenedor = ProviderContainer();
  contenedor.listen(crucigramaControllerProvider, (_, _) {});
  return contenedor;
}

void main() {
  group('reglas del Crucigrama (modelo)', () {
    test('las palabras coinciden en sus cruces', () {
      // Cada casilla compartida debe pedir la misma letra en ambas palabras.
      for (final p in palabrasCrucigrama) {
        for (var i = 0; i < p.posiciones.length; i++) {
          final (f, c) = p.posiciones[i];
          for (final otra in palabrasEn(f, c)) {
            final j = otra.posiciones.indexOf((f, c));
            expect(otra.palabra[j], p.palabra[i]);
          }
        }
      }
    });

    test('hayError marca letras que no coinciden (sin importar mayúsculas)', () {
      final t = copiarTableroCrucigrama(tableroInicialCrucigrama);
      t[0][1] = 'a'; // CASA lleva A -> correcto aunque sea minúscula
      expect(hayError(t, 0, 1), isFalse);
      t[0][1] = 'X';
      expect(hayError(t, 0, 1), isTrue);
      expect(hayError(t, 0, 2), isFalse); // vacía no es error
    });

    test('una palabra es correcta solo cuando está completa y bien escrita', () {
      final t = copiarTableroCrucigrama(tableroInicialCrucigrama);
      t[0][1] = 'A';
      t[0][2] = 'S';
      expect(palabraCorrecta(t, palabra('CASA')), isFalse); // incompleta
      t[0][3] = 'A';
      expect(palabraCorrecta(t, palabra('CASA')), isTrue);
      expect(crucigramaCompleto(t), isFalse); // faltan CLIMA e IRIS
    });

    test('puntuación = max(0, 1000 - segundos - 25 * errores)', () {
      expect(calcularPuntuacionCrucigrama(60, 4), 840);
      expect(calcularPuntuacionCrucigrama(990, 1), 0); // nunca negativa
    });
  });

  group('CrucigramaController', () {
    testWidgets('tocar de nuevo una casilla de cruce cambia la dirección',
        (tester) async {
      final contenedor = crearContenedor();
      final ctrl = contenedor.read(crucigramaControllerProvider.notifier);
      CrucigramaState estado() => contenedor.read(crucigramaControllerProvider);

      ctrl.seleccionarCasilla(2, 0); // cruce de IRIS (H) y CLIMA (V)
      expect(estado().palabraSeleccionada!.palabra, 'IRIS');
      ctrl.seleccionarCasilla(2, 0);
      expect(estado().palabraSeleccionada!.palabra, 'CLIMA');

      // En una casilla con una sola palabra no cambia la dirección.
      ctrl.seleccionarCasilla(2, 2);
      expect(estado().orientacion, Orientacion.horizontal);
      ctrl.seleccionarCasilla(2, 2);
      expect(estado().orientacion, Orientacion.horizontal);

      // Tocar un bloque negro no hace nada.
      ctrl.seleccionarCasilla(1, 1);
      expect((estado().filaSel, estado().colSel), (2, 2));
      contenedor.dispose();
    });

    testWidgets('tocar una pista salta la letra fija y escribir avanza',
        (tester) async {
      final contenedor = crearContenedor();
      final ctrl = contenedor.read(crucigramaControllerProvider.notifier);
      CrucigramaState estado() => contenedor.read(crucigramaControllerProvider);

      ctrl.seleccionarPalabra(palabra('CLIMA'));
      expect((estado().filaSel, estado().colSel), (1, 0)); // (0,0) es la C fija

      ctrl.escribir('l');
      expect(estado().tablero[1][0], 'L');
      expect((estado().filaSel, estado().colSel), (2, 0));
      contenedor.dispose();
    });

    testWidgets('la letra fija no se edita y los errores se cuentan',
        (tester) async {
      final contenedor = crearContenedor();
      final ctrl = contenedor.read(crucigramaControllerProvider.notifier);
      CrucigramaState estado() => contenedor.read(crucigramaControllerProvider);

      ctrl.seleccionarCasilla(0, 0); // C fija, dirección horizontal
      ctrl.escribir('X'); // se escribe en la siguiente casilla (0,1)
      expect(estado().tablero[0][0], 'C');
      expect(estado().tablero[0][1], 'X');
      expect(estado().errores, 1);

      // Borrar retrocede y limpia la casilla anterior.
      ctrl.borrar();
      expect(estado().tablero[0][1], '');
      contenedor.dispose();
    });

    testWidgets('completar el crucigrama detiene el tiempo y calcula puntos',
        (tester) async {
      final contenedor = crearContenedor();
      final ctrl = contenedor.read(crucigramaControllerProvider.notifier);
      CrucigramaState estado() => contenedor.read(crucigramaControllerProvider);

      await tester.pump(const Duration(seconds: 10));

      ctrl.seleccionarPalabra(palabra('CASA'));
      for (final l in 'ASA'.split('')) {
        ctrl.escribir(l);
      }
      ctrl.seleccionarPalabra(palabra('CLIMA'));
      for (final l in 'LIMA'.split('')) {
        ctrl.escribir(l);
      }
      ctrl.seleccionarPalabra(palabra('IRIS'));
      for (final l in 'RIS'.split('')) {
        ctrl.escribir(l);
      }

      expect(estado().terminado, isTrue);
      expect(estado().puntuacion, 1000 - 10);

      await tester.pump(const Duration(seconds: 5));
      expect(estado().segundos, 10); // el cronómetro se detuvo

      contenedor.dispose(); // no deben quedar Timers activos
    });
  });
}
