// Práctica 14: el botón "atrás" de Android en el diálogo "… sin terminar" NO
// debe cerrar el diálogo ni borrar la partida guardada (hallazgo de la prueba en
// el teléfono: antes se trataba como "Nueva partida" y la borraba).
// Solo "Nueva partida" borra.
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

PartidaEnCurso guardada(String juego, Map<String, dynamic> estado) => PartidaEnCurso(
      correo: _correo,
      juego: juego,
      estadoJson: jsonEncode(estado),
      segundos: estado['segundos'] as int,
      errores: estado['errores'] as int,
      actualizadoEn: 1,
    );

/// Monta la pantalla dentro de una ruta (como en la app: Inicio -> juego),
/// para que "atrás" tenga a dónde regresar si el diálogo lo dejara pasar.
Future<void> montar(WidgetTester tester, Widget juego, DaoEnMemoria dao) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      partidaEnCursoDaoProvider.overrideWithValue(dao),
      authControllerProvider.overrideWith(() => AuthFalso(_correo)),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => juego)),
              child: const Text('Inicio: abrir juego'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('Inicio: abrir juego'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400)); // transición + post-frame + diálogo
  await tester.pump();
}

/// Simula el botón "atrás" de Android (el mismo mensaje que manda el sistema).
Future<void> atrasDeAndroid(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final (nombre, juego, clave, estado, pantalla) in [
    (
      'Sudoku',
      'SUDOKU',
      (_correo, 'SUDOKU'),
      SudokuState.nuevo(0).copyWith(segundos: 160, errores: 15).toJson(),
      const SudokuPage() as Widget,
    ),
    (
      'Crucigrama',
      'CRUCIGRAMA',
      (_correo, 'CRUCIGRAMA'),
      CrucigramaState.nuevo().copyWith(segundos: 9, errores: 0).toJson(),
      const CrucigramaPage() as Widget,
    ),
  ]) {
    testWidgets('P14-ATRAS: $nombre: "atrás" con el diálogo abierto no lo cierra ni borra la partida guardada',
        (tester) async {
      final dao = DaoEnMemoria()..filas[clave] = guardada(juego, estado);
      await montar(tester, pantalla, dao);
      expect(find.text('$nombre sin terminar'), findsOneWidget);

      await atrasDeAndroid(tester);
      expect(find.text('$nombre sin terminar'), findsOneWidget, reason: 'el diálogo sigue visible');
      expect(dao.filas.containsKey(clave), isTrue, reason: 'la fila de partida_en_curso sigue ahí');

      await atrasDeAndroid(tester); // ni insistiendo
      expect(find.text('$nombre sin terminar'), findsOneWidget);
      expect(dao.filas.containsKey(clave), isTrue);

      // Solo "Nueva partida" la borra.
      await tester.tap(find.text('Nueva partida'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(dao.filas.containsKey(clave), isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
