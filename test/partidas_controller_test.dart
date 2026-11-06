import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/core/sesion_expirada_exception.dart';
import 'package:mindgames_app/data/foto_perfil_repository.dart';
import 'package:mindgames_app/data/partidas_repository.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/features/partidas/guardar_partida.dart';
import 'package:mindgames_app/features/partidas/partidas_controller.dart';
import 'package:mindgames_app/features/perfil/perfil_page.dart';

/// Qué debe hacer el repositorio falso en la siguiente llamada.
enum Modo { ok, sesionExpirada, errorRed }

final _partidaEjemplo = Partida(
  id: 1,
  juego: juegoSudoku,
  tiempoSegundos: 245,
  puntuacion: 655,
  fecha: DateTime(2026, 11, 5, 21, 30),
);

/// Repositorio falso: no hace HTTP, responde según [modo].
class _RepoFalso implements PartidasRepository {
  Modo modo = Modo.ok;
  List<Partida> enServidor = [];

  @override
  ApiClient get api => throw UnimplementedError();

  Never _fallar() => modo == Modo.sesionExpirada
      ? throw const SesionExpiradaException()
      : throw Exception('Error del servidor (500)');

  @override
  Future<Partida> guardar(
      {required String juego,
      required int tiempoSegundos,
      required int puntuacion}) async {
    if (modo != Modo.ok) _fallar();
    return _partidaEjemplo;
  }

  @override
  Future<List<Partida>> misPartidas() async {
    if (modo != Modo.ok) _fallar();
    return enServidor;
  }
}

/// Repositorio de foto falso: el usuario no tiene foto.
class _FotoSinFoto implements FotoPerfilRepository {
  @override
  ApiClient get api => throw UnimplementedError();
  @override
  Future<Uint8List?> obtener() async => null;
  @override
  Future<void> subir(Uint8List bytes) async {}
}

/// AuthController falso: arranca autenticado y registra si se llamó sesionExpirada().
class _AuthFalso extends AuthController {
  bool sesionExpiradaLlamada = false;

  @override
  AuthState build() => const AuthState(
      status: AuthStatus.autenticado, correo: 'jugador@correo.com', rol: 'USER');

  @override
  Future<void> sesionExpirada() async {
    sesionExpiradaLlamada = true;
    state = const AuthState(
        status: AuthStatus.noAutenticado, error: 'Tu sesión expiró');
  }
}

void main() {
  late _RepoFalso repo;
  late ProviderContainer contenedor;

  setUp(() {
    repo = _RepoFalso();
    contenedor = ProviderContainer(overrides: [
      partidasRepositoryProvider.overrideWithValue(repo),
      // Mi perfil también pide la foto: se usa un repositorio falso sin foto.
      fotoPerfilRepositoryProvider.overrideWithValue(_FotoSinFoto()),
      authControllerProvider.overrideWith(_AuthFalso.new),
    ]);
  });
  tearDown(() => contenedor.dispose());

  PartidasController ctrl() => contenedor.read(partidasControllerProvider.notifier);
  _AuthFalso auth() =>
      contenedor.read(authControllerProvider.notifier) as _AuthFalso;

  Future<ResultadoGuardado> guardar() =>
      ctrl().guardar(juego: juegoSudoku, tiempoSegundos: 245, puntuacion: 655);

  group('PartidasController', () {
    test('guardar con éxito agrega la partida al inicio de la lista', () async {
      expect(await guardar(), ResultadoGuardado.guardada);
      expect(contenedor.read(partidasControllerProvider).partidas,
          [_partidaEjemplo]);
    });

    test('SesionExpiradaException llama a authController.sesionExpirada()',
        () async {
      repo.modo = Modo.sesionExpirada;
      expect(await guardar(), ResultadoGuardado.sesionExpirada);
      expect(auth().sesionExpiradaLlamada, isTrue);
      expect(contenedor.read(authControllerProvider).error, 'Tu sesión expiró');
    });

    test('otros errores devuelven fallo sin cerrar la sesión', () async {
      repo.modo = Modo.errorRed;
      expect(await guardar(), ResultadoGuardado.fallo);
      expect(auth().sesionExpiradaLlamada, isFalse);
    });

    test('cargar trae las partidas o un mensaje genérico', () async {
      repo.enServidor = [_partidaEjemplo];
      await ctrl().cargar();
      expect(contenedor.read(partidasControllerProvider).partidas.length, 1);

      repo.modo = Modo.errorRed;
      await ctrl().cargar();
      final estado = contenedor.read(partidasControllerProvider);
      expect(estado.error, 'No se pudieron cargar tus partidas');
      expect(estado.cargando, isFalse);
    });

    test('cargar con sesión expirada también llama a sesionExpirada()',
        () async {
      repo.modo = Modo.sesionExpirada;
      await ctrl().cargar();
      expect(auth().sesionExpiradaLlamada, isTrue);
    });
  });

  group('pantallas', () {
    /// Monta [hijo] con los mismos providers falsos.
    Widget app(Widget hijo) => UncontrolledProviderScope(
          container: contenedor,
          child: MaterialApp(home: hijo),
        );

    testWidgets('guardarPartidaYAvisar muestra SnackBar de éxito y de fallo',
        (tester) async {
      await tester.pumpWidget(app(Scaffold(
        body: Consumer(builder: (context, ref, _) {
          return TextButton(
            onPressed: () => guardarPartidaYAvisar(context, ref,
                juego: juegoSudoku, tiempoSegundos: 10, puntuacion: 990),
            child: const Text('guardar'),
          );
        }),
      )));

      await tester.tap(find.text('guardar'));
      await tester.pump(); // termina el Future
      await tester.pump(); // aparece el SnackBar
      expect(find.text('Partida guardada'), findsOneWidget);

      ScaffoldMessenger.of(tester.element(find.text('guardar')))
          .removeCurrentSnackBar();
      repo.modo = Modo.errorRed;
      await tester.tap(find.text('guardar'));
      await tester.pump();
      await tester.pump();
      expect(find.text('No se pudo guardar la partida. Revisa tu conexión.'),
          findsOneWidget);
    });

    testWidgets('Mi perfil muestra juego, puntuación, tiempo y fecha',
        (tester) async {
      repo.enServidor = [_partidaEjemplo];
      await tester.pumpWidget(app(const PerfilPage()));
      await tester.pump(); // ejecuta cargar()
      await tester.pump();

      expect(find.text('jugador@correo.com'), findsOneWidget);
      expect(find.text('Sudoku'), findsOneWidget);
      expect(find.text('655'), findsOneWidget);
      expect(find.text('Tiempo 4:05 · 05/11/2026 21:30'), findsOneWidget);
    });

    testWidgets('Mi perfil sin partidas muestra el mensaje vacío',
        (tester) async {
      await tester.pumpWidget(app(const PerfilPage()));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Aún no tienes partidas'), findsOneWidget);
    });
  });
}
