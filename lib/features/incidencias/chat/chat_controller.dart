import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/adjuntos_cache.dart';
import '../../../data/mensajes_repository.dart';
import '../../auth/auth_controller.dart';
import '../incidencias_comun.dart';
import 'chat_comun.dart';

/// Error al cargar los mensajes (no de permiso): la pantalla agrega la nota
/// de que el servidor puede tardar si estuvo inactivo.
const mensajeErrorCargaMensajes = 'No se pudieron cargar los mensajes';

/// Clave de un chat: (id de la incidencia, canal).
typedef ClaveChat = (int, CanalChat);

// ---------------------------------------------------------------------------
// "Limpiar historial" (solo vista local, NO borra del servidor)
// ---------------------------------------------------------------------------

/// Guarda, por chat, el id del último mensaje oculto. Vive mientras la app
/// esté abierta (no es autoDispose) y se reinicia si cambia el usuario.
final limpiezaChatProvider =
    NotifierProvider<LimpiezaChatController, Map<ClaveChat, int>>(LimpiezaChatController.new);

class LimpiezaChatController extends Notifier<Map<ClaveChat, int>> {
  @override
  Map<ClaveChat, int> build() {
    ref.watch(authControllerProvider.select((s) => s.correo));
    return const {};
  }

  void ocultarHasta(ClaveChat clave, int id) => state = {...state, clave: id};
}

// ---------------------------------------------------------------------------
// Estado y controller del chat
// ---------------------------------------------------------------------------

class ChatState {
  final List<MensajeIncidencia> mensajes; // todos los que devolvió el servidor
  final int ocultarHastaId; // mensajes con id <= este no se muestran (limpieza local)
  final bool cargando;
  final bool enviando;
  final String? error; // mensaje genérico
  final DateTime? ultimaActualizacion;
  final int avisosNuevos; // sube cada vez que llegan mensajes nuevos de otros
  final String? textoAviso; // "Nuevo mensaje de ..."

  const ChatState({
    this.mensajes = const [],
    this.ocultarHastaId = 0,
    this.cargando = false,
    this.enviando = false,
    this.error,
    this.ultimaActualizacion,
    this.avisosNuevos = 0,
    this.textoAviso,
  });

  /// Lo que se muestra: sin los mensajes ocultados con "Limpiar historial".
  List<MensajeIncidencia> get visibles =>
      mensajes.where((m) => m.id > ocultarHastaId).toList();

  ChatState copyWith({
    List<MensajeIncidencia>? mensajes,
    int? ocultarHastaId,
    bool? cargando,
    bool? enviando,
    String? error, // null limpia el error
    DateTime? ultimaActualizacion,
    int? avisosNuevos,
    String? textoAviso,
  }) =>
      ChatState(
        mensajes: mensajes ?? this.mensajes,
        ocultarHastaId: ocultarHastaId ?? this.ocultarHastaId,
        cargando: cargando ?? this.cargando,
        enviando: enviando ?? this.enviando,
        error: error,
        ultimaActualizacion: ultimaActualizacion ?? this.ultimaActualizacion,
        avisosNuevos: avisosNuevos ?? this.avisosNuevos,
        textoAviso: textoAviso ?? this.textoAviso,
      );
}

/// Un controller por (incidencia, canal). autoDispose: al salir de la pantalla
/// (o cambiar de pestaña) se destruye y ref.onDispose cancela el Timer.
final chatProvider =
    NotifierProvider.autoDispose.family<ChatController, ChatState, ClaveChat>(ChatController.new);

class ChatController extends AutoDisposeFamilyNotifier<ChatState, ClaveChat> {
  MensajesRepository get _repo => ref.read(mensajesRepositoryProvider);

  Timer? _timer;
  bool _activo = false;
  bool _pidiendo = false;
  String? _miCorreo;

  @override
  ChatState build(ClaveChat clave) {
    final auth = ref.watch(authControllerProvider
        .select((s) => (s.status == AuthStatus.autenticado, s.rol, s.correo)));
    _activo = true;
    _miCorreo = auth.$3;
    ref.onDispose(() {
      _activo = false;
      _timer?.cancel();
    });
    final ocultos = ref.read(limpiezaChatProvider)[clave] ?? 0;
    if (!auth.$1) return ChatState(ocultarHastaId: ocultos);

    // ADMIN y AGENTE: cada 3 s. USER: pull-to-refresh.
    if (usaSincronizacionAutomatica(rolDesde(auth.$2))) {
      _timer = Timer.periodic(intervaloChat, (_) => cargar(silencioso: true));
    }
    Future.microtask(cargar);
    return ChatState(cargando: true, ocultarHastaId: ocultos);
  }

  bool _esMio(MensajeIncidencia m) =>
      _miCorreo != null &&
      (m.emisor?.email ?? '').trim().toLowerCase() == _miCorreo!.trim().toLowerCase();

  /// Trae los mensajes del canal. Avisa si llegaron mensajes nuevos de otros.
  Future<void> cargar({bool silencioso = false}) async {
    if (_pidiendo || !_activo) return;
    _pidiendo = true;
    if (!silencioso) state = state.copyWith(cargando: true, error: state.error);

    late List<MensajeIncidencia> lista;
    final r = await ejecutarAccion(ref, () async => lista = await _repo.listar(arg.$1, arg.$2));
    _pidiendo = false;
    if (!_activo || r == ResultadoAccion.sesionExpirada) return;

    if (r != ResultadoAccion.ok) {
      // 403 en el canal interno -> "No tienes permiso para esta acción".
      state = state.copyWith(
          cargando: false,
          error: r == ResultadoAccion.sinPermiso
              ? mensajeSinPermiso
              : mensajeErrorCargaMensajes);
      return;
    }

    // En la primera carga no se avisa (todo es "historial").
    final primeraCarga = state.ultimaActualizacion == null;
    final conocidos = {for (final m in state.mensajes) m.id};
    final nuevosAjenos = primeraCarga
        ? const <MensajeIncidencia>[]
        : lista
            .where((m) => !conocidos.contains(m.id) && !_esMio(m) && m.id > state.ocultarHastaId)
            .toList();

    state = state.copyWith(
      mensajes: lista,
      cargando: false,
      ultimaActualizacion: DateTime.now(),
      avisosNuevos: nuevosAjenos.isEmpty ? null : state.avisosNuevos + 1,
      textoAviso: nuevosAjenos.isEmpty
          ? null
          : nuevosAjenos.length == 1
              ? 'Nuevo mensaje de ${nuevosAjenos.first.emisor?.username ?? 'otro participante'}'
              : '${nuevosAjenos.length} mensajes nuevos',
    );
  }

  /// Envía un mensaje en este canal. El texto ya debe venir validado
  /// (por si acaso se revisa otra vez y no se llama al servidor si es inválido).
  Future<ResultadoAccion> enviar(String texto, {AdjuntoMensaje? adjunto}) async {
    final limpio = texto.trim();
    if (validarTextoMensaje(limpio) != null || state.enviando) return ResultadoAccion.error;
    state = state.copyWith(enviando: true, error: state.error);

    late MensajeIncidencia enviado;
    final r = await ejecutarAccion(ref, () async {
      enviado = await _repo.enviar(arg.$1, texto: limpio, canal: arg.$2, adjunto: adjunto);
    });
    // Los bytes del adjunto propio ya están en el teléfono: se guardan en la
    // caché para no volver a descargarlos (Práctica 12).
    final bytes = adjunto?.bytes;
    if (r == ResultadoAccion.ok && bytes != null && adjunto!.esImagen) {
      ref.read(adjuntosCacheProvider.notifier).sembrar(enviado.id, bytes);
    }
    if (!_activo) return r;

    final yaEsta = r == ResultadoAccion.ok && state.mensajes.any((m) => m.id == enviado.id);
    state = state.copyWith(
      enviando: false,
      error: state.error,
      mensajes: r == ResultadoAccion.ok && !yaEsta ? [...state.mensajes, enviado] : null,
    );
    return r;
  }

  /// Oculta lo que hay en pantalla. NO borra nada del servidor.
  void limpiarHistorial() {
    if (state.mensajes.isEmpty) return;
    final ultimo = state.mensajes.map((m) => m.id).reduce(max);
    ref.read(limpiezaChatProvider.notifier).ocultarHasta(arg, ultimo);
    state = state.copyWith(ocultarHastaId: ultimo, error: state.error);
  }
}
