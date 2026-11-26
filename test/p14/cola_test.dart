// Práctica 14: cola offline de puntuaciones.
// Pila real: Floor en memoria + ApiClient + PartidasRepository + PartidasController
// + ColaPuntuacionesController. El "servidor" es un MockClient programable y la
// conectividad un StreamController. Sin red real; el token es falso.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/core/errores_api.dart';
import 'package:mindgames_app/core/providers.dart';
import 'package:mindgames_app/core/sesion_expirada_exception.dart';
import 'package:mindgames_app/data/local/app_database.dart';
import 'package:mindgames_app/data/local/puntuacion_pendiente.dart';
import 'package:mindgames_app/data/local/sesion.dart';
import 'package:mindgames_app/data/partidas_repository.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/features/partidas/cola_puntuaciones.dart';
import 'package:mindgames_app/features/partidas/partidas_controller.dart';

/// AuthController falso: usuario autenticado; registra si se cerró la sesión.
class AuthCola extends AuthController {
  AuthCola(this.correo);
  final String correo;
  bool sesionExpiradaLlamada = false;

  @override
  AuthState build() => AuthState(status: AuthStatus.autenticado, correo: correo, rol: 'USER');

  @override
  Future<void> sesionExpirada() async {
    sesionExpiradaLlamada = true;
    state = const AuthState(status: AuthStatus.noAutenticado, error: 'Tu sesión expiró');
  }
}

/// Servidor simulado: [alPost] decide qué responde cada POST (por número de
/// llamada, empezando en 1). Registra los POST y cuántos hay "en vuelo".
class Servidor {
  FutureOr<http.Response> Function(int n, Map<String, dynamic> cuerpo) alPost =
      (n, cuerpo) => ok(n, cuerpo);
  final posts = <Map<String, dynamic>>[];
  int getsPartidas = 0;
  int enVuelo = 0, maxEnVuelo = 0;
  Duration demora = Duration.zero;

  static http.Response json(int codigo, Object cuerpo) => http.Response.bytes(
      utf8.encode(jsonEncode(cuerpo)), codigo,
      headers: {'content-type': 'application/json; charset=utf-8'});

  static http.Response ok(int n, Map<String, dynamic> c) => json(200, {
        'id': 500 + n,
        'juego': c['juego'],
        'tiempoSegundos': c['tiempoSegundos'],
        'puntuacion': c['puntuacion'],
        'fecha': '2026-11-26T10:00:00',
      });

  Future<http.Response> manejar(http.Request req) async {
    if (req.method == 'GET' && req.url.path == '/api/partidas/me') {
      getsPartidas++;
      return json(200, []);
    }
    if (req.method == 'POST' && req.url.path == '/api/partidas') {
      final cuerpo = jsonDecode(req.body) as Map<String, dynamic>;
      posts.add(cuerpo);
      enVuelo++;
      if (enVuelo > maxEnVuelo) maxEnVuelo = enVuelo;
      try {
        if (demora > Duration.zero) await Future<void>.delayed(demora);
        return await alPost(posts.length, cuerpo);
      } finally {
        enVuelo--;
      }
    }
    return json(404, {'mensaje': 'no existe'});
  }
}

/// Todo lo necesario para una prueba.
class Entorno {
  Entorno._(this.db, this.c, this.servidor, this.auth, this.red);
  final AppDatabase db;
  final ProviderContainer c;
  final Servidor servidor;
  final AuthCola auth;
  final StreamController<bool> red;

  ColaPuntuacionesController get cola => c.read(colaPuntuacionesProvider.notifier);
  PartidasController get partidas => c.read(partidasControllerProvider.notifier);

  Future<ResultadoGuardado> guardar({int puntuacion = 700}) =>
      partidas.guardar(juego: 'SUDOKU', tiempoSegundos: 60, puntuacion: puntuacion);

  Future<List<PuntuacionPendiente>> pendientes([String? correo]) =>
      db.puntuacionPendienteDao.pendientesDe(correo ?? auth.correo);

  /// Deja correr las tareas en segundo plano (sincronización disparada sola).
  Future<void> esperar() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }
}

/// Crea el entorno. [antes] permite dejar pendientes en la base ANTES de que
/// arranque la cola (como si vinieran de una sesión anterior).
Future<Entorno> crearEntorno({
  String correo = 'a@ejemplo.com',
  Servidor? servidor,
  Future<void> Function(AppDatabase db)? antes,
}) async {
  final db = await $FloorAppDatabase.inMemoryDatabaseBuilder().build();
  await db.sesionDao.guardar(Sesion(correo: correo, token: 'token-falso', rol: 'USER'));
  if (antes != null) await antes(db);
  final s = servidor ?? Servidor();
  final auth = AuthCola(correo);
  final red = StreamController<bool>.broadcast();
  final c = ProviderContainer(overrides: [
    puntuacionPendienteDaoProvider.overrideWithValue(db.puntuacionPendienteDao),
    conectividadProvider.overrideWithValue(red.stream),
    apiClientProvider.overrideWithValue(ApiClient(db.sesionDao, cliente: MockClient(s.manejar))),
    authControllerProvider.overrideWith(() => auth),
  ]);
  c.listen(colaPuntuacionesProvider, (_, _) {}); // arranca la cola (como main.dart)
  // La cola intenta reenviar al iniciar con sesión: se deja terminar ese
  // primer intento para que no se cruce con lo que haga cada prueba.
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  addTearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50)); // termina lo que corría
    c.dispose();
    await red.close();
    await db.close();
  });
  return Entorno._(db, c, s, auth, red);
}

PuntuacionPendiente pendiente(String correo, int puntuacion, int creadoEn) => PuntuacionPendiente(
    correo: correo, juego: 'SUDOKU', tiempoSegundos: 30, puntuacion: puntuacion, creadoEn: creadoEn);

void main() {
  group('P14 cola: clasificación del fallo', () {
    test('P14-COLA: red y 5xx se encolan; 400/422/otros 4xx y 403 de permiso no; 401/403 de sesión es "sesion"', () {
      expect(clasificarFalloGuardado(const SocketException('sin red')), FalloGuardado.red);
      expect(clasificarFalloGuardado(http.ClientException('cortada')), FalloGuardado.red);
      expect(clasificarFalloGuardado(TimeoutException('30 s')), FalloGuardado.red);
      expect(clasificarFalloGuardado(const ErrorHttpException(500)), FalloGuardado.servidor);
      expect(clasificarFalloGuardado(const ErrorHttpException(503)), FalloGuardado.servidor);
      for (final c in [400, 404, 409, 422]) {
        expect(clasificarFalloGuardado(ErrorHttpException(c)), FalloGuardado.rechazada, reason: '$c');
      }
      expect(clasificarFalloGuardado(const PermisoDenegadoException()), FalloGuardado.rechazada);
      expect(clasificarFalloGuardado(const SesionExpiradaException()), FalloGuardado.sesion);
      expect(seDebeEncolar(FalloGuardado.red), isTrue);
      expect(seDebeEncolar(FalloGuardado.servidor), isTrue);
      expect(seDebeEncolar(FalloGuardado.rechazada), isFalse);
      expect(seDebeEncolar(FalloGuardado.sesion), isFalse);
    });
  });

  group('P14 cola: al guardar', () {
    test('P14-COLA: fallo de red -> se encola y devuelve "pendiente"', () async {
      final s = Servidor()..alPost = (_, _) => throw http.ClientException('sin conexión');
      final e = await crearEntorno(servidor: s);

      expect(await e.guardar(puntuacion: 812), ResultadoGuardado.pendiente);
      final cola = await e.pendientes();
      expect(cola, hasLength(1));
      expect(cola.single.puntuacion, 812);
      expect(cola.single.juego, 'SUDOKU');
      expect(cola.single.correo, 'a@ejemplo.com');
      expect(e.c.read(colaPuntuacionesProvider), 1); // contador para "Mi perfil"
    });

    test('P14-COLA: HTTP 503 -> también se encola', () async {
      final s = Servidor()..alPost = (_, _) => Servidor.json(503, {'mensaje': 'mantenimiento'});
      final e = await crearEntorno(servidor: s);
      expect(await e.guardar(), ResultadoGuardado.pendiente);
      expect(await e.pendientes(), hasLength(1));
    });

    test('P14-COLA: HTTP 400 y 422 -> "fallo" y NO se encola', () async {
      for (final codigo in [400, 422]) {
        final s = Servidor()..alPost = (_, _) => Servidor.json(codigo, {'mensaje': 'inválida'});
        final e = await crearEntorno(servidor: s);
        expect(await e.guardar(), ResultadoGuardado.fallo, reason: '$codigo');
        expect(await e.pendientes(), isEmpty, reason: '$codigo');
      }
    });

    test('P14-COLA: HTTP 401 con la cola vacía -> cierra la sesión y NO se encola (como hoy)', () async {
      final s = Servidor()..alPost = (_, _) => Servidor.json(401, {});
      final e = await crearEntorno(servidor: s);
      expect(await e.guardar(puntuacion: 3), ResultadoGuardado.sesionExpirada);
      expect(e.auth.sesionExpiradaLlamada, isTrue);
      expect(await e.pendientes(), isEmpty);
    });

    test('P14-COLA: HTTP 401 con pendientes -> cierra la sesión y la cola se conserva (con la nueva al final)',
        () async {
      final s = Servidor()..alPost = (_, _) => throw http.ClientException('sin conexión');
      final e = await crearEntorno(servidor: s);
      await e.guardar(puntuacion: 1);
      await e.guardar(puntuacion: 2);
      expect(await e.pendientes(), hasLength(2));

      s.alPost = (_, _) => Servidor.json(401, {});
      expect(await e.guardar(puntuacion: 3), ResultadoGuardado.sesionExpirada);
      expect(e.auth.sesionExpiradaLlamada, isTrue);
      final cola = await e.pendientes();
      expect(cola.map((p) => p.puntuacion), [1, 2, 3],
          reason: 'no se borra nada; la nueva ya estaba en la cola (detrás de las otras) cuando llegó el 401');
    });
  });

  group('P14 cola: sincronización', () {
    test('P14-COLA: reenvía en orden (creadoEn ASC) y borra cada una tras 2xx; luego refresca la lista', () async {
      final s = Servidor()..alPost = (_, _) => throw http.ClientException('sin conexión');
      final e = await crearEntorno(
        servidor: s,
        antes: (db) async {
          // Insertadas en desorden a propósito.
          await db.puntuacionPendienteDao.insertar(pendiente('a@ejemplo.com', 3, 300));
          await db.puntuacionPendienteDao.insertar(pendiente('a@ejemplo.com', 1, 100));
          await db.puntuacionPendienteDao.insertar(pendiente('a@ejemplo.com', 2, 200));
        },
      );
      await e.esperar(); // el intento al iniciar falla (sin red)
      expect(await e.pendientes(), hasLength(3));
      s.posts.clear();
      final getsAntes = s.getsPartidas;

      s.alPost = Servidor.ok; // vuelve la red
      final r = await e.cola.sincronizar();

      expect(r.enviadas, 3);
      expect(r.detenida, isFalse);
      expect(s.posts.map((p) => p['puntuacion']), [1, 2, 3]);
      expect(await e.pendientes(), isEmpty);
      expect(e.c.read(colaPuntuacionesProvider), 0);
      await e.esperar();
      expect(s.getsPartidas, greaterThan(getsAntes), reason: 'se refresca la lista de partidas');
    });

    test('P14-COLA: se detiene al primer fallo de red; nada se borra sin 2xx', () async {
      final s = Servidor()..alPost = (_, _) => throw http.ClientException('sin conexión');
      final e = await crearEntorno(
        servidor: s,
        antes: (db) async {
          for (final (p, t) in [(1, 100), (2, 200), (3, 300)]) {
            await db.puntuacionPendienteDao.insertar(pendiente('a@ejemplo.com', p, t));
          }
        },
      );
      await e.esperar();
      s.posts.clear();

      s.alPost = (n, c) => n == 1 ? Servidor.ok(n, c) : throw http.ClientException('se cayó otra vez');
      final r = await e.cola.sincronizar();

      expect(r.enviadas, 1);
      expect(r.detenida, isTrue);
      expect(s.posts.map((p) => p['puntuacion']), [1, 2], reason: 'la 3 ni se intenta');
      final cola = await e.pendientes();
      expect(cola.map((p) => p.puntuacion), [2, 3]);
      expect(cola.first.intentos, greaterThan(0));
    });

    test('P14-COLA: una pendiente rechazada (400) se descarta y no bloquea a las demás', () async {
      final s = Servidor()..alPost = (_, _) => throw http.ClientException('sin conexión');
      final e = await crearEntorno(
        servidor: s,
        antes: (db) async {
          await db.puntuacionPendienteDao.insertar(pendiente('a@ejemplo.com', 1, 100));
          await db.puntuacionPendienteDao.insertar(pendiente('a@ejemplo.com', 2, 200));
        },
      );
      await e.esperar();
      s.alPost = (n, c) => c['puntuacion'] == 1 ? Servidor.json(400, {'mensaje': 'inválida'}) : Servidor.ok(n, c);
      final r = await e.cola.sincronizar();
      expect(r.descartadas, 1);
      expect(r.enviadas, 1);
      expect(await e.pendientes(), isEmpty);
    });

    test('P14-COLA: dos usuarios no se mezclan (solo se envían las del usuario actual)', () async {
      final s = Servidor()..alPost = (_, _) => throw http.ClientException('sin conexión');
      final e = await crearEntorno(
        servidor: s,
        antes: (db) async {
          await db.puntuacionPendienteDao.insertar(pendiente('a@ejemplo.com', 11, 100));
          await db.puntuacionPendienteDao.insertar(pendiente('b@ejemplo.com', 99, 50));
          await db.puntuacionPendienteDao.insertar(pendiente('a@ejemplo.com', 12, 200));
        },
      );
      await e.esperar();
      s.posts.clear();
      s.alPost = Servidor.ok;
      await e.cola.sincronizar();

      expect(s.posts.map((p) => p['puntuacion']), [11, 12]);
      expect(await e.pendientes('a@ejemplo.com'), isEmpty);
      expect((await e.pendientes('b@ejemplo.com')).single.puntuacion, 99);
      expect(await e.db.puntuacionPendienteDao.contar('b@ejemplo.com'), 1);
    });

    test('P14-COLA: sin envíos concurrentes aunque se pida sincronizar varias veces a la vez', () async {
      final s = Servidor()..alPost = (_, _) => throw http.ClientException('sin conexión');
      final e = await crearEntorno(
        servidor: s,
        antes: (db) async {
          for (final (p, t) in [(1, 100), (2, 200), (3, 300)]) {
            await db.puntuacionPendienteDao.insertar(pendiente('a@ejemplo.com', p, t));
          }
        },
      );
      await e.esperar();
      s.posts.clear();
      s.maxEnVuelo = 0;
      s.alPost = Servidor.ok;
      s.demora = const Duration(milliseconds: 20);

      // Cinco disparos a la vez: tres llamadas, la red que vuelve y un guardado nuevo.
      e.red.add(true);
      final resultados = await Future.wait<Object>(
          [e.cola.sincronizar(), e.cola.sincronizar(), e.cola.sincronizar(), e.guardar(puntuacion: 4)]);
      await e.esperar();
      await e.cola.sincronizar();

      expect(s.maxEnVuelo, 1, reason: 'nunca hubo dos POST de la cola al mismo tiempo... ni con el guardado nuevo');
      final enviadas = s.posts.map((p) => p['puntuacion']).toList();
      expect(enviadas.where((p) => p != 4), [1, 2, 3], reason: 'cada pendiente se envió una sola vez y en orden');
      expect(enviadas, [1, 2, 3, 4], reason: 'la partida nueva va al final de la cola');
      expect(resultados.last, ResultadoGuardado.guardada);
      expect(await e.pendientes(), isEmpty);
    });

    test('P14-COLA: al volver la conectividad se reenvía solo', () async {
      final s = Servidor()..alPost = (_, _) => throw http.ClientException('sin conexión');
      final e = await crearEntorno(servidor: s);
      expect(await e.guardar(puntuacion: 640), ResultadoGuardado.pendiente);
      s.posts.clear();

      s.alPost = Servidor.ok;
      e.red.add(true); // connectivity_plus avisa que hay red
      await e.esperar();

      expect(s.posts.single['puntuacion'], 640);
      expect(await e.pendientes(), isEmpty);
      expect(e.c.read(colaPuntuacionesProvider), 0);
    });

    test('P14-COLA: perder la red (evento false) no dispara envíos', () async {
      final s = Servidor()..alPost = (_, _) => throw http.ClientException('sin conexión');
      final e = await crearEntorno(servidor: s);
      await e.guardar();
      s.posts.clear();
      e.red.add(false);
      await e.esperar();
      expect(s.posts, isEmpty);
    });

    test('P14-COLA: al iniciar con sesión se reenvía lo pendiente', () async {
      final s = Servidor(); // con red desde el inicio
      final e = await crearEntorno(
        servidor: s,
        antes: (db) => db.puntuacionPendienteDao.insertar(pendiente('a@ejemplo.com', 333, 100)),
      );
      await e.esperar();
      expect(s.posts.single['puntuacion'], 333);
      expect(await e.pendientes(), isEmpty);
    });

    test('P14-COLA: con pendientes, una partida nueva va al final de la cola: se envían en orden y queda "guardada"',
        () async {
      final s = Servidor()..alPost = (_, _) => throw http.ClientException('sin conexión');
      final e = await crearEntorno(servidor: s);
      await e.guardar(puntuacion: 100); // queda pendiente
      s.posts.clear();

      s.alPost = Servidor.ok;
      expect(await e.guardar(puntuacion: 200), ResultadoGuardado.guardada);
      await e.esperar();
      expect(s.posts.map((p) => p['puntuacion']), [100, 200], reason: 'primero la que se jugó antes');
      expect(await e.pendientes(), isEmpty);
    });

    test('P14-COLA: con pendientes y aún sin red, la partida nueva queda "pendiente" detrás de las demás', () async {
      final s = Servidor()..alPost = (_, _) => throw http.ClientException('sin conexión');
      final e = await crearEntorno(servidor: s);
      expect(await e.guardar(puntuacion: 1), ResultadoGuardado.pendiente);
      expect(await e.guardar(puntuacion: 2), ResultadoGuardado.pendiente);
      expect((await e.pendientes()).map((p) => p.puntuacion), [1, 2]);
    });
  });
}
