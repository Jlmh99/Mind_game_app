import 'dart:async';
import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'sesion.dart';
import 'sesion_dao.dart';

part 'app_database.g.dart';

@Database(version: 1, entities: [Sesion])
abstract class AppDatabase extends FloorDatabase {
  SesionDao get sesionDao;
}
