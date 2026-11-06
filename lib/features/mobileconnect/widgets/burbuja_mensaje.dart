import 'package:flutter/material.dart';
import '../mobileconnect_model.dart';
import 'panel_dispositivos.dart';

/// Burbuja de un mensaje. Dispositivo A se alinea a la izquierda y
/// Dispositivo B a la derecha, cada uno con su color.
class BurbujaMensaje extends StatelessWidget {
  final Mensaje mensaje;
  const BurbujaMensaje({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final esA = mensaje.emisor == Dispositivo.a;

    // Esquina "en punta" del lado del emisor, como en las apps de chat.
    const r = Radius.circular(16);
    final forma = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: esA ? const Radius.circular(4) : r,
      bottomRight: esA ? r : const Radius.circular(4),
    );

    return Align(
      alignment: esA ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        // La burbuja no ocupa más del 78 % del ancho.
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: colorDispositivo(colores, mensaje.emisor),
            borderRadius: forma,
          ),
          child: Column(
            crossAxisAlignment:
                esA ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              // Emisor -> receptor
              Text(
                '${mensaje.emisor.nombre} → ${mensaje.receptor.letra}',
                style: textos.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(mensaje.texto, style: textos.bodyLarge),
              const SizedBox(height: 2),
              // Hora de envío HH:mm
              Text(mensaje.horaTexto,
                  style: textos.labelSmall
                      ?.copyWith(color: colores.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
