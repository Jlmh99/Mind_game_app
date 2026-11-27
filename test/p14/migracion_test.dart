// Práctica 14: migraciones de Floor sobre ARCHIVOS reales (una base en memoria
// no sobrevive a cerrarla, así que no sirve para simular la actualización de
// la app). Se crea una base "de la app anterior" (v1 o v2) con datos y se abre
// con la app nueva, que registra migracionesApp igual que main.dart.
import 'dart:io';
import 'package:floor/floor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/data/local/app_database.dart';
import 'package:mindgames_app/data/local/partida_en_curso.dart';
import 'package:mindgames_app/data/local/puntuacion_pendiente.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

/// Esquemas de versiones anteriores (copiados de los app_database.g.dart de
/// cada versión).
const _sesionV1 =
    'CREATE TABLE IF NOT EXISTS `sesion` (`id` INTEGER NOT NULL, `correo` TEXT NOT NULL, `token` TEXT NOT NULL, `rol` TEXT NOT NULL, PRIMARY KEY (`id`))';
const _partidaEnCursoV2 =
    'CREATE TABLE IF NOT EXISTS `partida_en_curso` (`correo` TEXT NOT NULL, `juego` TEXT NOT NULL, `estadoJson` TEXT NOT NULL, `segundos` INTEGER NOT NULL, `errores` INTEGER NOT NULL, `actualizadoEn` INTEGER NOT NULL, PRIMARY KEY (`correo`, `juego`))';

/// Crea en [ruta] una base de la versión [version] (1 o 2) con una sesión
/// guardada (y en v2, además, una partida en curso).
Future<void> crearBaseAnterior(String ruta, int version) async {
  final db = await sqfliteDatabaseFactory.openDatabase(ruta,
      options: sqflite.OpenDatabaseOptions(
        version: version,
        onCreate: (db, _) async {
          await db.execute(_sesionV1);
          if (version >= 2) await db.execute(_partidaEnCursoV2);
        },
      ));
  await db.insert('sesion', {'id': 1, 'correo': 'a@ejemplo.com', 'token': 'token-falso', 'rol': 'ADMIN'});
  if (version >= 2) {
    await db.insert('partida_en_curso', {
      'correo': 'a@ejemplo.com',
      'juego': 'SUDOKU',
      'estadoJson': '{"indiceTablero":0}',
      'segundos': 77,
      'errores': 1,
      'actualizadoEn': 1,
    });
  }
  await db.close();
}

Future<int> versionDe(FloorDatabase db) async =>
    (await db.database.rawQuery('PRAGMA user_version')).first.values.first as int;

Future<List<Map<String, Object?>>> columnas(FloorDatabase db, String tabla) =>
    db.database.rawQuery('PRAGMA table_info($tabla)');

void main() {
  late Directory dir;
  late String ruta;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('p14_migracion_');
    ruta = '${dir.path}${Platform.pathSeparator}mindgames.db';
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('P14 migración 1 -> 3 (desde la app original)', () {
    setUp(() => crearBaseAnterior(ruta, 1));

    test('P14-MIG: conserva la sesión y crea partida_en_curso y puntuacion_pendiente', () async {
      final db = await $FloorAppDatabase.databaseBuilder(ruta).addMigrations(migracionesApp).build();
      addTearDown(db.close);

      final s = await db.sesionDao.obtener();
      expect(s!.correo, 'a@ejemplo.com');
      expect(s.token, 'token-falso');
      expect(s.rol, 'ADMIN');
      expect(await versionDe(db), 3);

      await db.partidaEnCursoDao.guardar(const PartidaEnCurso(
          correo: 'a@ejemplo.com', juego: 'SUDOKU', estadoJson: '{}', segundos: 5, errores: 0, actualizadoEn: 1));
      expect((await db.partidaEnCursoDao.obtener('a@ejemplo.com', 'SUDOKU'))!.segundos, 5);
      await db.puntuacionPendienteDao.insertar(const PuntuacionPendiente(
          correo: 'a@ejemplo.com', juego: 'SUDOKU', tiempoSegundos: 9, puntuacion: 900, creadoEn: 1));
      expect(await db.puntuacionPendienteDao.contar('a@ejemplo.com'), 1);
    });

    test('P14-MIG: las tablas migradas tienen el mismo esquema que una base nueva v3', () async {
      final migrada = await $FloorAppDatabase.databaseBuilder(ruta).addMigrations(migracionesApp).build();
      addTearDown(migrada.close);
      final nueva = await $FloorAppDatabase.inMemoryDatabaseBuilder().build();
      addTearDown(nueva.close);

      for (final tabla in ['sesion', 'partida_en_curso', 'puntuacion_pendiente']) {
        expect(await columnas(migrada, tabla), await columnas(nueva, tabla), reason: tabla);
      }
    });

    test('P14-MIG: sin registrar las migraciones, abrir la base v1 falla (por eso van en main.dart)', () async {
      await expectLater($FloorAppDatabase.databaseBuilder(ruta).build(), throwsA(anything));
    });
  });

  group('P14 migración 2 -> 3 (desde la versión con partida en curso)', () {
    setUp(() => crearBaseAnterior(ruta, 2));

    test('P14-MIG: 2 -> 3 conserva "sesion" y "partida_en_curso" y crea la cola', () async {
      final db = await $FloorAppDatabase.databaseBuilder(ruta).addMigrations(migracionesApp).build();
      addTearDown(db.close);

      expect(await versionDe(db), 3);
      final s = await db.sesionDao.obtener();
      expect(s!.correo, 'a@ejemplo.com');
      expect(s.token, 'token-falso');

      final p = await db.partidaEnCursoDao.obtener('a@ejemplo.com', 'SUDOKU');
      expect(p, isNotNull);
      expect(p!.segundos, 77);
      expect(p.errores, 1);
      expect(p.estadoJson, '{"indiceTablero":0}');

      expect(await db.puntuacionPendienteDao.contar('a@ejemplo.com'), 0);
      final id = await db.puntuacionPendienteDao.insertar(const PuntuacionPendiente(
          correo: 'a@ejemplo.com', juego: 'CRUCIGRAMA', tiempoSegundos: 30, puntuacion: 970, creadoEn: 2));
      expect(id, greaterThan(0));
    });

    test('P14-MIG: solo migracion2a3 también basta para pasar de 2 a 3', () async {
      final db = await $FloorAppDatabase.databaseBuilder(ruta).addMigrations([migracion2a3]).build();
      addTearDown(db.close);
      expect(await versionDe(db), 3);
      expect(await db.partidaEnCursoDao.obtener('a@ejemplo.com', 'SUDOKU'), isNotNull);
    });
  });
}
