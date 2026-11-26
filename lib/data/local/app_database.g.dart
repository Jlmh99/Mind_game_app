// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

abstract class $AppDatabaseBuilderContract {
  /// Adds migrations to the builder.
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations);

  /// Adds a database [Callback] to the builder.
  $AppDatabaseBuilderContract addCallback(Callback callback);

  /// Creates the database and initializes it.
  Future<AppDatabase> build();
}

// ignore: avoid_classes_with_only_static_members
class $FloorAppDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract databaseBuilder(String name) =>
      _$AppDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract inMemoryDatabaseBuilder() =>
      _$AppDatabaseBuilder(null);
}

class _$AppDatabaseBuilder implements $AppDatabaseBuilderContract {
  _$AppDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  @override
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  @override
  $AppDatabaseBuilderContract addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  @override
  Future<AppDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$AppDatabase();
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
    return database;
  }
}

class _$AppDatabase extends AppDatabase {
  _$AppDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  SesionDao? _sesionDaoInstance;

  PartidaEnCursoDao? _partidaEnCursoDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 2,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
            database, startVersion, endVersion, migrations);

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `sesion` (`id` INTEGER NOT NULL, `correo` TEXT NOT NULL, `token` TEXT NOT NULL, `rol` TEXT NOT NULL, PRIMARY KEY (`id`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `partida_en_curso` (`correo` TEXT NOT NULL, `juego` TEXT NOT NULL, `estadoJson` TEXT NOT NULL, `segundos` INTEGER NOT NULL, `errores` INTEGER NOT NULL, `actualizadoEn` INTEGER NOT NULL, PRIMARY KEY (`correo`, `juego`))');

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  SesionDao get sesionDao {
    return _sesionDaoInstance ??= _$SesionDao(database, changeListener);
  }

  @override
  PartidaEnCursoDao get partidaEnCursoDao {
    return _partidaEnCursoDaoInstance ??=
        _$PartidaEnCursoDao(database, changeListener);
  }
}

class _$SesionDao extends SesionDao {
  _$SesionDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _sesionInsertionAdapter = InsertionAdapter(
            database,
            'sesion',
            (Sesion item) => <String, Object?>{
                  'id': item.id,
                  'correo': item.correo,
                  'token': item.token,
                  'rol': item.rol
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Sesion> _sesionInsertionAdapter;

  @override
  Future<Sesion?> obtener() async {
    return _queryAdapter.query('SELECT * FROM sesion WHERE id = 1',
        mapper: (Map<String, Object?> row) => Sesion(
            id: row['id'] as int,
            correo: row['correo'] as String,
            token: row['token'] as String,
            rol: row['rol'] as String));
  }

  @override
  Future<void> limpiar() async {
    await _queryAdapter.queryNoReturn('DELETE FROM sesion');
  }

  @override
  Future<void> guardar(Sesion sesion) async {
    await _sesionInsertionAdapter.insert(sesion, OnConflictStrategy.replace);
  }
}

class _$PartidaEnCursoDao extends PartidaEnCursoDao {
  _$PartidaEnCursoDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _partidaEnCursoInsertionAdapter = InsertionAdapter(
            database,
            'partida_en_curso',
            (PartidaEnCurso item) => <String, Object?>{
                  'correo': item.correo,
                  'juego': item.juego,
                  'estadoJson': item.estadoJson,
                  'segundos': item.segundos,
                  'errores': item.errores,
                  'actualizadoEn': item.actualizadoEn
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<PartidaEnCurso> _partidaEnCursoInsertionAdapter;

  @override
  Future<PartidaEnCurso?> obtener(
    String correo,
    String juego,
  ) async {
    return _queryAdapter.query(
        'SELECT * FROM partida_en_curso WHERE correo = ?1 AND juego = ?2',
        mapper: (Map<String, Object?> row) => PartidaEnCurso(
            correo: row['correo'] as String,
            juego: row['juego'] as String,
            estadoJson: row['estadoJson'] as String,
            segundos: row['segundos'] as int,
            errores: row['errores'] as int,
            actualizadoEn: row['actualizadoEn'] as int),
        arguments: [correo, juego]);
  }

  @override
  Future<void> borrar(
    String correo,
    String juego,
  ) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM partida_en_curso WHERE correo = ?1 AND juego = ?2',
        arguments: [correo, juego]);
  }

  @override
  Future<void> borrarTodasDe(String correo) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM partida_en_curso WHERE correo = ?1',
        arguments: [correo]);
  }

  @override
  Future<void> guardar(PartidaEnCurso partida) async {
    await _partidaEnCursoInsertionAdapter.insert(
        partida, OnConflictStrategy.replace);
  }
}
