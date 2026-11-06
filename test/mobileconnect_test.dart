import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/features/mobileconnect/canal_controller.dart';
import 'package:mindgames_app/features/mobileconnect/mobileconnect_model.dart';
import 'package:mindgames_app/features/mobileconnect/mobileconnect_page.dart';
import 'package:mindgames_app/features/mobileconnect/widgets/burbuja_mensaje.dart';

/// AuthController falso (el canal se reinicia si cambia el usuario).
class _AuthFalso extends AuthController {
  @override
  AuthState build() =>
      const AuthState(status: AuthStatus.autenticado, correo: 'a@b.com');
}

/// Hora fija para poder comprobar el formato HH:mm.
final _horaFija = DateTime(2026, 11, 6, 9, 5);

final _overrides = [
  authControllerProvider.overrideWith(_AuthFalso.new),
  relojProvider.overrideWithValue(() => _horaFija),
];

void main() {
  group('modelo y canal', () {
    late ProviderContainer c;
    setUp(() => c = ProviderContainer(overrides: _overrides));
    tearDown(() => c.dispose());

    CanalController canal() => c.read(canalProvider.notifier);
    CanalState estado() => c.read(canalProvider);

    test('la hora se muestra como HH:mm', () {
      final m = Mensaje(emisor: Dispositivo.a, texto: 'x', hora: _horaFija);
      expect(m.horaTexto, '09:05');
      expect(m.receptor, Dispositivo.b);
    });

    test('enviar agrega el mensaje con su emisor, texto recortado y hora', () {
      final m = canal().enviar('  hola B  ');
      expect(m, isNotNull);
      expect(estado().mensajes.single.emisor, Dispositivo.a);
      expect(estado().mensajes.single.texto, 'hola B');
      expect(estado().mensajes.single.hora, _horaFija);
    });

    test('no se envían mensajes vacíos ni con solo espacios', () {
      expect(canal().enviar(''), isNull);
      expect(canal().enviar('     '), isNull);
      expect(estado().mensajes, isEmpty);
    });

    test('contadores por dispositivo y limpiar historial', () {
      canal().enviar('1');
      canal().enviar('2');
      canal().cambiarEmisor(Dispositivo.b);
      canal().enviar('3');
      expect(estado().enviadosPor(Dispositivo.a), 2);
      expect(estado().enviadosPor(Dispositivo.b), 1);

      canal().limpiar();
      expect(estado().mensajes, isEmpty);
      expect(estado().enviadosPor(Dispositivo.a), 0);
      expect(estado().emisor, Dispositivo.b); // el emisor se conserva
    });
  });

  group('pantalla MobileConnect', () {
    Future<void> montar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides,
        child: const MaterialApp(home: MobileConnectPage()),
      ));
    }

    Future<void> escribirYEnviar(WidgetTester tester, String texto) async {
      await tester.enterText(find.byType(TextField), texto);
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pump();
    }

    testWidgets('muestra los dos dispositivos y sus contadores', (tester) async {
      await montar(tester);
      expect(find.text('Dispositivo A'), findsOneWidget);
      expect(find.text('Dispositivo B'), findsOneWidget);
      expect(find.text('0 enviados'), findsNWidgets(2));
    });

    testWidgets('mensaje vacío muestra un aviso y no se envía', (tester) async {
      await montar(tester);
      await escribirYEnviar(tester, '    ');
      expect(find.text('Escribe un mensaje antes de enviar'), findsOneWidget);
      expect(find.byType(BurbujaMensaje), findsNothing);
    });

    testWidgets('enviar desde A y desde B: burbujas, SnackBar, hora y contador',
        (tester) async {
      await montar(tester);

      await escribirYEnviar(tester, 'Hola B');
      expect(find.text('Mensaje enviado de A a B'), findsOneWidget);
      expect(find.text('Hola B'), findsOneWidget);
      expect(find.text('09:05'), findsOneWidget);
      expect(find.text('1 enviado'), findsOneWidget);
      // El campo se vacía después de enviar.
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');

      // Cambia el emisor con el SegmentedButton.
      await tester.tap(find.text('B'));
      await tester.pump();
      await escribirYEnviar(tester, 'Hola A');
      expect(find.text('Mensaje enviado de B a A'), findsOneWidget);

      // A se alinea a la izquierda y B a la derecha.
      Alignment alineacion(String texto) => tester
          .widget<Align>(find
              .ancestor(of: find.text(texto), matching: find.byType(Align))
              .first)
          .alignment as Alignment;
      expect(alineacion('Hola B'), Alignment.centerLeft);
      expect(alineacion('Hola A'), Alignment.centerRight);
      expect(find.text('1 enviado'), findsNWidgets(2));
    });

    testWidgets('limpiar historial pide confirmación', (tester) async {
      await montar(tester);
      await escribirYEnviar(tester, 'Mensaje');

      // Cancelar: el mensaje sigue.
      await tester.tap(find.byTooltip('Limpiar historial'));
      await tester.pumpAndSettle();
      expect(find.text('¿Borrar historial?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(BurbujaMensaje), findsOneWidget);

      // Confirmar: se borra todo.
      await tester.tap(find.byTooltip('Limpiar historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar'));
      await tester.pumpAndSettle();
      expect(find.byType(BurbujaMensaje), findsNothing);
      expect(find.text('0 enviados'), findsNWidgets(2));
    });
  });
}
