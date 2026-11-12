import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/incidencias_repository.dart';
import '../auth/auth_controller.dart';
import 'incidencias_comun.dart';

class ListaIncidenciasState {
  final List<Incidencia> incidencias; // lo que devolvió el backend para este rol
  final EstadoIncidencia? filtro; // null = todos los estados
  final bool cargando;
  final String? error; // mensaje genérico
  final DateTime? ultimaActualizacion;

  const ListaIncidenciasState({
    this.incidencias = const [],
    this.filtro,
    this.cargando = false,
    this.error,
    this.ultimaActualizacion,
  });

  /// Incidencias que se muestran con el filtro de estado aplicado.
  List<Incidencia> get visibles => filtro == null
      ? incidencias
      : incidencias.where((i) => i.estado == filtro).toList();

  int cuantas(EstadoIncidencia? e) =>
      e == null ? incidencias.length : incidencias.where((i) => i.estado == e).length;

  ListaIncidenciasState copyWith({
    List<Incidencia>? incidencias,
    EstadoIncidencia? filtro,
    bool quitarFiltro = false,
    bool? cargando,
    String? error, // null limpia el error
    DateTime? ultimaActualizacion,
  }) =>
      ListaIncidenciasState(
        incidencias: incidencias ?? this.incidencias,
        filtro: quitarFiltro ? null : (filtro ?? this.filtro),
        cargando: cargando ?? this.cargando,
        error: error,
        ultimaActualizacion: ultimaActualizacion ?? this.ultimaActualizacion,
      );
}

/// autoDispose: al salir de la pantalla se destruye y ref.onDispose cancela el Timer.
final listaIncidenciasProvider =
    NotifierProvider.autoDispose<ListaIncidenciasController, ListaIncidenciasState>(
        ListaIncidenciasController.new);

class ListaIncidenciasController extends AutoDisposeNotifier<ListaIncidenciasState> {
  IncidenciasRepository get _repo => ref.read(incidenciasRepositoryProvider);

  Timer? _timer;
  bool _activo = false; // false después de dispose: no tocar el estado
  bool _pidiendo = false; // evita dos peticiones a la vez

  @override
  ListaIncidenciasState build() {
    final auth = ref.watch(authControllerProvider
        .select((s) => (s.status == AuthStatus.autenticado, s.rol)));
    _activo = true;
    ref.onDispose(() {
      _activo = false;
      _timer?.cancel();
    });
    if (!auth.$1) return const ListaIncidenciasState();

    // Sincronización: ADMIN y AGENTE cada 5 s; USER solo con pull-to-refresh.
    if (usaSincronizacionAutomatica(rolDesde(auth.$2))) {
      _timer = Timer.periodic(intervaloSincronizacion, (_) => cargar(silencioso: true));
    }
    Future.microtask(cargar);
    return const ListaIncidenciasState(cargando: true);
  }

  /// Pide la lista al backend. [silencioso]: sin indicador de carga (Timer).
  Future<void> cargar({bool silencioso = false}) async {
    if (_pidiendo || !_activo) return;
    _pidiendo = true;
    if (!silencioso) state = state.copyWith(cargando: true, error: state.error);

    late List<Incidencia> lista;
    final r = await ejecutarAccion(ref, () async => lista = await _repo.listar());
    _pidiendo = false;
    if (!_activo || r == ResultadoAccion.sesionExpirada) return;

    state = r == ResultadoAccion.ok
        ? state.copyWith(
            incidencias: lista, cargando: false, ultimaActualizacion: DateTime.now())
        // Se conserva la lista anterior y se muestra un mensaje genérico.
        : state.copyWith(
            cargando: false,
            error: r == ResultadoAccion.sinPermiso ? mensajeSinPermiso : mensajeErrorCarga);
  }

  void cambiarFiltro(EstadoIncidencia? estado) => state = estado == null
      ? state.copyWith(quitarFiltro: true, error: state.error)
      : state.copyWith(filtro: estado, error: state.error);

  /// Crea una incidencia y la agrega al inicio de la lista.
  Future<ResultadoAccion> crear({
    required String titulo,
    required String descripcion,
    required PrioridadIncidencia prioridad,
  }) async {
    late Incidencia nueva;
    final r = await ejecutarAccion(ref, () async {
      nueva = await _repo.crear(titulo: titulo, descripcion: descripcion, prioridad: prioridad);
    });
    if (r == ResultadoAccion.ok && _activo) {
      state = state.copyWith(incidencias: [nueva, ...state.incidencias], error: state.error);
    }
    return r;
  }
}
