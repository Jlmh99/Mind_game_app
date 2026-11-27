// Práctica 14: PartidaEnCursoDao sobre Floor REAL en memoria (FFI).
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/data/local/app_database.dart';
import 'package:mindgames_app/data/local/partida_en_curso.dart';

PartidaEnCurso partida(String correo, String juego, {int segundos = 10, String json = '{}'}) =>
    PartidaEnCurso(
      correo: correo,
      juego: juego,
      estadoJson: json,
      segundos: segundos,
      errores: 1,
      actualizadoEn: 1764115200000,
    );

void main() {
  late AppDatabase db;

  setUp(() async => db = await $FloorAppDatabase.inMemoryDatabaseBuilder().build());
  tearDown(() => db.close());

  group('P14 DAO: PartidaEnCursoDao en Floor en memoria', () {
    test('P14-DAO: obtener sin datos devuelve null', () async {
      expect(await db.partidaEnCursoDao.obtener('a@ejemplo.com', 'SUDOKU'), isNull);
    });

    test('P14-DAO: guardar y obtener conserva todos los campos', () async {
      await db.partidaEnCursoDao.guardar(partida('a@ejemplo.com', 'SUDOKU', segundos: 95, json: '{"x":1}'));
      final p = await db.partidaEnCursoDao.obtener('a@ejemplo.com', 'SUDOKU');
      expect(p!.correo, 'a@ejemplo.com');
      expect(p.juego, 'SUDOKU');
      expect(p.estadoJson, '{"x":1}');
      expect(p.segundos, 95);
      expect(p.errores, 1);
      expect(p.actualizadoEn, 1764115200000);
    });

    test('P14-DAO: guardar dos veces el mismo (correo, juego) reemplaza', () async {
      await db.partidaEnCursoDao.guardar(partida('a@ejemplo.com', 'SUDOKU', segundos: 10));
      await db.partidaEnCursoDao.guardar(partida('a@ejemplo.com', 'SUDOKU', segundos: 20));
      expect((await db.partidaEnCursoDao.obtener('a@ejemplo.com', 'SUDOKU'))!.segundos, 20);
      final n = await db.database.rawQuery('SELECT COUNT(*) AS n FROM partida_en_curso');
      expect(n.first['n'], 1);
    });

    test('P14-DAO: borrar solo quita ese (correo, juego)', () async {
      await db.partidaEnCursoDao.guardar(partida('a@ejemplo.com', 'SUDOKU'));
      await db.partidaEnCursoDao.guardar(partida('a@ejemplo.com', 'CRUCIGRAMA'));
      await db.partidaEnCursoDao.borrar('a@ejemplo.com', 'SUDOKU');
      expect(await db.partidaEnCursoDao.obtener('a@ejemplo.com', 'SUDOKU'), isNull);
      expect(await db.partidaEnCursoDao.obtener('a@ejemplo.com', 'CRUCIGRAMA'), isNotNull);
    });

    test('P14-DAO: dos usuarios no se mezclan; borrarTodasDe solo afecta a uno', () async {
      await db.partidaEnCursoDao.guardar(partida('a@ejemplo.com', 'SUDOKU', segundos: 11));
      await db.partidaEnCursoDao.guardar(partida('b@ejemplo.com', 'SUDOKU', segundos: 22));
      await db.partidaEnCursoDao.guardar(partida('a@ejemplo.com', 'CRUCIGRAMA'));
      expect((await db.partidaEnCursoDao.obtener('a@ejemplo.com', 'SUDOKU'))!.segundos, 11);
      expect((await db.partidaEnCursoDao.obtener('b@ejemplo.com', 'SUDOKU'))!.segundos, 22);

      await db.partidaEnCursoDao.borrarTodasDe('a@ejemplo.com');
      expect(await db.partidaEnCursoDao.obtener('a@ejemplo.com', 'SUDOKU'), isNull);
      expect(await db.partidaEnCursoDao.obtener('a@ejemplo.com', 'CRUCIGRAMA'), isNull);
      expect((await db.partidaEnCursoDao.obtener('b@ejemplo.com', 'SUDOKU'))!.segundos, 22);
    });

    test('P14-DAO: limpiar la sesión (cerrar sesión) NO borra las partidas guardadas', () async {
      await db.partidaEnCursoDao.guardar(partida('a@ejemplo.com', 'SUDOKU'));
      await db.sesionDao.limpiar(); // lo que hace AuthRepository.cerrarSesion()
      expect(await db.partidaEnCursoDao.obtener('a@ejemplo.com', 'SUDOKU'), isNotNull);
    });
  });
}
