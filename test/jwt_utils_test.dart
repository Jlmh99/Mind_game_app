import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/core/jwt_utils.dart';

/// Arma un JWT de prueba: encabezado.payload.firma
/// Solo el payload importa para jwt_utils; la firma es falsa porque
/// la app no la verifica (eso lo hace el servidor).
String crearToken(Map<String, dynamic> payload) {
  // base64url sin relleno '=' , igual que los JWT reales.
  String codificar(Map<String, dynamic> datos) =>
      base64Url.encode(utf8.encode(jsonEncode(datos))).replaceAll('=', '');

  final encabezado = codificar({'alg': 'HS256', 'typ': 'JWT'});
  return '$encabezado.${codificar(payload)}.firmaFalsa';
}

/// Segundos desde 1970 desplazados [delta] respecto a ahora (formato de "exp").
int segundosDesdeAhora(Duration delta) =>
    DateTime.now().add(delta).millisecondsSinceEpoch ~/ 1000;

void main() {
  group('tokenExpirado', () {
    test('un token vigente se acepta', () {
      final token = crearToken({
        'sub': 'usuario@correo.com',
        'rol': 'USER',
        'exp': segundosDesdeAhora(const Duration(hours: 1)),
      });
      expect(tokenExpirado(token), isFalse);
    });

    test('un token vencido se rechaza', () {
      final token = crearToken({
        'sub': 'usuario@correo.com',
        'exp': segundosDesdeAhora(const Duration(hours: -1)),
      });
      expect(tokenExpirado(token), isTrue);
    });

    test('un token sin exp se rechaza', () {
      final token = crearToken({'sub': 'usuario@correo.com'});
      expect(tokenExpirado(token), isTrue);
    });

    test('un token vacío se rechaza', () {
      expect(tokenExpirado(''), isTrue);
    });

    test('un token mal formado se rechaza', () {
      // Payload que no es base64 válido.
      expect(tokenExpirado('abc.%%%.def'), isTrue);
      // No tiene las 3 partes de un JWT.
      expect(tokenExpirado('solo-una-parte'), isTrue);
    });
  });

  group('expiracionJwt', () {
    test('devuelve la fecha contenida en exp', () {
      final exp = segundosDesdeAhora(const Duration(minutes: 30));
      final token = crearToken({'exp': exp});
      expect(
        expiracionJwt(token),
        DateTime.fromMillisecondsSinceEpoch(exp * 1000),
      );
    });
  });
}
