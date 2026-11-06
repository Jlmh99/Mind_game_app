import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/features/auth/validadores.dart';

void main() {
  group('validarUsuario', () {
    test('obligatorio y rechaza solo espacios', () {
      expect(validarUsuario(null), isNotNull);
      expect(validarUsuario(''), isNotNull);
      expect(validarUsuario('    '), isNotNull);
    });
    test('máximo 30 caracteres', () {
      expect(validarUsuario('a' * 30), isNull);
      expect(validarUsuario('a' * 31), isNotNull);
    });
    test('acepta un usuario normal', () {
      expect(validarUsuario('  juan  '), isNull); // se compara ya recortado
    });
  });

  group('validarCorreo', () {
    test('obligatorio, sin solo espacios y con formato', () {
      expect(validarCorreo(''), isNotNull);
      expect(validarCorreo('   '), isNotNull);
      expect(validarCorreo('sinarroba.com'), isNotNull);
      expect(validarCorreo('a b@c.com'), isNotNull);
      expect(validarCorreo('juan@correo.com'), isNull);
    });
    test('máximo 100 caracteres', () {
      final base = '@correo.com';
      expect(validarCorreo('${'a' * (100 - base.length)}$base'), isNull);
      expect(validarCorreo('${'a' * (101 - base.length)}$base'), isNotNull);
    });
  });

  group('contraseñas', () {
    test('login: obligatoria, sin solo espacios, máx. 64 y sin mínimo', () {
      expect(validarPasswordLogin(''), isNotNull);
      expect(validarPasswordLogin('      '), isNotNull);
      expect(validarPasswordLogin('abc'), isNull); // cuentas antiguas
      expect(validarPasswordLogin('a' * 64), isNull);
      expect(validarPasswordLogin('a' * 65), isNotNull);
    });
    test('registro: además mínimo 8', () {
      expect(validarPasswordRegistro('1234567'), 'Mínimo 8 caracteres');
      expect(validarPasswordRegistro('12345678'), isNull);
      expect(validarPasswordRegistro('a' * 65), isNotNull);
      expect(validarPasswordRegistro('        '), isNotNull); // 8 espacios
    });
  });
}
