import 'package:flutter/material.dart';

/// Teclado numérico en pantalla: 1-9 y borrar, en dos filas
/// (cabe bien en un celular en vertical).
class SudokuTeclado extends StatelessWidget {
  final void Function(int numero) onNumero;
  final VoidCallback onBorrar;
  final bool habilitado; // false cuando el juego ya terminó

  const SudokuTeclado({
    super.key,
    required this.onNumero,
    required this.onBorrar,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _fila([for (var n = 1; n <= 5; n++) _botonNumero(n)]),
        const SizedBox(height: 8),
        _fila([
          for (var n = 6; n <= 9; n++) _botonNumero(n),
          _boton(
            onPressed: onBorrar,
            child: const Icon(Icons.backspace_outlined),
            tooltip: 'Borrar',
          ),
        ]),
      ],
    );
  }

  Widget _fila(List<Widget> botones) => Row(
        children: [
          for (var i = 0; i < botones.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: botones[i]),
          ],
        ],
      );

  Widget _botonNumero(int n) => _boton(
        onPressed: () => onNumero(n),
        child: Text('$n', style: const TextStyle(fontSize: 22)),
      );

  Widget _boton({
    required VoidCallback onPressed,
    required Widget child,
    String? tooltip,
  }) {
    final boton = SizedBox(
      height: 52,
      child: FilledButton.tonal(
        onPressed: habilitado ? onPressed : null,
        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
        child: child,
      ),
    );
    return tooltip == null ? boton : Tooltip(message: tooltip, child: boton);
  }
}
