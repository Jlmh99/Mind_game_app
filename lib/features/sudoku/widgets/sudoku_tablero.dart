import 'package:flutter/material.dart';
import '../sudoku_model.dart';

/// Tablero 9x9 táctil. Solo dibuja el estado; las acciones se avisan
/// hacia arriba con [onSeleccionar] (el Notifier decide qué hacer).
class SudokuTablero extends StatelessWidget {
  final SudokuState estado;
  final void Function(int fila, int col) onSeleccionar;

  const SudokuTablero({
    super.key,
    required this.estado,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    // AspectRatio 1 = tablero siempre cuadrado, ocupa el ancho disponible.
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colores.onSurface, width: 2),
        ),
        child: Column(
          children: [
            for (var f = 0; f < 9; f++)
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < 9; c++)
                      Expanded(child: _celda(context, f, c)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _celda(BuildContext context, int f, int c) {
    final colores = Theme.of(context).colorScheme;
    final valor = estado.tablero[f][c];
    final fija = estado.esFija(f, c);
    final conflicto = estado.esConflicto(f, c);

    // Líneas gruesas cada 3 celdas para separar los bloques 3x3.
    // (la orilla exterior la dibuja el borde del tablero)
    final borde = Border(
      right: c == 8
          ? BorderSide.none
          : BorderSide(
              color: colores.onSurface.withValues(alpha: c % 3 == 2 ? 1 : 0.3),
              width: c % 3 == 2 ? 2 : 0.5,
            ),
      bottom: f == 8
          ? BorderSide.none
          : BorderSide(
              color: colores.onSurface.withValues(alpha: f % 3 == 2 ? 1 : 0.3),
              width: f % 3 == 2 ? 2 : 0.5,
            ),
    );

    // Color del número: rojo si hay conflicto, normal si es fijo,
    // color primario si lo escribió el usuario.
    final colorTexto = conflicto
        ? colores.error
        : fija
            ? colores.onSurface
            : colores.primary;

    return GestureDetector(
      onTap: () => onSeleccionar(f, c),
      child: Container(
        decoration: BoxDecoration(
          color: _colorFondo(colores, f, c, valor, conflicto),
          border: borde,
        ),
        alignment: Alignment.center,
        child: valor == 0
            ? null
            // FittedBox ajusta el número al tamaño de la celda en cualquier pantalla.
            : FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    '$valor',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: fija ? FontWeight.bold : FontWeight.w500,
                      color: colorTexto,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Fondo según la prioridad: seleccionada > conflicto > número igual >
  /// misma fila/columna/bloque > normal.
  Color _colorFondo(
      ColorScheme colores, int f, int c, int valor, bool conflicto) {
    if (!estado.haySeleccion) {
      return conflicto ? colores.errorContainer : colores.surface;
    }
    final fs = estado.filaSel!, cs = estado.colSel!;

    if (f == fs && c == cs) return colores.primaryContainer;
    if (conflicto) return colores.errorContainer;

    final valorSel = estado.valorSeleccionado;
    if (valorSel != 0 && valor == valorSel) return colores.tertiaryContainer;

    final mismoBloque = f ~/ 3 == fs ~/ 3 && c ~/ 3 == cs ~/ 3;
    if (f == fs || c == cs || mismoBloque) {
      return colores.surfaceContainerHighest;
    }
    return colores.surface;
  }
}
