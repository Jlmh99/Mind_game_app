// Práctica 14 (rendimiento, hallazgo E3): el cronómetro del Crucigrama ya no
// reconstruye ni repinta toda la pantalla cada segundo.
//  - Tras un tic, el widget CrucigramaTablero es la MISMA instancia (identical):
//    la página no se reconstruyó, solo el marcador.
//  - Al escribir una letra sí se reconstruye (el tablero cambió).
//  - Tablero y pistas tienen su propio RepaintBoundary.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/features/crucigrama/crucigrama_page.dart';
import 'package:mindgames_app/features/crucigrama/widgets/crucigrama_pistas.dart';
import 'package:mindgames_app/features/crucigrama/widgets/crucigrama_tablero.dart';

Future<void> montar(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: CrucigramaPage())));
  await tester.pump();
}

CrucigramaTablero tablero(WidgetTester tester) => tester.widget<CrucigramaTablero>(find.byType(CrucigramaTablero));

void main() {
  testWidgets('P14-REND: un tic del cronómetro actualiza el reloj pero NO reconstruye el tablero', (tester) async {
    await montar(tester);
    expect(find.text('0:00'), findsOneWidget);
    final antes = tablero(tester);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:01'), findsOneWidget, reason: 'el reloj sí avanza');
    expect(identical(tablero(tester), antes), isTrue, reason: 'el tablero no se reconstruyó');

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0:03'), findsOneWidget);
    expect(identical(tablero(tester), antes), isTrue);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('P14-REND: al escribir una letra el tablero SÍ se reconstruye y la muestra', (tester) async {
    await montar(tester);
    final antes = tablero(tester);
    await tester.tap(find.text('Lugar donde vives con tu familia.')); // CASA
    await tester.pump();
    await tester.enterText(find.byType(TextField), ' a');
    await tester.pump();
    expect(identical(tablero(tester), antes), isFalse);
    expect(find.text('A'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('P14-REND: tablero y pistas tienen su propio RepaintBoundary', (tester) async {
    await montar(tester);
    for (final tipo in [CrucigramaTablero, CrucigramaPistas]) {
      // El padre DIRECTO debe ser un RepaintBoundary (no basta uno lejano,
      // como el que ya trae cada ruta).
      Widget? padreDirecto;
      tester.element(find.byType(tipo)).visitAncestorElements((e) {
        padreDirecto = e.widget;
        return false; // solo el primero
      });
      expect(padreDirecto, isA<RepaintBoundary>(), reason: '$tipo');
    }
    await tester.pumpWidget(const SizedBox());
  });
}
