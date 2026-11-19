// Práctica 13 · AUT-06 (persistencia): SesionDao sobre Floor real en memoria
// (sqflite_common_ffi, que ya trae floor). Los valores son de prueba.
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/data/local/app_database.dart';
import 'package:mindgames_app/data/local/sesion.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await $FloorAppDatabase.inMemoryDatabaseBuilder().build());
  tearDown(() => db.close());

  Future<int> filas() async =>
      (await db.database.rawQuery('SELECT COUNT(*) AS n FROM sesion')).first['n'] as int;

  group('AUT-06: SesionDao en Floor en memoria', () {
    test('AUT-06: obtener en una BD vacía devuelve null', () async {
      expect(await db.sesionDao.obtener(), isNull);
      expect(await filas(), 0);
    });

    test('AUT-06: guardar y obtener', () async {
      await db.sesionDao.guardar(Sesion(correo: 'a@ejemplo.com', token: 'token-a', rol: 'AGENTE'));
      final s = await db.sesionDao.obtener();
      expect(s!.id, 1);
      expect(s.correo, 'a@ejemplo.com');
      expect(s.token, 'token-a');
      expect(s.rol, 'AGENTE');
    });

    test('AUT-06: guardar dos veces reemplaza (sigue habiendo una sola fila)', () async {
      await db.sesionDao.guardar(Sesion(correo: 'a@ejemplo.com', token: 'token-a', rol: 'ADMIN'));
      await db.sesionDao.guardar(Sesion(correo: 'b@ejemplo.com', token: 'token-b'));
      final s = await db.sesionDao.obtener();
      expect(s!.correo, 'b@ejemplo.com');
      expect(s.token, 'token-b');
      expect(s.rol, 'USER'); // valor por defecto de Sesion
      expect(await filas(), 1);
    });

    test('AUT-06: limpiar borra la sesión', () async {
      await db.sesionDao.guardar(Sesion(correo: 'a@ejemplo.com', token: 'token-a'));
      await db.sesionDao.limpiar();
      expect(await db.sesionDao.obtener(), isNull);
      expect(await filas(), 0);
    });
  });
}
