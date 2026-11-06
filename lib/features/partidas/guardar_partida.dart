import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'partidas_controller.dart';

/// Guarda una partida terminada y avisa con un SnackBar si se guardó o falló.
/// La usan Sudoku y Crucigrama para no repetir este código.
///
/// Si la sesión expiró no se muestra SnackBar: el AuthController ya regresa
/// al login con el mensaje "Tu sesión expiró".
Future<void> guardarPartidaYAvisar(
  BuildContext context,
  WidgetRef ref, {
  required String juego,
  required int tiempoSegundos,
  required int puntuacion,
}) async {
  // Se toma el ScaffoldMessenger ANTES del await: es el de la app completa,
  // así el aviso se ve aunque el usuario ya haya salido de la pantalla del juego.
  final messenger = ScaffoldMessenger.of(context);

  final resultado = await ref.read(partidasControllerProvider.notifier).guardar(
        juego: juego,
        tiempoSegundos: tiempoSegundos,
        puntuacion: puntuacion,
      );

  switch (resultado) {
    case ResultadoGuardado.guardada:
      messenger.showSnackBar(const SnackBar(
        content: Text('Partida guardada'),
        behavior: SnackBarBehavior.floating,
      ));
    case ResultadoGuardado.fallo:
      messenger.showSnackBar(const SnackBar(
        content: Text('No se pudo guardar la partida. Revisa tu conexión.'),
        behavior: SnackBarBehavior.floating,
      ));
    case ResultadoGuardado.sesionExpirada:
      break; // el login ya muestra "Tu sesión expiró"
  }
}
