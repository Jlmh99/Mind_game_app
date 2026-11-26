import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/partidas_repository.dart';
import '../partidas/guardado_en_curso.dart';
import '../partidas/guardar_partida.dart';
import '../partidas/partida_en_curso_pagina.dart';
import '../partidas/partidas_controller.dart';
import 'crucigrama_controller.dart';
import 'crucigrama_model.dart';
import 'widgets/captura_teclado.dart';
import 'widgets/crucigrama_pistas.dart';
import 'widgets/crucigrama_tablero.dart';

/// Pantalla del minijuego Crucigrama.
/// Es Stateful solo para manejar el FocusNode del teclado del celular;
/// todo el estado del juego vive en CrucigramaController.
class CrucigramaPage extends ConsumerStatefulWidget {
  const CrucigramaPage({super.key});

  @override
  ConsumerState<CrucigramaPage> createState() => _CrucigramaPageState();
}

class _CrucigramaPageState extends ConsumerState<CrucigramaPage>
    with PartidaEnCursoEnPagina<CrucigramaPage, CrucigramaState> {
  final _focoTeclado = FocusNode();

  // ---- Partida en curso (Práctica 14): ver PartidaEnCursoEnPagina ----
  @override
  ControladorConPartidaEnCurso<CrucigramaState> get controladorEnCurso =>
      ref.read(crucigramaControllerProvider.notifier);

  @override
  String get nombreJuego => 'Crucigrama';

  @override
  String resumenPartida(CrucigramaState g) =>
      'tiempo ${formatoTiempoCrucigrama(g.segundos)}, errores: ${g.errores}';

  @override
  void dispose() {
    _focoTeclado.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rendimiento (P14): la página NO observa "segundos". Antes, cada tic del
    // cronómetro (1 por segundo) reconstruía y repintaba toda la pantalla.
    // Ahora solo se reconstruye si cambia el tablero, la selección o el fin de
    // la partida; el reloj tiene su propio Consumer (ver _Marcador abajo).
    ref.watch(crucigramaControllerProvider.select(_vistaSinReloj));
    final estado = ref.read(crucigramaControllerProvider);
    final controller = ref.read(crucigramaControllerProvider.notifier);

    // Al completar (una sola vez por partida): ocultamos el teclado,
    // guardamos en el servidor y mostramos el diálogo de victoria.
    ref.listen(crucigramaControllerProvider, (anterior, nuevo) {
      if (anterior?.terminado != true && nuevo.terminado) {
        _focoTeclado.unfocus();
        final guardado = guardarPartidaYAvisar(
          context,
          ref,
          juego: juegoCrucigrama,
          tiempoSegundos: nuevo.segundos,
          puntuacion: nuevo.puntuacion,
        );
        _mostrarVictoria(nuevo, guardado);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Crucigrama')),
      body: SafeArea(
        child: Stack(
          children: [
            // Campo invisible que recibe las letras del teclado del celular.
            CapturaTeclado(
              focusNode: _focoTeclado,
              onLetra: controller.escribir,
              onBorrar: controller.borrar,
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Solo esto se reconstruye con cada tic del cronómetro.
                      Consumer(builder: (context, ref, _) {
                        final (segundos, errores) = ref.watch(crucigramaControllerProvider
                            .select((s) => (s.segundos, s.errores)));
                        return _Marcador(segundos: segundos, errores: errores);
                      }),
                      const SizedBox(height: 12),
                      // RepaintBoundary: el tic del reloj ya no repinta el tablero,
                      // y al moverse por el teclado se mueve su capa sin repintarla.
                      RepaintBoundary(
                        child: CrucigramaTablero(
                          estado: estado,
                          onTocar: (f, c) {
                            controller.seleccionarCasilla(f, c);
                            CapturaTeclado.mostrar(_focoTeclado);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _PistaActual(estado: estado),
                      const SizedBox(height: 12),
                      RepaintBoundary(
                        child: CrucigramaPistas(
                          estado: estado,
                          onTocarPista: (p) {
                            controller.seleccionarPalabra(p);
                            CapturaTeclado.mostrar(_focoTeclado);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reiniciar'),
                        onPressed: controller.reiniciar,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Diálogo de victoria con tiempo, errores y puntuación.
  /// [guardado]: resultado de guardar la puntuación; se muestra dentro del
  /// diálogo porque su barrera tapa el SnackBar (hallazgo de P12).
  void _mostrarVictoria(CrucigramaState e, Future<ResultadoGuardado> guardado) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.emoji_events, size: 48),
        title: const Text('¡Crucigrama completado!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _filaDato('Tiempo', formatoTiempoCrucigrama(e.segundos)),
            _filaDato('Errores', '${e.errores}'),
            const Divider(),
            _filaDato('Puntuación', '${e.puntuacion}', destacado: true),
            EstadoGuardadoPartida(guardado: guardado),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // cierra el diálogo
              Navigator.of(context).pop(); // regresa al inicio
            },
            child: const Text('Volver al inicio'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(crucigramaControllerProvider.notifier).reiniciar();
            },
            child: const Text('Jugar de nuevo'),
          ),
        ],
      ),
    );
  }

  Widget _filaDato(String etiqueta, String valor, {bool destacado = false}) {
    final estilo = TextStyle(
      fontSize: destacado ? 20 : 16,
      fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(etiqueta, style: estilo), Text(valor, style: estilo)],
      ),
    );
  }
}

/// Lo que la página observa del estado: todo menos el cronómetro. Si un tic
/// solo cambia "segundos", el registro es igual (mismo tablero) y no hay rebuild.
(List<List<String?>>, int?, int?, Orientacion, bool) _vistaSinReloj(CrucigramaState s) =>
    (s.tablero, s.filaSel, s.colSel, s.orientacion, s.terminado);

/// Fila superior con el cronómetro y el contador de errores.
class _Marcador extends StatelessWidget {
  final int segundos;
  final int errores;
  const _Marcador({required this.segundos, required this.errores});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;

    // Flexible + FittedBox(scaleDown): en pantallas angostas o con letra
    // grande el contenido se reduce en vez de desbordarse.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(children: [
              const Icon(Icons.timer_outlined),
              const SizedBox(width: 6),
              Text(formatoTiempoCrucigrama(segundos),
                  style: textos.titleLarge),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(children: [
              Icon(Icons.close, color: colores.error),
              const SizedBox(width: 6),
              Text('Errores: $errores', style: textos.titleMedium),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Muestra la pista de la palabra seleccionada justo debajo del tablero,
/// para que se vea aunque el teclado tape la lista completa.
class _PistaActual extends StatelessWidget {
  final CrucigramaState estado;
  const _PistaActual({required this.estado});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final p = estado.palabraSeleccionada;

    final texto = p == null
        ? 'Toca una casilla o una pista para empezar.'
        : p.pista;
    final icono = p == null
        ? Icons.touch_app_outlined
        : p.orientacion == Orientacion.horizontal
            ? Icons.arrow_forward
            : Icons.arrow_downward;

    return Card.filled(
      color: colores.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(icono, color: colores.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto,
                style: TextStyle(color: colores.onSecondaryContainer)),
          ),
        ]),
      ),
    );
  }
}
