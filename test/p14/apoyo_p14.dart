// Práctica 14: dobles de prueba compartidos por test/p14/*_test.dart.
// (No termina en _test.dart: no es una suite, solo apoyo.)
import 'package:mindgames_app/data/local/partida_en_curso.dart';
import 'package:mindgames_app/data/local/partida_en_curso_dao.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';

/// DAO en memoria (Map). Se usa en pruebas con reloj falso (fakeAsync o
/// testWidgets), donde la E/S real de SQLite no avanzaría.
/// El DAO real se prueba aparte sobre Floor en memoria (dao_test.dart).
class DaoEnMemoria implements PartidaEnCursoDao {
  final Map<(String, String), PartidaEnCurso> filas = {};
  int guardados = 0;

  @override
  Future<PartidaEnCurso?> obtener(String correo, String juego) async => filas[(correo, juego)];

  @override
  Future<void> guardar(PartidaEnCurso partida) async {
    guardados++;
    filas[(partida.correo, partida.juego)] = partida;
  }

  @override
  Future<void> borrar(String correo, String juego) async => filas.remove((correo, juego));

  @override
  Future<void> borrarTodasDe(String correo) async =>
      filas.removeWhere((clave, _) => clave.$1 == correo);
}

/// AuthController falso: usuario autenticado con [correo].
class AuthFalso extends AuthController {
  AuthFalso(this.correo);
  final String correo;

  @override
  AuthState build() => AuthState(status: AuthStatus.autenticado, correo: correo, rol: 'USER');
}
