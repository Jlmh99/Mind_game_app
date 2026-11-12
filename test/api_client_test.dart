import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/core/errores_api.dart';
import 'package:mindgames_app/core/sesion_expirada_exception.dart';
import 'package:mindgames_app/data/local/sesion.dart';
import 'package:mindgames_app/data/local/sesion_dao.dart';

class _DaoConToken implements SesionDao {
  @override
  Future<Sesion?> obtener() async =>
      Sesion(correo: 'a@b.com', token: 'token-de-prueba', rol: 'USER');
  @override
  Future<void> guardar(Sesion sesion) async {}
  @override
  Future<void> limpiar() async {}
}

/// ApiClient con un servidor falso que responde [codigo] y [cuerpo].
ApiClient clienteQueResponde(int codigo, String cuerpo, {List<http.Request>? registro}) =>
    ApiClient(_DaoConToken(), cliente: MockClient((req) async {
      registro?.add(req);
      return http.Response(cuerpo, codigo,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));

void main() {
  group('ApiClient: traducción de errores', () {
    test('403 con {"mensaje"} del backend -> PermisoDenegadoException', () {
      final api = clienteQueResponde(403, '{"mensaje":"No tienes permiso para realizar esta acción"}');
      expect(api.get('/x', autenticado: true), throwsA(isA<PermisoDenegadoException>()));
    });

    test('403 sin mensaje (Spring Security, sin token) -> SesionExpiradaException', () {
      final api = clienteQueResponde(403, '');
      expect(api.get('/x', autenticado: true), throwsA(isA<SesionExpiradaException>()));
    });

    test('401 -> SesionExpiradaException', () {
      final api = clienteQueResponde(401, '{"mensaje":"Sesión no válida"}');
      expect(api.put('/x', {}, autenticado: true), throwsA(isA<SesionExpiradaException>()));
    });

    test('409 -> ErrorHttpException(409) con el mismo texto de siempre', () async {
      final api = clienteQueResponde(409, '{"mensaje":"El registro fue modificado desde otro dispositivo"}');
      try {
        await api.put('/x', {'version': 0}, autenticado: true);
        fail('Debió lanzar');
      } on ErrorHttpException catch (e) {
        expect(e.esConflicto, isTrue);
        expect(e.toString(), 'Error del servidor (409)'); // AuthController lo reconoce
      }
    });

    test('peticiones públicas: un 403 no se trata como sesión', () {
      final api = clienteQueResponde(403, '');
      expect(api.post('/api/auth/login', {}), throwsA(isA<ErrorHttpException>()));
    });

    test('DELETE autenticado envía el token Bearer', () async {
      final registro = <http.Request>[];
      final api = clienteQueResponde(200, '{"mensaje":"Incidencia eliminada"}', registro: registro);
      await api.delete('/api/incidencias/1', autenticado: true);
      expect(registro.single.method, 'DELETE');
      expect(registro.single.headers['Authorization'], 'Bearer token-de-prueba');
    });
  });
}
