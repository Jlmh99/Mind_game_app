// Práctica 13 · AUT-04 (integración): AuthRepository + ApiClient real + Floor en memoria.
// El "servidor" es un MockClient; el token es un valor falso. Sin red real.
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/data/auth_repository.dart';
import 'package:mindgames_app/data/local/app_database.dart';

/// Respuesta JSON en UTF-8 (como la manda el backend real).
http.Response _json(String cuerpo, int codigo) => http.Response.bytes(utf8.encode(cuerpo), codigo,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  late AppDatabase db;
  late List<http.Request> peticiones;

  setUp(() async {
    db = await $FloorAppDatabase.inMemoryDatabaseBuilder().build();
    peticiones = [];
  });
  tearDown(() => db.close());

  AuthRepository repo(http.Response respuesta) => AuthRepository(
        db,
        ApiClient(db.sesionDao, cliente: MockClient((req) async {
          peticiones.add(req);
          return respuesta;
        })),
      );

  group('AUT-04: login con Floor en memoria', () {
    test('AUT-04: 200 "Login correcto" -> la sesión queda guardada en la BD', () async {
      final r = repo(_json(
          '{"mensaje":"Login correcto","token":"token-falso","email":"prueba@ejemplo.com","rol":"ADMIN"}', 200));

      final pide2fa = await r.login('prueba@ejemplo.com', 'contraseña-de-prueba');

      expect(pide2fa, isFalse);
      expect(peticiones.single.url.path, '/api/auth/login');
      final guardada = await db.sesionDao.obtener();
      expect(guardada, isNotNull);
      expect(guardada!.correo, 'prueba@ejemplo.com');
      expect(guardada.token, 'token-falso');
      expect(guardada.rol, 'ADMIN');
    });

    test('AUT-04: 200 con mensaje de error -> lanza ese mensaje y NO guarda sesión', () async {
      final r = repo(_json('{"mensaje":"Contraseña incorrecta"}', 200));

      await expectLater(
        r.login('prueba@ejemplo.com', 'otra'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'texto', contains('Contraseña incorrecta'))),
      );
      expect(await db.sesionDao.obtener(), isNull);
    });
  });
}
