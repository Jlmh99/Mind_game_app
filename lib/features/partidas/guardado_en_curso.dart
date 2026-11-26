import 'dart:async';
import 'dart:convert';
import '../../data/local/partida_en_curso.dart';
import '../../data/local/partida_en_curso_dao.dart';

/// Lo que una pantalla de juego necesita de su controller para ofrecer
/// "Continuar partida" y reaccionar al ciclo de vida de la app.
/// Lo implementan SudokuController y CrucigramaController.
abstract interface class ControladorConPartidaEnCurso<S> {
  /// false en pruebas sin base de datos o sin usuario: no se guarda nada.
  bool get persistenciaActiva;

  /// La partida guardada del usuario actual, o null si no hay (o estaba corrupta).
  Future<S?> partidaGuardada();

  /// Carga [guardada] y el cronómetro sigue desde sus segundos.
  void restaurar(S guardada);

  /// Guarda la partida si hubo jugadas y no ha terminado
  /// (con debounce, o ya mismo si [inmediato]).
  Future<void> guardarEnCurso({bool inmediato = false});

  /// Borra la partida guardada del usuario actual.
  Future<void> borrarEnCurso();

  /// Detiene / reanuda el cronómetro (app en segundo plano, diálogo abierto).
  void pausar();
  void reanudar();
}

/// Guarda en Floor la partida en curso de un juego (Práctica 14).
/// Lo usan SudokuController y CrucigramaController para no repetir:
///  - el "debounce" (guardar ~500 ms después de la última jugada),
///  - el guardado inmediato (app en segundo plano / salir del juego),
///  - leer y borrar la partida guardada de (correo, juego).
///
/// Si no hay DAO (pruebas sin base de datos) o no hay correo, no hace nada:
/// el juego funciona igual que antes.
class GuardadoEnCurso {
  GuardadoEnCurso({
    required this.dao,
    required this.correo,
    required this.juego,
    this.espera = const Duration(milliseconds: 500),
  });

  final PartidaEnCursoDao? dao;
  final String? correo;
  final String juego;
  final Duration espera;
  Timer? _debounce;

  bool get activo => dao != null && (correo ?? '').isNotEmpty;

  /// JSON de la partida guardada, o null si no hay. Si el registro está
  /// corrupto (JSON inválido) se borra y se devuelve null.
  Future<Map<String, dynamic>?> leer() async {
    if (!activo) return null;
    final guardada = await dao!.obtener(correo!, juego);
    if (guardada == null) return null;
    try {
      final datos = jsonDecode(guardada.estadoJson);
      if (datos is Map<String, dynamic>) return datos;
    } on FormatException {
      // Se borra abajo.
    }
    await borrar();
    return null;
  }

  /// Programa un guardado: si llega otra jugada antes de [espera], se
  /// reinicia la espera y solo se guarda la última. [actual] se evalúa al
  /// momento de guardar (estado, segundos y errores de ese instante).
  void programar(({Map<String, dynamic> estado, int segundos, int errores}) Function() actual) {
    if (!activo) return;
    _debounce?.cancel();
    _debounce = Timer(espera, () {
      _debounce = null;
      final a = actual();
      guardarAhora(a.estado, a.segundos, a.errores);
    });
  }

  /// true si hay un guardado programado que todavía no se ejecuta.
  bool get pendiente => _debounce != null;

  /// Guarda ya (cancela el guardado programado, si había uno).
  Future<void> guardarAhora(Map<String, dynamic> estado, int segundos, int errores) async {
    cancelar();
    if (!activo) return;
    await dao!.guardar(PartidaEnCurso(
      correo: correo!,
      juego: juego,
      estadoJson: jsonEncode(estado),
      segundos: segundos,
      errores: errores,
      actualizadoEn: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  /// Borra la partida guardada de este usuario y juego (y cancela lo pendiente).
  Future<void> borrar() async {
    cancelar();
    if (!activo) return;
    await dao!.borrar(correo!, juego);
  }

  /// Cancela el guardado programado sin guardar.
  void cancelar() {
    _debounce?.cancel();
    _debounce = null;
  }
}
