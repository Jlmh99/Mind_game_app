import 'package:flutter/material.dart';
import '../mobileconnect_model.dart';

/// Tarjetas con los dos dispositivos simulados: nombre y mensajes enviados.
/// Se resalta el que está seleccionado como emisor.
///
/// [compacto]: versión de una sola línea que se usa con el teclado abierto,
/// para dejar espacio a la conversación sin ocultar nombres ni contadores.
class PanelDispositivos extends StatelessWidget {
  final CanalState estado;
  final bool compacto;
  const PanelDispositivos({super.key, required this.estado, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _tarjeta(context, Dispositivo.a)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.sync_alt), // canal entre los dos
        ),
        Expanded(child: _tarjeta(context, Dispositivo.b)),
      ],
    );
  }

  Widget _tarjeta(BuildContext context, Dispositivo d) {
    final colores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final activo = estado.emisor == d;
    final enviados = estado.enviadosPor(d);
    final textoEnviados = '$enviados ${enviados == 1 ? 'enviado' : 'enviados'}';

    // FittedBox(scaleDown): si no cabe (pantalla angosta o letra grande)
    // el texto se reduce en vez de desbordarse.
    final contenido = compacto
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('${d.nombre} · $textoEnviados',
                  style: textos.labelMedium),
            ),
          )
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(children: [
                Icon(Icons.smartphone, color: colores.primary),
                const SizedBox(height: 4),
                Text(d.nombre, style: textos.titleSmall),
                Text(textoEnviados, style: textos.bodySmall),
              ]),
            ),
          );

    return Card.outlined(
      color: activo ? colorDispositivo(colores, d) : null,
      child: contenido,
    );
  }
}

/// Color de cada dispositivo (el mismo en tarjetas y burbujas).
Color colorDispositivo(ColorScheme colores, Dispositivo d) =>
    d == Dispositivo.a ? colores.primaryContainer : colores.tertiaryContainer;
