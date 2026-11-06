import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';

void main() {
  test('AuthState inicia cargando, sin rol, sin error y sin proceso activo', () {
    const estado = AuthState();

    // "cargando" es lo que ve la app mientras restaura la sesión guardada.
    expect(estado.status, AuthStatus.cargando);
    expect(estado.rol, isNull);
    expect(estado.correo, isNull);
    expect(estado.error, isNull);
    expect(estado.enProceso, isFalse);
  });
}
