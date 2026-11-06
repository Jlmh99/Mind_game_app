import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sudoku_controller.dart';
import 'sudoku_model.dart';
import 'widgets/sudoku_tablero.dart';
import 'widgets/sudoku_teclado.dart';

/// Pantalla del minijuego Sudoku.
/// La lógica vive en SudokuController; aquí solo se dibuja y se avisan acciones.
class SudokuPage extends ConsumerWidget {
  const SudokuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(sudokuControllerProvider);
    final controller = ref.read(sudokuControllerProvider.notifier);

    // Cuando el juego pasa a "terminado" mostramos el diálogo una sola vez.
    ref.listen(sudokuControllerProvider, (anterior, nuevo) {
      if (anterior?.terminado != true && nuevo.terminado) {
        _mostrarVictoria(context, ref, nuevo);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku')),
      body: SafeArea(
        // Scroll por si la pantalla es muy baja; en celulares normales cabe completo.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            // En tablets evita que el tablero crezca demasiado.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  _Marcador(segundos: estado.segundos, errores: estado.errores),
                  const SizedBox(height: 12),
                  SudokuTablero(
                    estado: estado,
                    onSeleccionar: controller.seleccionar,
                  ),
                  const SizedBox(height: 16),
                  SudokuTeclado(
                    habilitado: !estado.terminado,
                    onNumero: controller.colocar,
                    onBorrar: controller.borrar,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reiniciar'),
                          onPressed: controller.reiniciar,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.casino_outlined),
                          label: const Text('Nuevo'),
                          onPressed: controller.nuevo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Diálogo de victoria con tiempo, errores y puntuación.
  void _mostrarVictoria(BuildContext context, WidgetRef ref, SudokuState e) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // obliga a elegir una opción
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.emoji_events, size: 48),
        title: const Text('¡Sudoku completado!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _filaDato('Tiempo', formatoTiempo(e.segundos)),
            _filaDato('Errores', '${e.errores}'),
            const Divider(),
            _filaDato('Puntuación', '${e.puntuacion}', destacado: true),
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
              ref.read(sudokuControllerProvider.notifier).nuevo();
            },
            child: const Text('Jugar otro'),
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

/// Fila superior con el cronómetro y el contador de errores.
class _Marcador extends StatelessWidget {
  final int segundos;
  final int errores;
  const _Marcador({required this.segundos, required this.errores});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          const Icon(Icons.timer_outlined),
          const SizedBox(width: 6),
          Text(formatoTiempo(segundos), style: textos.titleLarge),
        ]),
        Row(children: [
          Icon(Icons.close, color: colores.error),
          const SizedBox(width: 6),
          Text('Errores: $errores', style: textos.titleMedium),
        ]),
      ],
    );
  }
}
