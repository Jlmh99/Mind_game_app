import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_controller.dart';
import 'mensajes_repository.dart';

/// Caché en memoria de los adjuntos del chat, por id de mensaje (Práctica 12).
///
/// Antes, cada recarga del chat (cada 3 s para ADMIN y AGENTE) traía y
/// decodificaba el Base64 de TODOS los adjuntos. Ahora el listado solo trae
/// nombre/tipo/tamaño y cada imagen se descarga UNA sola vez:
///  - si ya se está descargando o ya está lista, no se vuelve a pedir;
///  - si falló, se puede reintentar;
///  - siempre se entrega la MISMA instancia de bytes, así Image.memory no
///    vuelve a decodificar la imagen en cada recarga;
///  - se vacía al cambiar de usuario (un USER nunca ve bytes que bajó un AGENTE).
///
/// No es autoDispose: sobrevive al salir y volver a entrar al chat.
final adjuntosCacheProvider =
    NotifierProvider<AdjuntosCache, Map<int, AsyncValue<Uint8List>>>(AdjuntosCache.new);

class AdjuntosCache extends Notifier<Map<int, AsyncValue<Uint8List>>> {
  // Sube en el MISMO instante en que cambia el usuario (ref.listen avisa de
  // inmediato; build() corre después, de forma perezosa). Una descarga que
  // empezó con otra sesión y termina tarde no se guarda.
  int _sesion = 0;

  @override
  Map<int, AsyncValue<Uint8List>> build() {
    final correo = authControllerProvider.select((s) => s.correo);
    ref.watch(correo); // al cambiar de usuario, la caché se vacía
    ref.listen(correo, (_, _) => _sesion++);
    return const {};
  }

  /// Descarga el adjunto si no está listo ni en camino (o si falló antes).
  void cargar(int incidenciaId, int mensajeId) {
    final actual = state[mensajeId];
    if (actual != null && !actual.hasError) return;

    final sesion = _sesion;
    state = {...state, mensajeId: const AsyncLoading()};
    ref.read(mensajesRepositoryProvider).descargarAdjunto(incidenciaId, mensajeId).then(
      (bytes) {
        if (sesion == _sesion) state = {...state, mensajeId: AsyncData(bytes)};
      },
      onError: (Object e, StackTrace st) {
        // No se registra nada: el error puede venir de un 403 o de la red.
        if (sesion == _sesion) state = {...state, mensajeId: AsyncError(e, st)};
      },
    );
  }

  /// Guarda los bytes de un adjunto propio recién enviado (no hace falta bajarlo).
  void sembrar(int mensajeId, Uint8List bytes) =>
      state = {...state, mensajeId: AsyncData(bytes)};
}
