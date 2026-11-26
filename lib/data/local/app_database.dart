import 'dart:async';
import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'partida_en_curso.dart';
import 'partida_en_curso_dao.dart';
import 'sesion.dart';
import 'sesion_dao.dart';

part 'app_database.g.dart';

/// v1: sesion.  v2 (Práctica 14): + partida_en_curso.
@Database(version: 2, entities: [Sesion, PartidaEnCurso])
abstract class AppDatabase extends FloorDatabase {
  SesionDao get sesionDao;
  PartidaEnCursoDao get partidaEnCursoDao;
}

/// Migración 1 -> 2: SOLO crea la tabla nueva; la tabla "sesion" no se toca,
/// así el usuario sigue con su sesión después de actualizar la app.
/// El SQL es el mismo que genera floor_generator para PartidaEnCurso
/// (app_database.g.dart, onCreate), para que una base migrada y una nueva
/// tengan exactamente el mismo esquema.
final migracion1a2 = Migration(1, 2, (database) async {
  await database.execute(
      'CREATE TABLE IF NOT EXISTS `partida_en_curso` (`correo` TEXT NOT NULL, `juego` TEXT NOT NULL, `estadoJson` TEXT NOT NULL, `segundos` INTEGER NOT NULL, `errores` INTEGER NOT NULL, `actualizadoEn` INTEGER NOT NULL, PRIMARY KEY (`correo`, `juego`))');
});
