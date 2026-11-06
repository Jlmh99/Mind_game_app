import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/features/crucigrama/crucigrama_page.dart';

void main() {
  testWidgets('la pantalla cabe en un celular y recibe letras del teclado',
      (tester) async {
    // Celular pequeño en vertical (360 x 640 dp).
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: CrucigramaPage()),
    ));

    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('Horizontales'), findsOneWidget);
    expect(find.text('Verticales'), findsOneWidget);

    // Toca la pista de CASA: se selecciona y la pista aparece arriba también.
    await tester.tap(find.text('Lugar donde vives con tu familia.'));
    await tester.pump();
    expect(find.text('Lugar donde vives con tu familia.'), findsNWidgets(2));

    // Simula el teclado del celular: el campo invisible tiene un espacio
    // centinela; escribir "a" lo convierte en " a".
    final campo = find.byType(TextField);
    await tester.enterText(campo, ' a');
    await tester.pump();
    expect(find.text('A'), findsOneWidget);

    // Borrar deja el campo vacío -> se borra la letra anterior.
    await tester.enterText(campo, '');
    await tester.pump();
    expect(find.text('A'), findsNothing);

    // Al quitar la pantalla se destruye el provider y se cancela el Timer.
    await tester.pumpWidget(const SizedBox());
  });
}
