// Pruebas de caja blanca de AuthRepository.login() (lib/data/auth_repository.dart L32-41).
//
// Complejidad ciclomática = 4:
//   C1 (L35): mensaje == '2FA requerido'
//   C2 (L36): mensaje == 'Login correcto'
//   C3 (L40): mensaje == null            (operador ??)
// Además, _post (L15-20) tiene la condición C4 (L18): r is Map<String, dynamic>.
//
// No se usa un servidor real: el ApiClient recibe un MockClient de
// package:http/testing.dart y la base de datos local es un doble que solo
// registra la sesión que se guarda.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/core/api_config.dart';
import 'package:mindgames_app/data/auth_repository.dart';
import 'package:mindgames_app/data/local/app_database.dart';
import 'package:mindgames_app/data/local/sesion.dart';
import 'package:mindgames_app/data/local/sesion_dao.dart';

/// DAO falso: guarda en memoria las sesiones que recibe.
class _SesionDaoFalso implements SesionDao {
  final List<Sesion> guardadas = [];

  @override
  Future<Sesion?> obtener() async => guardadas.isEmpty ? null : guardadas.last;

  @override
  Future<void> guardar(Sesion sesion) async => guardadas.add(sesion);

  @override
  Future<void> limpiar() async => guardadas.clear();
}

/// AppDatabase falsa: solo expone el DAO. Lo demás de FloorDatabase no se
/// usa en login(), por eso se resuelve con noSuchMethod.
class _BdFalsa implements AppDatabase {
  @override
  final SesionDao sesionDao;
  _BdFalsa(this.sesionDao);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Arma un AuthRepository cuyo "servidor" responde con [responder].
({AuthRepository repo, _SesionDaoFalso dao, List<http.Request> peticiones}) armar(
    Future<http.Response> Function(http.Request) responder) {
  final dao = _SesionDaoFalso();
  final peticiones = <http.Request>[];
  final api = ApiClient(dao, cliente: MockClient((req) {
    peticiones.add(req);
    return responder(req);
  }));
  return (repo: AuthRepository(_BdFalsa(dao), api), dao: dao, peticiones: peticiones);
}

/// Respuesta JSON 200 como las del AuthController del backend.
Future<http.Response> json200(Object cuerpo) async => http.Response(
      jsonEncode(cuerpo),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  group('AuthRepository.login: caminos independientes', () {
    test('P1 - "2FA requerido" (C1 V): devuelve true y NO guarda sesión', () async {
      final p = armar((_) => json200({'mensaje': '2FA requerido'}));

      final pideCodigo = await p.repo.login('a@b.com', 'secreta1');

      expect(pideCodigo, isTrue);
      expect(p.dao.guardadas, isEmpty);
      // Se llamó a la ruta real de login con el correo y la contraseña.
      expect(p.peticiones.single.url.toString(), '$baseUrl$rutaLogin');
      expect(jsonDecode(p.peticiones.single.body),
          {'email': 'a@b.com', 'password': 'secreta1'});
    });

    test('P2 - "Login correcto" (C1 F -> C2 V): guarda correo, token y rol y devuelve false',
        () async {
      final p = armar((_) => json200({
            'mensaje': 'Login correcto',
            'token': 'token-de-prueba',
            'rol': 'ADMIN',
            'email': 'admin@b.com',
          }));

      final pideCodigo = await p.repo.login('admin@b.com', 'secreta1');

      expect(pideCodigo, isFalse);
      expect(p.dao.guardadas, hasLength(1));
      final s = p.dao.guardadas.single;
      expect(s.correo, 'admin@b.com');
      expect(s.token, 'token-de-prueba');
      expect(s.rol, 'ADMIN');
      expect(s.id, 1); // siempre una sola sesión
    });

    test('P3 - otro mensaje, no nulo (C1 F -> C2 F -> C3 F): lanza Exception con ese mensaje',
        () async {
      final p = armar((_) => json200({'mensaje': 'Contraseña incorrecta'}));

      await expectLater(
        p.repo.login('a@b.com', 'mala'),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'mensaje', contains('Contraseña incorrecta'))),
      );
      expect(p.dao.guardadas, isEmpty);
    });

    test('P4 - respuesta sin "mensaje" (C1 F -> C2 F -> C3 V): lanza el mensaje por defecto',
        () async {
      final p = armar((_) => json200(<String, dynamic>{}));

      await expectLater(
        p.repo.login('a@b.com', 'x'),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'mensaje', contains('No fue posible iniciar sesión'))),
      );
      expect(p.dao.guardadas, isEmpty);
    });
  });

  group('AuthRepository.login: excepciones', () {
    test('_post C4 F - JSON que no es objeto (lista): "Respuesta inesperada del servidor"',
        () async {
      final p = armar((_) => json200(['no', 'es', 'objeto']));

      await expectLater(
        p.repo.login('a@b.com', 'x'),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'mensaje', contains('Respuesta inesperada del servidor'))),
      );
      expect(p.dao.guardadas, isEmpty);
    });

    test('texto plano (no JSON): ApiClient lo envuelve en {"mensaje"} y sigue el camino P3',
        () async {
      // ApiClient convierte el texto plano en {'mensaje': texto} (api_client.dart),
      // así que _post sí recibe un Map y login() lanza ese texto como error.
      final p = armar((_) async => http.Response('Servicio no disponible', 200));

      await expectLater(
        p.repo.login('a@b.com', 'x'),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'mensaje', contains('Servicio no disponible'))),
      );
      expect(p.dao.guardadas, isEmpty);
    });

    test('error de red: el cliente lanza ClientException y login() la propaga sin guardar nada',
        () async {
      final p = armar((_) => throw http.ClientException('Sin conexión'));

      await expectLater(p.repo.login('a@b.com', 'x'), throwsA(isA<http.ClientException>()));
      expect(p.dao.guardadas, isEmpty);
    });
  });

  // ---------------------------------------------------------------------
  // registrar() (auth_repository.dart L22-28), CC = 2.
  //   C1 (L25): mensaje != 'Usuario registrado correctamente'
  // ---------------------------------------------------------------------
  group('AuthRepository.registrar: caminos independientes', () {
    test('R1 - "Usuario registrado correctamente" (C1 F): termina sin error y no guarda sesión',
        () async {
      final p = armar((_) => json200({'mensaje': 'Usuario registrado correctamente'}));

      await p.repo.registrar('juan', 'juan@b.com', 'secreta12');

      expect(p.dao.guardadas, isEmpty); // registrar no inicia sesión
      expect(p.peticiones.single.url.toString(), '$baseUrl$rutaRegistro');
      expect(jsonDecode(p.peticiones.single.body),
          {'username': 'juan', 'email': 'juan@b.com', 'password': 'secreta12'});
    });

    test('R2 - otro mensaje (C1 V): lanza Exception con ese texto', () async {
      final p = armar((_) => json200({'mensaje': 'El correo ya está registrado'}));

      await expectLater(
        p.repo.registrar('juan', 'juan@b.com', 'secreta12'),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'mensaje', contains('El correo ya está registrado'))),
      );
      expect(p.dao.guardadas, isEmpty);
    });
  });

  // ---------------------------------------------------------------------
  // verificarCodigo() (auth_repository.dart L44-50), CC = 3.
  //   C1 (L46): mensaje != 'Login correcto'
  //   C2 (L47): mensaje == null   (operador ??)
  // ---------------------------------------------------------------------
  group('AuthRepository.verificarCodigo: caminos independientes', () {
    test('V1 - "Login correcto" (C1 F): guarda correo, token y rol', () async {
      final p = armar((_) => json200({
            'mensaje': 'Login correcto',
            'token': 'token-2fa',
            'rol': 'AGENTE',
            'email': 'agente@b.com',
          }));

      await p.repo.verificarCodigo('agente@b.com', '123456');

      final s = p.dao.guardadas.single;
      expect(s.correo, 'agente@b.com');
      expect(s.token, 'token-2fa');
      expect(s.rol, 'AGENTE');
      expect(p.peticiones.single.url.toString(), '$baseUrl$rutaVerificar');
      expect(jsonDecode(p.peticiones.single.body),
          {'email': 'agente@b.com', 'codigo': '123456'});
    });

    test('V2 - otro mensaje, no nulo (C1 V -> C2 F): lanza Exception con ese texto', () async {
      final p = armar((_) => json200({'mensaje': 'Código expirado'}));

      await expectLater(
        p.repo.verificarCodigo('a@b.com', '000000'),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'mensaje', contains('Código expirado'))),
      );
      expect(p.dao.guardadas, isEmpty);
    });

    test('V3 - respuesta sin "mensaje" (C1 V -> C2 V): lanza "Código inválido"', () async {
      final p = armar((_) => json200(<String, dynamic>{}));

      await expectLater(
        p.repo.verificarCodigo('a@b.com', '000000'),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'mensaje', contains('Código inválido'))),
      );
      expect(p.dao.guardadas, isEmpty);
    });
  });

  // ---------------------------------------------------------------------
  // sesionGuardada() (L61) y cerrarSesion() (L63), CC = 1 cada uno.
  // Delegan en el DAO; no hacen peticiones de red.
  // ---------------------------------------------------------------------
  group('AuthRepository.sesionGuardada y cerrarSesion', () {
    test('S1 - sin sesión guardada: devuelve null', () async {
      final p = armar((_) => throw StateError('no debe llamar al servidor'));

      expect(await p.repo.sesionGuardada(), isNull);
      expect(p.peticiones, isEmpty);
    });

    test('S2 - con sesión guardada: devuelve esa sesión', () async {
      final p = armar((_) => throw StateError('no debe llamar al servidor'));
      await p.dao.guardar(Sesion(correo: 'a@b.com', token: 't', rol: 'USER'));

      final s = await p.repo.sesionGuardada();

      expect(s, isNotNull);
      expect(s!.correo, 'a@b.com');
      expect(s.token, 't');
      expect(s.rol, 'USER');
      expect(p.peticiones, isEmpty);
    });

    test('C1 - cerrarSesion: después de llamarla la sesión desaparece', () async {
      // Se inicia sesión por el camino real (login P2) y luego se cierra.
      final p = armar((_) => json200({
            'mensaje': 'Login correcto',
            'token': 'token-de-prueba',
            'rol': 'USER',
            'email': 'a@b.com',
          }));
      await p.repo.login('a@b.com', 'secreta1');
      expect(await p.repo.sesionGuardada(), isNotNull);

      await p.repo.cerrarSesion();

      expect(await p.repo.sesionGuardada(), isNull);
      expect(p.dao.guardadas, isEmpty);
      expect(p.peticiones, hasLength(1)); // cerrarSesion no llama al servidor
    });
  });
}
