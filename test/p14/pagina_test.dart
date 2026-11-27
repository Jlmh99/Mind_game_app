// Práctica 14: pantallas de juego con partida en curso.
//  - Ciclo de vida: al pasar a "paused" se guarda YA (sin esperar el debounce)
//    y el cronómetro se detiene; al volver a "resumed" sigue.
//  - Diálogo "Continuar partida / Nueva partida" al abrir con partida guardada.
//  - Sin partida guardada no aparece ningún diálogo.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/core/providers.dart';
import 'package:mindgames_app/data/local/partida_en_curso.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/features/crucigrama/crucigrama_model.dart';
import 'package:mindgames_app/features/crucigrama/crucigrama_page.dart';
import 'package:mindgames_app/features/sudoku/sudoku_model.dart';
import 'package:mindgames_app/features/sudoku/sudoku_page.dart';
import 'apoyo_p14.dart';

const _correo = 'a@ejemplo.com';

Future<void> montar(WidgetTester tester, Widget pantalla, DaoEnMemoria dao) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      partidaEnCursoDaoProvider.overrideWithValue(dao),
      authControllerProvider.overrideWith(() => AuthFalso(_correo)),
    ],
    child: MaterialApp(home: pantalla),
  ));
  await tester.pump(); // post-frame: busca la partida guardada
  await tester.pump();
}

Future<void> salir(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// Toca la primera celda vacía del Sudoku y el número 4 (como sudoku_page_test.dart).
Future<void> jugarUnaVez(WidgetTester tester) async {
  final celdasVacias = find.byWidgetPredicate(
      (w) => w is Container && w.child == null && w.alignment == Alignment.center);
  await tester.tap(celdasVacias.first);
  await tester.pump();
  await tester.tap(find.widgetWithText(FilledButton, '4'));
  await tester.pump();
}

PartidaEnCurso guardadaSudoku({int segundos = 120, int errores = 2}) {
  final e = SudokuState.nuevo(0).copyWith(segundos: segundos, errores: errores);
  return PartidaEnCurso(
    correo: _correo,
    juego: 'SUDOKU',
    estadoJson: jsonEncode(e.toJson()),
    segundos: segundos,
    errores: errores,
    actualizadoEn: 1,
  );
}

void main() {
  group('P14 pantallas: ciclo de vida', () {
    testWidgets('P14-UI: al pasar a "paused" se guarda ya y el cronómetro se pausa; "resumed" lo reanuda',
        (tester) async {
      final dao = DaoEnMemoria();
      await montar(tester, const SudokuPage(), dao);
      expect(find.byType(AlertDialog), findsNothing); // sin partida guardada: sin diálogo

      await jugarUnaVez(tester);
      expect(dao.filas, isEmpty, reason: 'el debounce todavía no vence');

      // Como en el teléfono: resumed -> inactive -> hidden -> paused
      // (AppLifecycleListener exige transiciones válidas).
      for (final e in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(e);
      }
      await tester.pump();
      expect(dao.filas.containsKey((_correo, 'SUDOKU')), isTrue, reason: 'se guarda inmediato al pausar');

      final enPausa = find.text('0:00');
      expect(enPausa, findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('0:00'), findsOneWidget, reason: 'en segundo plano el cronómetro no avanza');

      // Y de regreso: paused -> hidden -> inactive -> resumed.
      for (final e in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(e);
      }
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('0:02'), findsOneWidget, reason: 'al volver, el cronómetro sigue');

      await salir(tester);
    });
  });

  group('P14 pantallas: diálogo Continuar / Nueva', () {
    testWidgets('P14-UI: "Continuar partida" restaura tiempo y errores, y el cronómetro sigue',
        (tester) async {
      final dao = DaoEnMemoria()..filas[(_correo, 'SUDOKU')] = guardadaSudoku(segundos: 120, errores: 2);
      await montar(tester, const SudokuPage(), dao);

      expect(find.text('Sudoku sin terminar'), findsOneWidget);
      expect(find.textContaining('tiempo 2:00, errores: 2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3)); // con el diálogo abierto el tiempo no corre

      await tester.tap(find.text('Continuar partida'));
      await tester.pump(); // primer frame tras el toque
      await tester.pump(const Duration(milliseconds: 300)); // animación de cierre del diálogo
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('2:00'), findsOneWidget);
      expect(find.text('Errores: 2'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('2:03'), findsOneWidget);
      expect(dao.filas.containsKey((_correo, 'SUDOKU')), isTrue);
      await salir(tester);
    });

    testWidgets('P14-UI: "Nueva partida" borra la guardada y empieza de cero', (tester) async {
      final dao = DaoEnMemoria()..filas[(_correo, 'SUDOKU')] = guardadaSudoku();
      await montar(tester, const SudokuPage(), dao);

      await tester.tap(find.text('Nueva partida'));
      await tester.pump(); // primer frame tras el toque
      await tester.pump(const Duration(milliseconds: 300)); // animación de cierre del diálogo
      expect(find.byType(AlertDialog), findsNothing);
      expect(dao.filas, isEmpty);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('Errores: 0'), findsOneWidget);
      await salir(tester);
    });

    testWidgets('P14-UI: la partida guardada de OTRO usuario no se ofrece', (tester) async {
      final dao = DaoEnMemoria()
        ..filas[('b@ejemplo.com', 'SUDOKU')] = PartidaEnCurso(
            correo: 'b@ejemplo.com',
            juego: 'SUDOKU',
            estadoJson: jsonEncode(SudokuState.nuevo(0).toJson()),
            segundos: 50,
            errores: 0,
            actualizadoEn: 1);
      await montar(tester, const SudokuPage(), dao);
      expect(find.byType(AlertDialog), findsNothing);
      await salir(tester);
    });

    testWidgets('P14-UI: Crucigrama con partida guardada -> "Continuar partida"', (tester) async {
      final e = CrucigramaState.nuevo().copyWith(segundos: 75, errores: 1);
      final dao = DaoEnMemoria()
        ..filas[(_correo, 'CRUCIGRAMA')] = PartidaEnCurso(
            correo: _correo,
            juego: 'CRUCIGRAMA',
            estadoJson: jsonEncode(e.toJson()),
            segundos: 75,
            errores: 1,
            actualizadoEn: 1);
      await montar(tester, const CrucigramaPage(), dao);

      expect(find.text('Crucigrama sin terminar'), findsOneWidget);
      await tester.tap(find.text('Continuar partida'));
      await tester.pump(); // primer frame tras el toque
      await tester.pump(const Duration(milliseconds: 300)); // animación de cierre del diálogo
      expect(find.text('1:15'), findsOneWidget);
      await salir(tester);
    });
  });
}
