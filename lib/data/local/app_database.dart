import 'dart:async';
import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'partida_en_curso.dart';
import 'partida_en_curso_dao.dart';
import 'puntuacion_pendiente.dart';
import 'puntuacion_pendiente_dao.dart';
import 'sesion.dart';
import 'sesion_dao.dart';

part 'app_database.g.dart';

/// v1: sesion.  v2 (Práctica 14): + partida_en_curso.
/// v3 (Práctica 14, cola offline): + puntuacion_pendiente.
@Database(version: 3, entities: [Sesion, PartidaEnCurso, PuntuacionPendiente])
abstract class AppDatabase extends FloorDatabase {
  SesionDao get sesionDao;
  PartidaEnCursoDao get partidaEnCursoDao;
  PuntuacionPendienteDao get puntuacionPendienteDao;
}

/// Todas las migraciones, en orden. main() las registra con addMigrations;
/// Floor aplica las que falten según la versión que tenga el teléfono.
final migracionesApp = [migracion1a2, migracion2a3];

/// Migración 1 -> 2: SOLO crea la tabla nueva; la tabla "sesion" no se toca,
/// así el usuario sigue con su sesión después de actualizar la app.
/// El SQL es el mismo que genera floor_generator para PartidaEnCurso
/// (app_database.g.dart, onCreate), para que una base migrada y una nueva
/// tengan exactamente el mismo esquema.
final migracion1a2 = Migration(1, 2, (database) async {
  await database.execute(
      'CREATE TABLE IF NOT EXISTS `partida_en_curso` (`correo` TEXT NOT NULL, `juego` TEXT NOT NULL, `estadoJson` TEXT NOT NULL, `segundos` INTEGER NOT NULL, `errores` INTEGER NOT NULL, `actualizadoEn` INTEGER NOT NULL, PRIMARY KEY (`correo`, `juego`))');
});

/// Migración 2 -> 3: SOLO crea la tabla de la cola offline de puntuaciones;
/// "sesion" y "partida_en_curso" no se tocan. Mismo SQL que genera
/// floor_generator para PuntuacionPendiente.
final migracion2a3 = Migration(2, 3, (database) async {
  await database.execute(
      'CREATE TABLE IF NOT EXISTS `puntuacion_pendiente` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `correo` TEXT NOT NULL, `juego` TEXT NOT NULL, `tiempoSegundos` INTEGER NOT NULL, `puntuacion` INTEGER NOT NULL, `creadoEn` INTEGER NOT NULL, `intentos` INTEGER NOT NULL)');
});
