import 'dart:math';
import 'package:flutter/material.dart';
import '../crucigrama_model.dart';

// Colores fijos para las palabras correctas (Material 3 no trae un "verde").
const _verdeFondo = Color(0xFFC8E6C9);
const _verdeTexto = Color(0xFF1B5E20);

/// Tablero del crucigrama. Solo dibuja el estado; los toques se avisan
/// hacia arriba con [onTocar].
class CrucigramaTablero extends StatelessWidget {
  final CrucigramaState estado;
  final void Function(int fila, int col) onTocar;

  const CrucigramaTablero({
    super.key,
    required this.estado,
    required this.onTocar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, restricciones) {
      // Casillas cuadradas que se ajustan al ancho, con un máximo de 64 dp.
      final lado = min(restricciones.maxWidth / estado.columnas, 64.0);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var f = 0; f < estado.filas; f++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < estado.columnas; c++)
                    SizedBox.square(dimension: lado, child: _casilla(context, f, c)),
                ],
              ),
          ],
        ),
      );
    });
  }

  Widget _casilla(BuildContext context, int f, int c) {
    final colores = Theme.of(context).colorScheme;

    if (estado.esBloque(f, c)) {
      return Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: colores.inverseSurface,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }

    final letra = estado.tablero[f][c] ?? '';
    final fija = estado.esFija(f, c);
    final error = estado.esError(f, c);
    final seleccionada = estado.filaSel == f && estado.colSel == c;
    final enPalabraSel = estado.palabraSeleccionada?.contiene(f, c) ?? false;
    final enPalabraCorrecta =
        palabrasEn(f, c).any((p) => estado.esCorrecta(p));

    // Fondo según prioridad: error > seleccionada / palabra seleccionada >
    // palabra correcta > normal.
    final Color fondo;
    if (error) {
      fondo = colores.errorContainer;
    } else if (seleccionada) {
      fondo = colores.primaryContainer;
    } else if (enPalabraSel) {
      fondo = colores.secondaryContainer;
    } else if (enPalabraCorrecta) {
      fondo = _verdeFondo;
    } else {
      fondo = colores.surface;
    }

    final Color colorLetra = error
        ? colores.error
        : enPalabraCorrecta
            ? _verdeTexto
            : fija
                ? colores.onSurface
                : colores.primary;

    return GestureDetector(
      onTap: () => onTocar(f, c),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(3),
          // La casilla seleccionada lleva borde grueso para verse siempre.
          border: Border.all(
            color: seleccionada ? colores.primary : colores.outline,
            width: seleccionada ? 2.5 : 1,
          ),
        ),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(
              letra,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: colorLetra,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
