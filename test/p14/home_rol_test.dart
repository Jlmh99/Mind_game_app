// Práctica 14: opciones del inicio según el rol.
//  - MobileConnect solo para AGENTE y ADMIN (USER y rol null: oculto).
//  - Incidencias para TODOS los roles (USER reporta y sigue las suyas).
//  - Al cambiar de sesión (USER -> cerrar sesión -> ADMIN) el menú se
//    actualiza sin reiniciar la app.
//  - USER no tiene ningún acceso a MobileConnect desde el inicio (no hay rutas
//    con nombre ni deep links: el inicio es la única entrada).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/features/home/home_page.dart';
import 'package:mindgames_app/features/mobileconnect/mobileconnect_page.dart';

/// AuthController falso que permite simular cerrar sesión y entrar con otro rol.
class AuthCambiante extends AuthController {
  AuthCambiante(this.rolInicial);
  final String? rolInicial;

  @override
  AuthState build() => AuthState(status: AuthStatus.autenticado, correo: 'a@ejemplo.com', rol: rolInicial);

  void salir() => state = const AuthState(status: AuthStatus.noAutenticado);

  void entrarComo(String correo, String rol) =>
      state = AuthState(status: AuthStatus.autenticado, correo: correo, rol: rol);
}

Future<AuthCambiante> montar(WidgetTester tester, String? rol) async {
  tester.view.physicalSize = const Size(400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = AuthCambiante(rol);
  await tester.pumpWidget(ProviderScope(
    overrides: [authControllerProvider.overrideWith(() => auth)],
    child: const MaterialApp(home: HomePage()),
  ));
  await tester.pump();
  return auth;
}

void main() {
  for (final (rol, veMobileConnect) in [
    ('USER', false),
    (null, false),
    ('AGENTE', true),
    ('ADMIN', true),
  ]) {
    testWidgets('P14-ROL: $rol -> MobileConnect ${veMobileConnect ? "visible" : "oculto"}; Incidencias visible',
        (tester) async {
      await montar(tester, rol);
      expect(find.text('MobileConnect'), veMobileConnect ? findsOneWidget : findsNothing);
      expect(find.text('Incidencias'), findsOneWidget, reason: 'Incidencias es para todos los roles');
      expect(find.text('Mi perfil'), findsOneWidget);
    });
  }

  testWidgets('P14-ROL: USER no tiene ninguna forma de abrir MobileConnect desde el inicio', (tester) async {
    await montar(tester, 'USER');
    expect(find.byIcon(Icons.devices_outlined), findsNothing);
    // Tocar todo lo que hay en el inicio que no cambia de sesión nunca lleva a MobileConnect.
    for (final texto in ['Mi perfil', 'Incidencias']) {
      expect(find.text(texto), findsOneWidget);
    }
    expect(find.byType(MobileConnectPage), findsNothing);
  });

  testWidgets('P14-ROL: USER -> cerrar sesión -> ADMIN: el menú se actualiza sin reiniciar', (tester) async {
    final auth = await montar(tester, 'USER');
    expect(find.text('MobileConnect'), findsNothing);

    auth.salir();
    auth.entrarComo('admin@ejemplo.com', 'ADMIN');
    await tester.pump();
    expect(find.text('MobileConnect'), findsOneWidget);
    expect(find.text('admin@ejemplo.com'), findsOneWidget);

    // Y de regreso a USER se vuelve a ocultar.
    auth.salir();
    auth.entrarComo('a@ejemplo.com', 'USER');
    await tester.pump();
    expect(find.text('MobileConnect'), findsNothing);
    expect(find.text('Incidencias'), findsOneWidget);
  });
}
