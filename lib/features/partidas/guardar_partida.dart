import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'partidas_controller.dart';

/// Texto del aviso cuando la puntuación quedó en la cola offline.
const mensajePuntuacionPendiente =
    'Sin conexión: tu puntuación se guardó en el teléfono y se enviará al reconectar';

/// Guarda una partida terminada y avisa con un SnackBar si se guardó, quedó
/// pendiente (cola offline) o falló. La usan Sudoku y Crucigrama.
///
/// Devuelve el resultado para que el diálogo de victoria también lo muestre:
/// el diálogo es modal y su barrera queda encima del SnackBar (hallazgo de
/// P12), así que el estado del guardado se ve dentro del diálogo
/// (EstadoGuardadoPartida) y el SnackBar sigue para cuando el diálogo se cierra.
///
/// Si la sesión expiró no se muestra SnackBar: el AuthController ya regresa
/// al login con el mensaje "Tu sesión expiró".
Future<ResultadoGuardado> guardarPartidaYAvisar(
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

  final texto = switch (resultado) {
    ResultadoGuardado.guardada => 'Partida guardada',
    ResultadoGuardado.pendiente => mensajePuntuacionPendiente,
    ResultadoGuardado.fallo => 'No se pudo guardar la partida. Revisa tu conexión.',
    ResultadoGuardado.sesionExpirada => null, // el login ya muestra "Tu sesión expiró"
  };
  if (texto != null) {
    messenger.showSnackBar(SnackBar(
      content: Text(texto),
      behavior: SnackBarBehavior.floating,
      // El mensaje de pendiente es más largo: un poco más de tiempo para leerlo.
      duration: Duration(seconds: resultado == ResultadoGuardado.pendiente ? 6 : 4),
    ));
  }
  return resultado;
}

/// Línea con el estado del guardado, para el diálogo de victoria.
class EstadoGuardadoPartida extends StatelessWidget {
  const EstadoGuardadoPartida({super.key, required this.guardado});

  final Future<ResultadoGuardado> guardado;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return FutureBuilder<ResultadoGuardado>(
      future: guardado,
      builder: (context, snap) {
        final (IconData icono, String texto, Color color) = switch (snap.data) {
          null => (Icons.cloud_upload_outlined, 'Guardando puntuación…', colores.onSurfaceVariant),
          ResultadoGuardado.guardada => (Icons.cloud_done_outlined, 'Puntuación guardada', colores.primary),
          ResultadoGuardado.pendiente =>
            (Icons.cloud_off_outlined, 'Sin conexión: se enviará al reconectar', colores.tertiary),
          ResultadoGuardado.fallo => (Icons.error_outline, 'No se pudo guardar la puntuación', colores.error),
          ResultadoGuardado.sesionExpirada => (Icons.lock_outline, 'Tu sesión expiró', colores.error),
        };
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Icon(icono, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(texto, style: TextStyle(color: color))),
          ]),
        );
      },
    );
  }
}
