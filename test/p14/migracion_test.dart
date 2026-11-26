// Práctica 14: migración Floor 1 -> 2 sobre un ARCHIVO real (una base en
// memoria no sobrevive a cerrarla, así que no sirve para simular la
// actualización de la app). Se crea una base v1 idéntica a la de la app
// anterior, con una sesión guardada, y se abre con la app nueva.
import 'dart:io';
import 'package:floor/floor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/data/local/app_database.dart';
import 'package:mindgames_app/data/local/partida_en_curso.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// Esquema de la versión 1 (copiado del app_database.g.dart anterior).
const _sesionV1 =
    'CREATE TABLE IF NOT EXISTS `sesion` (`id` INTEGER NOT NULL, `correo` TEXT NOT NULL, `token` TEXT NOT NULL, `rol` TEXT NOT NULL, PRIMARY KEY (`id`))';

void main() {
  late Directory dir;
  late String ruta;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('p14_migracion_');
    ruta = '${dir.path}${Platform.pathSeparator}mindgames_v1.db';
    // Base v1 "de la app anterior" con una sesión guardada.
    final v1 = await sqfliteDatabaseFactory.openDatabase(ruta,
        options: sqflite.OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) => db.execute(_sesionV1),
        ));
    await v1.insert('sesion', {'id': 1, 'correo': 'a@ejemplo.com', 'token': 'token-falso', 'rol': 'ADMIN'});
    await v1.close();
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('P14 migración 1 -> 2', () {
    test('P14-MIG: la migración conserva la sesión y crea partida_en_curso', () async {
      final db = await $FloorAppDatabase.databaseBuilder(ruta).addMigrations([migracion1a2]).build();
      addTearDown(db.close);

      // La sesión de la v1 sigue ahí.
      final s = await db.sesionDao.obtener();
      expect(s!.correo, 'a@ejemplo.com');
      expect(s.token, 'token-falso');
      expect(s.rol, 'ADMIN');

      // Versión 2 y la tabla nueva usable.
      final version = await db.database.rawQuery('PRAGMA user_version');
      expect(version.first.values.first, 2);
      await db.partidaEnCursoDao.guardar(const PartidaEnCurso(
          correo: 'a@ejemplo.com', juego: 'SUDOKU', estadoJson: '{}', segundos: 5, errores: 0, actualizadoEn: 1));
      expect((await db.partidaEnCursoDao.obtener('a@ejemplo.com', 'SUDOKU'))!.segundos, 5);
    });

    test('P14-MIG: la tabla migrada tiene el mismo esquema que una base nueva v2', () async {
      final migrada = await $FloorAppDatabase.databaseBuilder(ruta).addMigrations([migracion1a2]).build();
      addTearDown(migrada.close);
      final nueva = await $FloorAppDatabase.inMemoryDatabaseBuilder().build();
      addTearDown(nueva.close);

      Future<List<Map<String, Object?>>> columnas(FloorDatabase db) =>
          db.database.rawQuery('PRAGMA table_info(partida_en_curso)');
      expect(await columnas(migrada), await columnas(nueva));
    });

    test('P14-MIG: sin registrar la migración, abrir la base v1 falla (por eso va en main.dart)', () async {
      await expectLater($FloorAppDatabase.databaseBuilder(ruta).build(), throwsA(anything));
    });
  });
}
