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

  // ---------------------------------------------------------------------
  // Caja blanca: validarPasswordLogin (validadores.dart L43-48), CC = 4.
  //   C1 (L44): valor == null          (operador ??)
  //   C2 (L45): texto.trim().isEmpty
  //   C3 (L46): texto.length > maxPassword (64)
  // ---------------------------------------------------------------------
  group('validarPasswordLogin: caminos independientes', () {
    test('P1 - valor null (C1 V -> C2 V): pide la contraseña', () {
      expect(validarPasswordLogin(null), 'Ingresa tu contraseña');
    });

    test('P2 - vacía o solo espacios (C1 F -> C2 V): pide la contraseña', () {
      expect(validarPasswordLogin(''), 'Ingresa tu contraseña');
      expect(validarPasswordLogin('     '), 'Ingresa tu contraseña'); // solo espacios
      expect(validarPasswordLogin(' \t\n '), 'Ingresa tu contraseña'); // espacios, tab y salto
      // C2 se evalúa antes que C3: 65 espacios se reportan como vacía, no como larga.
      expect(validarPasswordLogin(' ' * 65), 'Ingresa tu contraseña');
    });

    test('P3 - 65 caracteres (C1 F -> C2 F -> C3 V): excede el máximo', () {
      expect(validarPasswordLogin('a' * 65), 'Máximo 64 caracteres');
    });

    test('P4 - 63 y 64 caracteres, límite inferior a C3 (C3 F): válida', () {
      expect(validarPasswordLogin('a' * 63), isNull);
      expect(validarPasswordLogin('a' * 64), isNull); // borde exacto: 64 no es > 64
      expect(validarPasswordLogin('abc'), isNull); // sin mínimo en el login
      expect(validarPasswordLogin(' clave con espacios '), isNull); // no se recorta
    });
  });
}
