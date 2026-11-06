import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de texto invisible que recibe las letras del teclado del celular.
///
/// Truco para detectar también la tecla de borrar: el campo siempre contiene
/// un espacio "centinela".
///  - Si el texto queda vacío      -> el usuario presionó borrar.
///  - Si el texto crece            -> el usuario escribió una letra nueva.
/// Después de cada cambio se restablece el centinela.
class CapturaTeclado extends StatefulWidget {
  final FocusNode focusNode;
  final void Function(String letra) onLetra;
  final VoidCallback onBorrar;

  const CapturaTeclado({
    super.key,
    required this.focusNode,
    required this.onLetra,
    required this.onBorrar,
  });

  /// Muestra el teclado: pide el foco o, si ya lo tiene (el usuario lo
  /// había ocultado con "atrás"), lo vuelve a abrir.
  static void mostrar(FocusNode focusNode) {
    if (focusNode.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      focusNode.requestFocus();
    }
  }

  @override
  State<CapturaTeclado> createState() => _CapturaTecladoState();
}

class _CapturaTecladoState extends State<CapturaTeclado> {
  static const _centinela = ' ';
  static final _soloLetras = RegExp(r'[a-zA-ZñÑáéíóúÁÉÍÓÚüÜ]');

  final _controller = TextEditingController(text: _centinela);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _alCambiar(String valor) {
    if (valor.isEmpty) {
      widget.onBorrar();
    } else if (valor.length > _centinela.length) {
      // Tomamos el último carácter escrito y solo aceptamos letras.
      final ultimo = valor.characters.last;
      if (_soloLetras.hasMatch(ultimo)) widget.onLetra(ultimo.toUpperCase());
    }
    // Restablecer el centinela con el cursor al final.
    _controller.value = const TextEditingValue(
      text: _centinela,
      selection: TextSelection.collapsed(offset: _centinela.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1x1 y transparente: existe para el teclado, pero no se ve.
    return SizedBox(
      width: 1,
      height: 1,
      child: Opacity(
        opacity: 0,
        child: TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          onChanged: _alCambiar,
          // Sin autocorrección ni sugerencias: cada tecla llega tal cual.
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          textCapitalization: TextCapitalization.characters,
          showCursor: false,
          enableInteractiveSelection: false,
          decoration: const InputDecoration.collapsed(hintText: ''),
        ),
      ),
    );
  }
}
