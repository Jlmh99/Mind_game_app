// Práctica 13 · AUT-02 (unitaria): traducción de códigos HTTP en ApiClient,
// con MockClient (sin red real). El token es un valor falso de prueba.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/core/errores_api.dart';
import 'package:mindgames_app/core/sesion_expirada_exception.dart';
import 'package:mindgames_app/data/local/sesion.dart';
import 'package:mindgames_app/data/local/sesion_dao.dart';

/// DAO en memoria con una sesión de prueba (token falso).
class _DaoConSesion implements SesionDao {
  @override
  Future<Sesion?> obtener() async => Sesion(correo: 'prueba@ejemplo.com', token: 'token-falso', rol: 'USER');
  @override
  Future<void> guardar(Sesion sesion) async {}
  @override
  Future<void> limpiar() async {}
}

/// ApiClient cuyo "servidor" responde siempre [codigo] con [cuerpo].
ApiClient _api(int codigo, String cuerpo) => ApiClient(_DaoConSesion(),
    cliente: MockClient((_) async => http.Response(cuerpo, codigo,
        headers: {'content-type': 'application/json; charset=utf-8'})));

void main() {
  group('AUT-02: ApiClient con MockClient', () {
    test('AUT-02: 500 -> ErrorHttpException con código 500', () async {
      final api = _api(500, '{"mensaje":"Error interno"}');
      await expectLater(
        api.get('/x', autenticado: true),
        throwsA(isA<ErrorHttpException>().having((e) => e.codigo, 'codigo', 500)),
      );
    });

    test('AUT-02: 401 -> SesionExpiradaException', () async {
      await expectLater(_api(401, '').get('/x', autenticado: true),
          throwsA(isA<SesionExpiradaException>()));
    });

    test('AUT-02: 403 con {"mensaje"} -> PermisoDenegadoException', () async {
      await expectLater(
          _api(403, '{"mensaje":"No tienes permiso para realizar esta acción"}').get('/x', autenticado: true),
          throwsA(isA<PermisoDenegadoException>()));
    });

    test('AUT-02: 500 con cuerpo vacío o JSON inválido -> ErrorHttpException(500), sin reventar', () async {
      for (final cuerpo in ['', '{no es json']) {
        await expectLater(
          _api(500, cuerpo).post('/x', {}, autenticado: true),
          throwsA(isA<ErrorHttpException>().having((e) => e.codigo, 'codigo', 500)),
          reason: 'cuerpo: "$cuerpo"',
        );
      }
    });

    test('AUT-02: 401 y 403 con cuerpo vacío o JSON inválido -> SesionExpiradaException, sin reventar', () async {
      for (final (codigo, cuerpo) in [(401, '{no es json'), (403, ''), (403, '{no es json')]) {
        await expectLater(_api(codigo, cuerpo).get('/x', autenticado: true),
            throwsA(isA<SesionExpiradaException>()),
            reason: '$codigo con "$cuerpo"');
      }
    });

    test('AUT-02: 200 con cuerpo vacío o que no es JSON -> se envuelve en {"mensaje": texto}', () async {
      expect(await _api(200, '').get('/x', autenticado: true), {'mensaje': ''});
      expect(await _api(200, '{no es json').get('/x', autenticado: true), {'mensaje': '{no es json'});
    });
  });
}
