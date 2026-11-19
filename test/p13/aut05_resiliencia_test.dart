// Práctica 13 · AUT-05 (integración): resiliencia ante fallas del servidor.
//  (a) POST de partidas por el ApiClient real con HTTP 500.
//  (b) Servidor que nunca responde (fakeAsync, timeout de 30 s del ApiClient).
//  (c) Lista de incidencias con error de carga: debe mostrar el error y NO
//      "No hay incidencias todavía" ni "Todos (0)". FALLA hoy: es el defecto D1
//      (visto en P12, RES-01/03/04). No se corrige aquí.
// Sin red real (MockClient) y sin secretos (token falso).
import 'dart:async';
import 'dart:convert';
// fake_async llega con flutter_test (que fija su versión); no se agrega a
// pubspec.yaml porque en este paso solo se crean archivos en test/p13/.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/core/errores_api.dart';
import 'package:mindgames_app/core/providers.dart';
import 'package:mindgames_app/data/incidencias_repository.dart';
import 'package:mindgames_app/data/local/app_database.dart';
import 'package:mindgames_app/data/local/sesion.dart';
import 'package:mindgames_app/data/local/sesion_dao.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/features/incidencias/incidencias_page.dart';
import 'package:mindgames_app/features/partidas/partidas_controller.dart';

/// AuthController falso: usuario autenticado; registra si se pidió cerrar la sesión.
class _AuthFalso extends AuthController {
  bool sesionExpiradaLlamada = false;

  @override
  AuthState build() =>
      const AuthState(status: AuthStatus.autenticado, correo: 'prueba@ejemplo.com', rol: 'USER');

  @override
  Future<void> sesionExpirada() async {
    sesionExpiradaLlamada = true;
    state = const AuthState(status: AuthStatus.noAutenticado, error: 'Tu sesión expiró');
  }
}

/// DAO en memoria (para fakeAsync: sin E/S real de SQLite).
class _DaoEnMemoria implements SesionDao {
  Sesion? _s = Sesion(correo: 'prueba@ejemplo.com', token: 'token-falso', rol: 'USER');
  @override
  Future<Sesion?> obtener() async => _s;
  @override
  Future<void> guardar(Sesion sesion) async => _s = sesion;
  @override
  Future<void> limpiar() async => _s = null;
}

/// Repositorio de incidencias cuyo listado falla con HTTP 500
/// (equivale a fallaAlListar = ErrorHttpException(500) de incidencias_test.dart L55).
class _RepoQueFallaAlListar implements IncidenciasRepository {
  int llamadasListar = 0;

  @override
  Future<List<Incidencia>> listar() async {
    llamadasListar++;
    throw const ErrorHttpException(500);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AUT-05: resiliencia', () {
    test('AUT-05a: POST de partida con 500 (ApiClient real) -> no se confirma como guardada', () async {
      final db = await $FloorAppDatabase.inMemoryDatabaseBuilder().build();
      await db.sesionDao.guardar(Sesion(correo: 'prueba@ejemplo.com', token: 'token-falso', rol: 'USER'));
      final peticiones = <http.Request>[];
      final auth = _AuthFalso();
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(ApiClient(db.sesionDao, cliente: MockClient((req) async {
          peticiones.add(req);
          return http.Response.bytes(utf8.encode('{"mensaje":"Error interno"}'), 500,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }))),
        authControllerProvider.overrideWith(() => auth),
      ]);
      addTearDown(() async {
        c.dispose();
        await db.close();
      });

      final resultado = await c
          .read(partidasControllerProvider.notifier)
          .guardar(juego: 'SUDOKU', tiempoSegundos: 120, puntuacion: 880);

      expect(resultado, ResultadoGuardado.fallo);
      expect(c.read(partidasControllerProvider).partidas, isEmpty);
      expect(peticiones, hasLength(1)); // un solo POST, sin reintento automático
      expect(peticiones.single.method, 'POST');
      expect(peticiones.single.url.path, '/api/partidas');
      expect(peticiones.single.headers['Authorization'], 'Bearer token-falso');
      expect(auth.sesionExpiradaLlamada, isFalse); // un 500 no cierra la sesión
    });

    test('AUT-05b: servidor que nunca responde -> TimeoutException a los 30 s (no antes)', () {
      fakeAsync((fa) {
        var peticiones = 0;
        final api = ApiClient(_DaoEnMemoria(), cliente: MockClient((_) {
          peticiones++;
          return Completer<http.Response>().future; // nunca responde
        }));
        Object? error;
        var termino = false;
        api.post('/api/partidas', {'juego': 'SUDOKU'}, autenticado: true).then<void>(
          (_) {
            termino = true;
          },
          onError: (Object e) {
            error = e;
            termino = true;
          },
        );

        fa.elapse(const Duration(seconds: 29));
        expect(termino, isFalse, reason: 'a los 29 s todavía espera');

        fa.elapse(const Duration(seconds: 2)); // total 31 s
        expect(termino, isTrue);
        expect(error, isA<TimeoutException>());
        expect(peticiones, 1); // sin reintento automático
      });
    });

    test('AUT-05b: servidor que nunca responde -> el controller devuelve "fallo" tras el timeout', () {
      fakeAsync((fa) {
        final c = ProviderContainer(overrides: [
          apiClientProvider.overrideWithValue(ApiClient(_DaoEnMemoria(),
              cliente: MockClient((_) => Completer<http.Response>().future))),
          authControllerProvider.overrideWith(_AuthFalso.new),
        ]);
        ResultadoGuardado? resultado;
        c
            .read(partidasControllerProvider.notifier)
            .guardar(juego: 'CRUCIGRAMA', tiempoSegundos: 30, puntuacion: 970)
            .then((r) => resultado = r);

        fa.elapse(const Duration(seconds: 29));
        expect(resultado, isNull);
        fa.elapse(const Duration(seconds: 2));
        expect(resultado, ResultadoGuardado.fallo);
        expect(c.read(partidasControllerProvider).partidas, isEmpty);
        c.dispose();
      });
    });

    // FALLA HOY A PROPÓSITO: defecto D1.
    testWidgets('AUT-05c: lista de incidencias con error 500 -> muestra el error y NO "No hay incidencias todavía" ni "Todos (0)"',
        (tester) async {
      final repo = _RepoQueFallaAlListar();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          incidenciasRepositoryProvider.overrideWithValue(repo),
          authControllerProvider.overrideWith(_AuthFalso.new),
        ],
        child: const MaterialApp(home: IncidenciasPage()),
      ));
      await tester.pump();
      await tester.pump();

      expect(repo.llamadasListar, 1);
      expect(find.text('No se pudieron cargar las incidencias'), findsOneWidget);
      expect(find.text('No hay incidencias todavía'), findsNothing);
      expect(find.text('Todos (0)'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
