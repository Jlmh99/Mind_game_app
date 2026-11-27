// Práctica 14: guardado de la partida en curso desde los controllers
// (debounce, borrar al terminar, restaurar con el cronómetro, dos usuarios).
// Reloj falso (fakeAsync) + DAO en memoria (DaoEnMemoria).
import 'dart:convert';
// fake_async llega con flutter_test (que fija su versión); no se declara en pubspec.yaml.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/core/providers.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/features/crucigrama/crucigrama_controller.dart';
import 'package:mindgames_app/features/crucigrama/crucigrama_model.dart';
import 'package:mindgames_app/features/sudoku/sudoku_controller.dart';
import 'package:mindgames_app/features/sudoku/sudoku_model.dart';
import 'apoyo_p14.dart';

/// Backtracking simple para obtener la solución de un tablero (igual que en
/// sudoku_model_test.dart).
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

/// Contenedor con DAO en memoria y el usuario [correo]; mantiene vivo el
/// provider autoDispose de [juego] mientras dure la prueba.
ProviderContainer contenedor(DaoEnMemoria dao, String correo) => ProviderContainer(overrides: [
      partidaEnCursoDaoProvider.overrideWithValue(dao),
      authControllerProvider.overrideWith(() => AuthFalso(correo)),
    ]);

(int, int) primeraVacia(SudokuState e) {
  for (var f = 0; f < 9; f++) {
    for (var c = 0; c < 9; c++) {
      if (!e.esFija(f, c) && e.tablero[f][c] == 0) return (f, c);
    }
  }
  throw StateError('sin celdas vacías');
}

void main() {
  group('P14 controllers: Sudoku', () {
    test('P14-CTL: una jugada se guarda ~500 ms después (debounce), no antes', () {
      fakeAsync((fa) {
        final dao = DaoEnMemoria();
        final c = contenedor(dao, 'a@ejemplo.com');
        final sub = c.listen(sudokuControllerProvider, (_, _) {});
        final ctrl = c.read(sudokuControllerProvider.notifier);

        final (f, col) = primeraVacia(c.read(sudokuControllerProvider));
        ctrl.seleccionar(f, col);
        ctrl.colocar(5);
        fa.elapse(const Duration(milliseconds: 400));
        expect(dao.filas, isEmpty, reason: 'antes de 500 ms no se guarda');

        // Otra jugada reinicia la espera: solo se guarda una vez, con la última.
        ctrl.colocar(6);
        fa.elapse(const Duration(milliseconds: 400));
        expect(dao.filas, isEmpty);
        fa.elapse(const Duration(milliseconds: 200));
        expect(dao.guardados, 1);
        final guardada = dao.filas[('a@ejemplo.com', 'SUDOKU')]!;
        final estado = SudokuState.fromJson(jsonDecode(guardada.estadoJson) as Map<String, dynamic>);
        expect(estado.tablero[f][col], 6);

        sub.close();
        c.dispose();
      });
    });

    test('P14-CTL: sin jugadas no se guarda nada (ni al pausar ni al salir)', () {
      fakeAsync((fa) {
        final dao = DaoEnMemoria();
        final c = contenedor(dao, 'a@ejemplo.com');
        final sub = c.listen(sudokuControllerProvider, (_, _) {});
        c.read(sudokuControllerProvider.notifier).guardarEnCurso(inmediato: true);
        fa.elapse(const Duration(seconds: 5));
        sub.close();
        fa.flushMicrotasks();
        c.dispose();
        fa.flushMicrotasks();
        expect(dao.guardados, 0);
      });
    });

    test('P14-CTL: al terminar el Sudoku se borra la partida guardada (y no se vuelve a guardar)', () {
      fakeAsync((fa) {
        final dao = DaoEnMemoria();
        final c = contenedor(dao, 'a@ejemplo.com');
        final sub = c.listen(sudokuControllerProvider, (_, _) {});
        final ctrl = c.read(sudokuControllerProvider.notifier);
        final inicio = c.read(sudokuControllerProvider);
        final solucion = copiarTablero(inicio.tablero);
        expect(resolver(solucion), isTrue);

        // Primera jugada y se deja guardar.
        final celdas = [
          for (var f = 0; f < 9; f++)
            for (var col = 0; col < 9; col++)
              if (!inicio.esFija(f, col)) (f, col),
        ];
        ctrl.seleccionar(celdas.first.$1, celdas.first.$2);
        ctrl.colocar(solucion[celdas.first.$1][celdas.first.$2]);
        fa.elapse(const Duration(seconds: 1));
        expect(dao.filas, hasLength(1));

        // Resto de jugadas hasta ganar.
        for (final (f, col) in celdas.skip(1)) {
          ctrl.seleccionar(f, col);
          ctrl.colocar(solucion[f][col]);
        }
        fa.elapse(const Duration(seconds: 2));
        expect(c.read(sudokuControllerProvider).terminado, isTrue);
        expect(dao.filas, isEmpty, reason: 'la partida terminada no debe quedar guardada');

        sub.close();
        c.dispose();
        fa.flushMicrotasks();
        expect(dao.filas, isEmpty, reason: 'tampoco al salir');
      });
    });

    test('P14-CTL: restaurar carga la partida y el cronómetro sigue desde los segundos guardados', () {
      fakeAsync((fa) {
        final dao = DaoEnMemoria();
        final c = contenedor(dao, 'a@ejemplo.com');
        final sub = c.listen(sudokuControllerProvider, (_, _) {});
        final ctrl = c.read(sudokuControllerProvider.notifier);

        final guardada = SudokuState.nuevo(1).copyWith(segundos: 120, errores: 4);
        ctrl.restaurar(guardada);
        expect(c.read(sudokuControllerProvider).segundos, 120);
        fa.elapse(const Duration(seconds: 3));
        expect(c.read(sudokuControllerProvider).segundos, 123);
        expect(c.read(sudokuControllerProvider).errores, 4);
        expect(c.read(sudokuControllerProvider).indiceTablero, 1);

        sub.close();
        c.dispose();
      });
    });

    test('P14-CTL: partidaGuardada lee lo guardado por el mismo usuario', () {
      fakeAsync((fa) {
        final dao = DaoEnMemoria();
        final c = contenedor(dao, 'a@ejemplo.com');
        final sub = c.listen(sudokuControllerProvider, (_, _) {});
        final ctrl = c.read(sudokuControllerProvider.notifier);
        final (f, col) = primeraVacia(c.read(sudokuControllerProvider));
        ctrl.seleccionar(f, col);
        ctrl.colocar(3);
        fa.elapse(const Duration(seconds: 2)); // debounce + 2 s de cronómetro

        SudokuState? leida;
        ctrl.partidaGuardada().then((v) => leida = v);
        fa.flushMicrotasks();
        expect(leida!.tablero[f][col], 3);
        expect(leida!.indiceTablero, c.read(sudokuControllerProvider).indiceTablero);
        sub.close();
        c.dispose();
      });
    });

    test('P14-CTL: salir del juego a mitad de partida la guarda ya (sin esperar el debounce)', () {
      fakeAsync((fa) {
        final dao = DaoEnMemoria();
        final c = contenedor(dao, 'a@ejemplo.com');
        final sub = c.listen(sudokuControllerProvider, (_, _) {});
        final ctrl = c.read(sudokuControllerProvider.notifier);
        final (f, col) = primeraVacia(c.read(sudokuControllerProvider));
        ctrl.seleccionar(f, col);
        ctrl.colocar(8);
        fa.elapse(const Duration(milliseconds: 100)); // aún no vence el debounce

        sub.close(); // nadie escucha -> autoDispose -> onDispose guarda
        fa.elapse(const Duration(milliseconds: 10));
        expect(dao.filas, hasLength(1));
        c.dispose();
      });
    });

    test('P14-CTL: "Reiniciar" borra la partida guardada', () {
      fakeAsync((fa) {
        final dao = DaoEnMemoria();
        final c = contenedor(dao, 'a@ejemplo.com');
        final sub = c.listen(sudokuControllerProvider, (_, _) {});
        final ctrl = c.read(sudokuControllerProvider.notifier);
        final (f, col) = primeraVacia(c.read(sudokuControllerProvider));
        ctrl.seleccionar(f, col);
        ctrl.colocar(2);
        fa.elapse(const Duration(seconds: 1));
        expect(dao.filas, hasLength(1));

        ctrl.reiniciar();
        fa.flushMicrotasks();
        expect(dao.filas, isEmpty);
        sub.close();
        c.dispose();
      });
    });

    test('P14-CTL: dos usuarios no se mezclan', () {
      fakeAsync((fa) {
        final dao = DaoEnMemoria(); // la misma base para los dos
        for (final (correo, numero) in [('a@ejemplo.com', 4), ('b@ejemplo.com', 9)]) {
          final c = contenedor(dao, correo);
          final sub = c.listen(sudokuControllerProvider, (_, _) {});
          final ctrl = c.read(sudokuControllerProvider.notifier);
          ctrl.restaurar(SudokuState.nuevo(0)); // mismo tablero para ambos
          final (f, col) = primeraVacia(c.read(sudokuControllerProvider));
          ctrl.seleccionar(f, col);
          ctrl.colocar(numero);
          fa.elapse(const Duration(seconds: 1));
          sub.close();
          c.dispose();
          fa.flushMicrotasks();
        }
        expect(dao.filas.keys, unorderedEquals([('a@ejemplo.com', 'SUDOKU'), ('b@ejemplo.com', 'SUDOKU')]));

        // Cada uno lee solo la suya.
        for (final (correo, numero) in [('a@ejemplo.com', 4), ('b@ejemplo.com', 9)]) {
          final c = contenedor(dao, correo);
          final sub = c.listen(sudokuControllerProvider, (_, _) {});
          SudokuState? leida;
          c.read(sudokuControllerProvider.notifier).partidaGuardada().then((v) => leida = v);
          fa.flushMicrotasks();
          final (f, col) = primeraVacia(SudokuState.nuevo(0));
          expect(leida!.tablero[f][col], numero, reason: correo);
          sub.close();
          c.dispose();
        }
      });
    });
  });

  group('P14 controllers: Crucigrama', () {
    test('P14-CTL: una letra se guarda con debounce; al completar se borra', () {
      fakeAsync((fa) {
        final dao = DaoEnMemoria();
        final c = contenedor(dao, 'a@ejemplo.com');
        final sub = c.listen(crucigramaControllerProvider, (_, _) {});
        final ctrl = c.read(crucigramaControllerProvider.notifier);

        final casa = palabrasCrucigrama.first; // CASA
        ctrl.seleccionarPalabra(casa);
        ctrl.escribir('A');
        fa.elapse(const Duration(seconds: 1));
        final guardada = dao.filas[('a@ejemplo.com', 'CRUCIGRAMA')]!;
        final estado = CrucigramaState.fromJson(jsonDecode(guardada.estadoJson) as Map<String, dynamic>);
        expect(estado.tablero[0][1], 'A');

        // Completar todas las palabras.
        for (final p in palabrasCrucigrama) {
          ctrl.seleccionarPalabra(p);
          for (var i = 0; i < p.palabra.length; i++) {
            final (f, col) = p.posiciones[i];
            if (c.read(crucigramaControllerProvider).esFija(f, col)) continue;
            ctrl.seleccionarCasilla(f, col);
            if (c.read(crucigramaControllerProvider).orientacion != p.orientacion) {
              ctrl.seleccionarCasilla(f, col); // segundo toque cambia la dirección
            }
            ctrl.escribir(p.palabra[i]);
          }
        }
        fa.elapse(const Duration(seconds: 2));
        expect(c.read(crucigramaControllerProvider).terminado, isTrue);
        expect(dao.filas, isEmpty);
        sub.close();
        c.dispose();
      });
    });

    test('P14-CTL: restaurar el Crucigrama y el cronómetro sigue', () {
      fakeAsync((fa) {
        final c = contenedor(DaoEnMemoria(), 'a@ejemplo.com');
        final sub = c.listen(crucigramaControllerProvider, (_, _) {});
        c.read(crucigramaControllerProvider.notifier).restaurar(CrucigramaState.nuevo().copyWith(segundos: 61, errores: 1));
        fa.elapse(const Duration(seconds: 4));
        expect(c.read(crucigramaControllerProvider).segundos, 65);
        expect(c.read(crucigramaControllerProvider).errores, 1);
        sub.close();
        c.dispose();
      });
    });
  });
}
