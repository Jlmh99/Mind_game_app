import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../data/local/puntuacion_pendiente.dart';
import '../../data/partidas_repository.dart';
import '../auth/auth_controller.dart';
import 'partidas_controller.dart';

/// Resultado de una sincronización. [sesionExpirada]: el servidor respondió
/// 401/403 y se cerró la sesión (la cola se conserva).
typedef ResultadoSincronizacion = ({int enviadas, int descartadas, bool detenida, bool sesionExpirada});

/// Cola offline de puntuaciones (Práctica 14).
///
/// - encolar(): guarda en Floor una puntuación que no se pudo enviar.
/// - sincronizar(): envía las pendientes del usuario actual en orden
///   (creadoEn ASC) y borra cada una SOLO tras un 2xx. Si falla por red o 5xx
///   se detiene (la siguiente vez sigue desde ahí). Un solo envío a la vez:
///   si se pide otra sincronización mientras corre una, se espera a la misma
///   y al terminar se repasa la cola una vez más.
/// - Se dispara al volver la conectividad, al iniciar con sesión y después de
///   cada partida guardada con éxito (PartidasController).
///
/// El estado es el número de pendientes del usuario actual (para "Mi perfil").
/// Sin DAO (pruebas sin base de datos) no hace nada y vale 0.
final colaPuntuacionesProvider =
    NotifierProvider<ColaPuntuacionesController, int>(ColaPuntuacionesController.new);

/// Qué pasó con una pendiente concreta en la última sincronización.
enum DestinoPendiente { enviada, descartada }

class ColaPuntuacionesController extends Notifier<int> {
  Future<ResultadoSincronizacion>? _enCurso;
  bool _otraVez = false;

  /// id -> qué le pasó (para que PartidasController sepa el resultado de la
  /// partida que acaba de encolar). Se consulta y se borra con destinoDe().
  final Map<int, DestinoPendiente> _destinos = {};

  @override
  int build() {
    final dao = ref.watch(puntuacionPendienteDaoProvider);
    if (dao == null) return 0;

    // Al volver la red, se reenvía lo pendiente.
    final sub = ref.watch(conectividadProvider).listen((hayRed) {
      if (hayRed) sincronizar();
    });
    ref.onDispose(sub.cancel);

    // Al iniciar (o cambiar) la sesión: contar y reenviar lo pendiente.
    // Se ESCUCHA la sesión (listen) en lugar de observarla (watch): así la
    // cola no se reconstruye a mitad de un envío cuando un 401 cierra la sesión.
    ref.listen(
      authControllerProvider.select((s) => s.status == AuthStatus.autenticado ? s.correo : null),
      (_, correo) => Future.microtask(() async {
        await refrescarConteo(); // con sesión: sus pendientes; sin sesión: 0
        if (correo != null) await sincronizar();
      }),
      fireImmediately: true,
    );
    return 0;
  }

  /// true si hay base de datos y usuario con sesión.
  bool get activa => ref.read(puntuacionPendienteDaoProvider) != null && _correoActual() != null;

  String? _correoActual() {
    final a = ref.read(authControllerProvider);
    return a.status == AuthStatus.autenticado ? a.correo : null;
  }

  /// Guarda en el teléfono una puntuación para enviarla después.
  /// Devuelve su id (null si no hay cola).
  Future<int?> encolar({required String juego, required int tiempoSegundos, required int puntuacion}) async {
    final dao = ref.read(puntuacionPendienteDaoProvider);
    final correo = _correoActual();
    if (dao == null || correo == null) return null;
    final id = await dao.insertar(PuntuacionPendiente(
      correo: correo,
      juego: juego,
      tiempoSegundos: tiempoSegundos,
      puntuacion: puntuacion,
      creadoEn: DateTime.now().millisecondsSinceEpoch,
    ));
    await refrescarConteo();
    return id;
  }

  /// Pendientes del usuario actual según la base (no el contador en memoria).
  Future<int> pendientesActuales() async {
    final dao = ref.read(puntuacionPendienteDaoProvider);
    final correo = _correoActual();
    if (dao == null || correo == null) return 0;
    return await dao.contar(correo) ?? 0;
  }

  /// Qué pasó con la pendiente [id] en una sincronización: enviada,
  /// descartada (rechazo 4xx) o null si sigue en la cola.
  DestinoPendiente? destinoDe(int id) => _destinos.remove(id);

  Future<void> refrescarConteo() async {
    final dao = ref.read(puntuacionPendienteDaoProvider);
    final correo = _correoActual();
    state = (dao == null || correo == null) ? 0 : (await dao.contar(correo) ?? 0);
  }

  /// Envía las pendientes. Si ya hay un envío en curso, no empieza otro:
  /// devuelve el mismo Future (y al terminar se repasa la cola otra vez).
  Future<ResultadoSincronizacion> sincronizar() {
    final actual = _enCurso;
    if (actual != null) {
      _otraVez = true;
      return actual;
    }
    final nuevo = _correr();
    _enCurso = nuevo;
    return nuevo.whenComplete(() => _enCurso = null);
  }

  Future<ResultadoSincronizacion> _correr() async {
    var enviadas = 0, descartadas = 0;
    var detenida = false, sesionExpirada = false;
    do {
      _otraVez = false;
      final r = await _unaPasada();
      enviadas += r.enviadas;
      descartadas += r.descartadas;
      detenida = r.detenida;
      sesionExpirada = r.sesionExpirada;
    } while (_otraVez && !detenida);

    if (enviadas > 0) {
      // Ya están en el servidor: se refresca "Mi perfil".
      unawaited(ref.read(partidasControllerProvider.notifier).cargar());
    }
    await refrescarConteo();
    return (enviadas: enviadas, descartadas: descartadas, detenida: detenida, sesionExpirada: sesionExpirada);
  }

  Future<ResultadoSincronizacion> _unaPasada() async {
    final dao = ref.read(puntuacionPendienteDaoProvider);
    final correo = _correoActual();
    if (dao == null || correo == null) return (enviadas: 0, descartadas: 0, detenida: false, sesionExpirada: false);

    final repo = ref.read(partidasRepositoryProvider);
    var enviadas = 0, descartadas = 0;
    for (final p in await dao.pendientesDe(correo)) {
      // Si la sesión cambió a mitad del envío, no se mandan puntuaciones de un
      // usuario con el token de otro.
      if (_correoActual() != correo) {
        return (enviadas: enviadas, descartadas: descartadas, detenida: true, sesionExpirada: false);
      }
      try {
        await repo.guardar(juego: p.juego, tiempoSegundos: p.tiempoSegundos, puntuacion: p.puntuacion);
        await dao.borrar(p.id!); // solo tras 2xx
        _destinos[p.id!] = DestinoPendiente.enviada;
        enviadas++;
      } catch (e) {
        switch (clasificarFalloGuardado(e)) {
          case FalloGuardado.red:
          case FalloGuardado.servidor:
            await dao.sumarIntento(p.id!);
            return (enviadas: enviadas, descartadas: descartadas, detenida: true, sesionExpirada: false);
          case FalloGuardado.sesion:
            // Token inválido: se cierra la sesión, pero la cola se conserva.
            await ref.read(authControllerProvider.notifier).sesionExpirada();
            return (enviadas: enviadas, descartadas: descartadas, detenida: true, sesionExpirada: true);
          case FalloGuardado.rechazada:
            // 400/422...: reintentar no la arreglaría y bloquearía la cola.
            await dao.borrar(p.id!);
            _destinos[p.id!] = DestinoPendiente.descartada;
            descartadas++;
        }
      }
    }
    return (enviadas: enviadas, descartadas: descartadas, detenida: false, sesionExpirada: false);
  }
}
