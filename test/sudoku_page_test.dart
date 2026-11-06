import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/features/sudoku/sudoku_page.dart';

void main() {
  testWidgets('la pantalla cabe en un celular pequeño y responde a toques',
      (tester) async {
    // Celular pequeño en vertical (360 x 640 dp).
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SudokuPage()),
    ));

    // Se ven cronómetro, errores y teclado (si algo desbordara, la prueba falla).
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('Errores: 0'), findsOneWidget);
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);

    // Toca la primera celda vacía (sin número) y luego un número del teclado.
    final celdasVacias = find.byWidgetPredicate(
        (w) => w is Container && w.child == null && w.alignment == Alignment.center);
    await tester.tap(celdasVacias.first);
    await tester.pump();

    final antes = find.text('4').evaluate().length;
    await tester.tap(find.widgetWithText(FilledButton, '4'));
    await tester.pump();
    expect(find.text('4').evaluate().length, antes + 1);

    // Al quitar la pantalla se destruye el provider y se cancela el Timer.
    await tester.pumpWidget(const SizedBox());
  });
}
