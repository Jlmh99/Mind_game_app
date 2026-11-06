import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/core/api_config.dart';
import 'package:mindgames_app/data/local/sesion.dart';
import 'package:mindgames_app/data/local/sesion_dao.dart';
import 'package:mindgames_app/data/partidas_repository.dart';

/// DAO falso: ApiClient lo pide en su constructor, pero aquí no se usa.
class _DaoFalso implements SesionDao {
  @override
  Future<Sesion?> obtener() async => null;
  @override
  Future<void> guardar(Sesion sesion) async {}
  @override
  Future<void> limpiar() async {}
}

/// ApiClient falso: registra qué se pidió y devuelve una respuesta fija.
class _ApiFalsa extends ApiClient {
  _ApiFalsa(this.respuesta) : super(_DaoFalso());

  final dynamic respuesta;
  String? ruta;
  Map<String, dynamic>? cuerpo;
  bool? autenticado;

  @override
  Future<dynamic> get(String ruta, {bool autenticado = false}) async {
    this.ruta = ruta;
    this.autenticado = autenticado;
    return respuesta;
  }

  @override
  Future<dynamic> post(String ruta, Map<String, dynamic> cuerpo,
      {bool autenticado = false}) async {
    this.ruta = ruta;
    this.cuerpo = cuerpo;
    this.autenticado = autenticado;
    return respuesta;
  }
}

void main() {
  test('guardar hace POST autenticado con juego, tiempo y puntuación', () async {
    final api = _ApiFalsa({
      'id': 7,
      'juego': 'SUDOKU',
      'tiempoSegundos': 245,
      'puntuacion': 655,
      'fecha': '2026-11-05T21:30:12.123456',
    });
    final partida = await PartidasRepository(api)
        .guardar(juego: juegoSudoku, tiempoSegundos: 245, puntuacion: 655);

    expect(api.ruta, rutaPartidas);
    expect(api.autenticado, isTrue);
    expect(api.cuerpo,
        {'juego': 'SUDOKU', 'tiempoSegundos': 245, 'puntuacion': 655});
    expect(partida.id, 7);
    expect(partida.fecha, DateTime(2026, 11, 5, 21, 30, 12, 123, 456));
  });

  test('misPartidas hace GET autenticado y convierte la lista', () async {
    final api = _ApiFalsa([
      {
        'id': 2,
        'juego': 'CRUCIGRAMA',
        'tiempoSegundos': 60,
        'puntuacion': 940,
        'fecha': '2026-11-05T22:00:00',
      },
    ]);
    final partidas = await PartidasRepository(api).misPartidas();

    expect(api.ruta, rutaMisPartidas);
    expect(api.autenticado, isTrue);
    expect(partidas.single.juego, juegoCrucigrama);
    expect(partidas.single.puntuacion, 940);
  });

  test('una respuesta inesperada lanza error', () async {
    final api = _ApiFalsa({'mensaje': 'algo raro'});
    expect(PartidasRepository(api).misPartidas(), throwsException);
    expect(
      PartidasRepository(api)
          .guardar(juego: juegoSudoku, tiempoSegundos: 1, puntuacion: 1),
      throwsException,
    );
  });
}
