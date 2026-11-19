// Práctica 13 · AUT-01 (unitaria): validación del formulario de login
// (lib/features/auth/validadores.dart: validarCorreo y validarPasswordLogin).
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/features/auth/validadores.dart';

void main() {
  group('AUT-01: validarPasswordLogin', () {
    test('AUT-01: contraseña válida -> null (sin error)', () {
      expect(validarPasswordLogin('Secreta1'), isNull);
    });

    test('AUT-01: null -> "Ingresa tu contraseña"', () {
      expect(validarPasswordLogin(null), 'Ingresa tu contraseña');
    });

    test('AUT-01: vacía y solo espacios -> "Ingresa tu contraseña"', () {
      expect(validarPasswordLogin(''), 'Ingresa tu contraseña');
      expect(validarPasswordLogin('   '), 'Ingresa tu contraseña');
    });

    test('AUT-01: 64 caracteres (límite) -> null; 65 -> "Máximo 64 caracteres"', () {
      expect(validarPasswordLogin('a' * 64), isNull);
      expect(validarPasswordLogin('a' * 65), 'Máximo 64 caracteres');
    });

    test('AUT-01: 65 caracteres con espacios en los extremos también se rechaza (no se recorta)', () {
      expect(validarPasswordLogin(' ${'a' * 63} '), 'Máximo 64 caracteres');
    });
  });

  group('AUT-01: validarCorreo', () {
    test('AUT-01: correo válido -> null', () {
      expect(validarCorreo('a@b.com'), isNull);
    });

    test('AUT-01: null, vacío y solo espacios -> "Ingresa tu correo"', () {
      expect(validarCorreo(null), 'Ingresa tu correo');
      expect(validarCorreo(''), 'Ingresa tu correo');
      expect(validarCorreo('   '), 'Ingresa tu correo');
    });

    test('AUT-01: sin @ -> "Ingresa un correo válido"', () {
      expect(validarCorreo('ab.com'), 'Ingresa un correo válido');
    });

    test('AUT-01: 101 caracteres -> "Máximo 100 caracteres"', () {
      final largo = '${'a' * 95}@b.com'; // 101 caracteres
      expect(largo.length, 101);
      expect(validarCorreo(largo), 'Máximo 100 caracteres');
    });
  });
}
