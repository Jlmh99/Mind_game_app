import 'package:flutter/material.dart';
import '../../../../data/mensajes_repository.dart';

/// Hora de envío en formato HH:mm.
String horaMensaje(DateTime f) =>
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

String _rolLegible(String? rol) => switch (rol) {
      'ADMIN' => 'Administrador',
      'AGENTE' => 'Agente',
      _ => 'Usuario',
    };

/// Burbuja de un mensaje: los míos a la derecha, los de los demás a la izquierda.
class BurbujaChat extends StatelessWidget {
  final MensajeIncidencia mensaje;
  final bool esMio;
  const BurbujaChat({super.key, required this.mensaje, required this.esMio});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    const r = Radius.circular(16);
    final emisor = mensaje.emisor;

    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: esMio ? colores.primaryContainer : colores.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: r,
              topRight: r,
              bottomLeft: esMio ? r : const Radius.circular(4),
              bottomRight: esMio ? const Radius.circular(4) : r,
            ),
          ),
          child: Column(
            crossAxisAlignment: esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Emisor del mensaje.
              Text(
                esMio
                    ? 'Tú'
                    : '${emisor?.username ?? 'Participante'} · ${_rolLegible(emisor?.rol)}',
                style: textos.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (mensaje.adjunto != null) ...[
                const SizedBox(height: 4),
                _VistaAdjunto(adjunto: mensaje.adjunto!),
              ],
              const SizedBox(height: 2),
              Text(mensaje.texto, style: textos.bodyLarge),
              const SizedBox(height: 2),
              Text(horaMensaje(mensaje.fecha),
                  style: textos.labelSmall?.copyWith(color: colores.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Imagen en miniatura (se amplía al tocarla) o ícono con el nombre del PDF.
class _VistaAdjunto extends StatelessWidget {
  final AdjuntoMensaje adjunto;
  const _VistaAdjunto({required this.adjunto});

  @override
  Widget build(BuildContext context) {
    if (adjunto.esImagen) {
      return GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(child: Image.memory(adjunto.bytes, fit: BoxFit.contain)),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            adjunto.bytes,
            height: 160,
            fit: BoxFit.cover,
            cacheHeight: 320, // decodifica una versión pequeña: ahorra memoria
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 48),
          ),
        ),
      );
    }
    return ArchivoPdf(nombre: adjunto.nombre, bytes: adjunto.bytes.length);
  }
}

/// Ícono de PDF con su nombre y tamaño.
class ArchivoPdf extends StatelessWidget {
  final String nombre;
  final int bytes;
  const ArchivoPdf({super.key, required this.nombre, required this.bytes});

  @override
  Widget build(BuildContext context) {
    final kb = (bytes / 1024).toStringAsFixed(bytes < 10240 ? 1 : 0);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.picture_as_pdf, color: Theme.of(context).colorScheme.error, size: 32),
      const SizedBox(width: 8),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('PDF · $kb KB', style: Theme.of(context).textTheme.labelSmall),
        ]),
      ),
    ]);
  }
}
