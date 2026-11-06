import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/core/providers.dart';
import 'package:mindgames_app/data/auth_repository.dart';
import 'package:mindgames_app/data/local/app_database.dart';
import 'package:mindgames_app/data/local/sesion.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/main.dart';

/// Repositorio de autenticación falso: sin HTTP ni base de datos.
/// Cada campo "error..." simula lo que lanzaría el repositorio real.
class _RepoFalso implements AuthRepository {
  Object? errorLogin;
  Object? errorRegistro;
  Object? errorCodigo;
  bool pide2fa = false;
  Sesion? sesion;
  int llamadasLogin = 0;
  int llamadasRegistro = 0;

  @override
  AppDatabase get db => throw UnimplementedError();
  @override
  ApiClient get api => throw UnimplementedError();

  @override
  Future<bool> login(String email, String password) async {
    llamadasLogin++;
    if (errorLogin != null) throw errorLogin!;
    if (!pide2fa) sesion = Sesion(correo: email, token: 't', rol: 'USER');
    return pide2fa;
  }

  @override
  Future<void> registrar(String username, String email, String password) async {
    llamadasRegistro++;
    if (errorRegistro != null) throw errorRegistro!;
  }

  @override
  Future<void> verificarCodigo(String email, String codigo) async {
    if (errorCodigo != null) throw errorCodigo!;
    sesion = Sesion(correo: email, token: 't', rol: 'USER');
  }

  @override
  Future<Sesion?> sesionGuardada() async => sesion;

  @override
  Future<void> cerrarSesion() async => sesion = null;
}

void main() {
  late _RepoFalso repo;

  setUp(() => repo = _RepoFalso());

  // ---------------- Mensajes genéricos en el controller ----------------
  group('AuthController: mensajes genéricos', () {
    late ProviderContainer c;

    setUp(() async {
      c = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(repo)]);
      c.read(authControllerProvider);
      await Future<void>.delayed(Duration.zero); // termina restaurarSesion()
    });
    tearDown(() => c.dispose());

    AuthController ctrl() => c.read(authControllerProvider.notifier);
    String? error() => c.read(authControllerProvider).error;

    test('cualquier rechazo del backend en login -> "Credenciales inválidas"',
        () async {
      for (final mensaje in [
        'Usuario no encontrado',
        'Contraseña incorrecta',
        'Tu cuenta está deshabilitada. Contacta a un administrador.',
      ]) {
        repo.errorLogin = Exception(mensaje);
        await ctrl().login('a@b.com', 'x');
        expect(error(), 'Credenciales inválidas');
      }
    });

    test('red o servidor -> "No se pudo conectar, intenta de nuevo"', () async {
      for (final falla in [
        TimeoutException('lento'),
        const SocketException('sin red'),
        Exception('Error del servidor (500)'),
        Exception('Respuesta inesperada del servidor'),
      ]) {
        repo.errorLogin = falla;
        await ctrl().login('a@b.com', 'x');
        expect(error(), 'No se pudo conectar, intenta de nuevo');
      }
    });

    test('registro rechazado -> "No se pudo completar el registro"', () async {
      repo.errorRegistro = Exception('El usuario ya existe');
      expect(await ctrl().registrar('juan', 'a@b.com', '12345678'), isFalse);
      expect(error(), 'No se pudo completar el registro');
    });

    test('código 2FA incorrecto -> "Código inválido"', () async {
      repo.pide2fa = true;
      await ctrl().login('a@b.com', '12345678');
      repo.errorCodigo = Exception('Código inválido o expirado');
      await ctrl().verificarCodigo('000000');
      expect(error(), 'Código inválido');
    });

    test('login correcto llena el rol y no deja error', () async {
      await ctrl().login('a@b.com', '12345678');
      final estado = c.read(authControllerProvider);
      expect(estado.status, AuthStatus.autenticado);
      expect(estado.rol, 'USER');
      expect(estado.error, isNull);
    });
  });

  // ---------------- Pantallas ----------------
  group('pantallas de login y registro', () {
    Future<void> montarApp(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MindGamesApp(),
      ));
      await tester.pump(); // restaurarSesion() -> login
    }

    Finder campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

    testWidgets('campos vacíos o con solo espacios no llaman al servidor',
        (tester) async {
      await montarApp(tester);
      await tester.enterText(campo('Correo'), '   ');
      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pump();

      expect(find.text('Ingresa tu correo'), findsOneWidget);
      expect(find.text('Ingresa tu contraseña'), findsOneWidget);
      expect(repo.llamadasLogin, 0);
    });

    testWidgets('la contraseña está oculta y el botón la muestra u oculta',
        (tester) async {
      await montarApp(tester);
      bool oculta() => tester
          .widget<TextField>(find.descendant(
              of: campo('Contraseña'), matching: find.byType(TextField)))
          .obscureText;

      expect(oculta(), isTrue);
      await tester.tap(find.byTooltip('Mostrar contraseña'));
      await tester.pump();
      expect(oculta(), isFalse);
      await tester.tap(find.byTooltip('Ocultar contraseña'));
      await tester.pump();
      expect(oculta(), isTrue);
    });

    testWidgets('maxLength corta la contraseña a 64 caracteres', (tester) async {
      await montarApp(tester);
      await tester.enterText(campo('Contraseña'), 'a' * 80);
      final texto = tester
          .widget<TextField>(find.descendant(
              of: campo('Contraseña'), matching: find.byType(TextField)))
          .controller!
          .text;
      expect(texto.length, 64);
    });

    testWidgets('credenciales rechazadas muestran el mensaje genérico',
        (tester) async {
      repo.errorLogin = Exception('Usuario no encontrado');
      await montarApp(tester);
      await tester.enterText(campo('Correo'), 'nadie@correo.com');
      await tester.enterText(campo('Contraseña'), 'loquesea');
      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Credenciales inválidas'), findsOneWidget);
      expect(find.text('Usuario no encontrado'), findsNothing);
    });

    testWidgets('login correcto muestra "Acceso exitoso" y entra al inicio',
        (tester) async {
      await montarApp(tester);
      await tester.enterText(campo('Correo'), '  juan@correo.com  ');
      await tester.enterText(campo('Contraseña'), 'secreta123');
      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pump();
      await tester.pump();

      expect(repo.llamadasLogin, 1);
      expect(find.text('Acceso exitoso. ¡Bienvenido!'), findsOneWidget);
      expect(find.text('juan@correo.com'), findsOneWidget); // saludo del inicio (con trim)
    });

    testWidgets('registro: usuario con espacios y contraseña corta se rechazan',
        (tester) async {
      await montarApp(tester);
      await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
      await tester.pumpAndSettle();

      await tester.enterText(campo('Nombre de usuario'), '     ');
      await tester.enterText(campo('Correo'), 'juan@correo.com');
      await tester.enterText(campo('Contraseña'), '1234567');
      await tester.tap(find.text('REGISTRARME'));
      await tester.pump();

      expect(find.text('Ingresa tu nombre de usuario'), findsOneWidget);
      expect(find.text('Mínimo 8 caracteres'), findsWidgets);
      expect(repo.llamadasRegistro, 0);
    });

    testWidgets('registro rechazado por el backend muestra mensaje genérico',
        (tester) async {
      repo.errorRegistro = Exception('El usuario ya existe');
      await montarApp(tester);
      await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
      await tester.pumpAndSettle();

      await tester.enterText(campo('Nombre de usuario'), 'juan');
      await tester.enterText(campo('Correo'), 'juan@correo.com');
      await tester.enterText(campo('Contraseña'), '12345678');
      await tester.tap(find.text('REGISTRARME'));
      await tester.pump();
      await tester.pump();

      expect(find.text('No se pudo completar el registro'), findsOneWidget);
      expect(find.text('El usuario ya existe'), findsNothing);
    });
  });
}
