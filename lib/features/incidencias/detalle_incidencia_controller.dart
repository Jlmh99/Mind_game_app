import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/incidencias_repository.dart';
import '../auth/auth_controller.dart';
import 'incidencias_comun.dart';

class DetalleIncidenciaState {
  final Incidencia? incidencia;
  final bool cargando; // primera carga
  final bool procesando; // guardando un cambio
  final bool conflicto; // el servidor respondió 409
  final String? error; // mensaje genérico de carga
  final DateTime? ultimaActualizacion;
  final List<UsuarioResumen> agentes; // solo se llena para ADMIN

  const DetalleIncidenciaState({
    this.incidencia,
    this.cargando = false,
    this.procesando = false,
    this.conflicto = false,
    this.error,
    this.ultimaActualizacion,
    this.agentes = const [],
  });

  DetalleIncidenciaState copyWith({
    Incidencia? incidencia,
    bool? cargando,
    bool? procesando,
    bool? conflicto,
    String? error, // null limpia el error
    DateTime? ultimaActualizacion,
    List<UsuarioResumen>? agentes,
  }) =>
      DetalleIncidenciaState(
        incidencia: incidencia ?? this.incidencia,
        cargando: cargando ?? this.cargando,
        procesando: procesando ?? this.procesando,
        conflicto: conflicto ?? this.conflicto,
        error: error,
        ultimaActualizacion: ultimaActualizacion ?? this.ultimaActualizacion,
        agentes: agentes ?? this.agentes,
      );
}

/// Un controller por incidencia (family por id). autoDispose: al salir del
/// detalle se destruye y ref.onDispose cancela el Timer.
final detalleIncidenciaProvider = NotifierProvider.autoDispose
    .family<DetalleIncidenciaController, DetalleIncidenciaState, int>(
        DetalleIncidenciaController.new);

class DetalleIncidenciaController
    extends AutoDisposeFamilyNotifier<DetalleIncidenciaState, int> {
  IncidenciasRepository get _repo => ref.read(incidenciasRepositoryProvider);

  Timer? _timer;
  bool _activo = false;
  bool _pidiendo = false;

  @override
  DetalleIncidenciaState build(int id) {
    final auth = ref.watch(authControllerProvider
        .select((s) => (s.status == AuthStatus.autenticado, s.rol)));
    _activo = true;
    ref.onDispose(() {
      _activo = false;
      _timer?.cancel();
    });
    if (!auth.$1) return const DetalleIncidenciaState();

    final rol = rolDesde(auth.$2);
    // Sincronización: ADMIN y AGENTE cada 5 s; USER con pull-to-refresh.
    if (usaSincronizacionAutomatica(rol)) {
      _timer = Timer.periodic(intervaloSincronizacion, (_) => cargar(silencioso: true));
    }
    Future.microtask(() async {
      await cargar();
      if (puedeAsignar(rol)) await _cargarAgentes();
    });
    return const DetalleIncidenciaState(cargando: true);
  }

  /// Pide la incidencia al backend. [silencioso]: sin indicador (Timer).
  Future<void> cargar({bool silencioso = false}) async {
    if (_pidiendo || !_activo) return;
    _pidiendo = true;
    if (!silencioso) state = state.copyWith(cargando: true, error: state.error);

    late Incidencia inc;
    final r = await ejecutarAccion(ref, () async => inc = await _repo.obtener(arg));
    _pidiendo = false;
    if (!_activo || r == ResultadoAccion.sesionExpirada) return;

    state = r == ResultadoAccion.ok
        ? state.copyWith(
            incidencia: inc, cargando: false, ultimaActualizacion: DateTime.now())
        : state.copyWith(cargando: false, error: mensajeDe(r));
  }

  /// Botón "Recargar" del aviso de conflicto: trae la versión actual.
  Future<void> recargar() async {
    state = state.copyWith(conflicto: false, error: state.error);
    await cargar();
  }

  // ---------------- Acciones (todas envían la versión) ----------------

  /// Editar título y descripción. [version] es la que se leyó al abrir el
  /// formulario: si alguien guardó mientras tanto, el servidor responde 409.
  Future<ResultadoAccion> editarTexto(
          {required String titulo, required String descripcion, required int version}) =>
      _guardar(() => _repo.actualizar(arg,
          version: version, titulo: titulo, descripcion: descripcion));

  Future<ResultadoAccion> cambiarEstado(EstadoIncidencia estado) =>
      _guardar(() => _repo.actualizar(arg, version: _versionActual, estado: estado));

  Future<ResultadoAccion> cambiarPrioridad(PrioridadIncidencia prioridad) =>
      _guardar(() => _repo.actualizar(arg, version: _versionActual, prioridad: prioridad));

  Future<ResultadoAccion> asignar(int agenteId) =>
      _guardar(() => _repo.asignar(arg, agenteId));

  Future<ResultadoAccion> eliminar() async {
    state = state.copyWith(procesando: true, error: state.error);
    final r = await ejecutarAccion(ref, () => _repo.eliminar(arg));
    if (_activo) state = state.copyWith(procesando: false, error: state.error);
    return r;
  }

  // ---------------- Auxiliares ----------------

  int get _versionActual => state.incidencia?.version ?? 0;

  /// Ejecuta un cambio y actualiza la incidencia con lo que devuelve el servidor.
  Future<ResultadoAccion> _guardar(Future<Incidencia> Function() cambio) async {
    if (state.procesando) return ResultadoAccion.error;
    state = state.copyWith(procesando: true, error: state.error);

    late Incidencia actualizada;
    final r = await ejecutarAccion(ref, () async => actualizada = await cambio());
    if (!_activo) return r;

    state = switch (r) {
      ResultadoAccion.ok => state.copyWith(
          incidencia: actualizada,
          procesando: false,
          conflicto: false,
          ultimaActualizacion: DateTime.now()),
      ResultadoAccion.conflicto =>
        state.copyWith(procesando: false, conflicto: true, error: state.error),
      _ => state.copyWith(procesando: false, error: state.error),
    };
    return r;
  }

  Future<void> _cargarAgentes() async {
    late List<UsuarioResumen> agentes;
    final r = await ejecutarAccion(ref, () async => agentes = await _repo.agentes());
    if (r == ResultadoAccion.ok && _activo) {
      state = state.copyWith(agentes: agentes, error: state.error);
    }
  }
}
