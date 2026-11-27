import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/adjuntos_cache.dart';
import '../../../../data/mensajes_repository.dart';

/// Hora de envío en formato HH:mm, en la hora del teléfono (la fecha del
/// servidor llega en UTC; toLocal no cambia una fecha que ya es local).
String horaMensaje(DateTime f) {
  final l = f.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

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
                _VistaAdjunto(mensaje: mensaje),
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
///
/// Práctica 12: la imagen ya no viene en el listado; se pide UNA vez a
/// adjuntosCacheProvider por id de mensaje. Los PDF no se descargan (solo se
/// muestran nombre y tamaño, que sí vienen en el listado).
class _VistaAdjunto extends ConsumerStatefulWidget {
  final MensajeIncidencia mensaje;
  const _VistaAdjunto({required this.mensaje});

  @override
  ConsumerState<_VistaAdjunto> createState() => _VistaAdjuntoState();
}

class _VistaAdjuntoState extends ConsumerState<_VistaAdjunto> {
  AdjuntoMensaje get _adjunto => widget.mensaje.adjunto!;

  /// Solo se descarga una imagen que no tenga bytes locales.
  bool get _hayQueDescargar => _adjunto.esImagen && _adjunto.bytes == null;

  @override
  void initState() {
    super.initState();
    _pedir();
  }

  @override
  void didUpdateWidget(covariant _VistaAdjunto anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.mensaje.id != widget.mensaje.id) _pedir();
  }

  // Fuera del build: un provider no se puede modificar mientras se construye.
  void _pedir() {
    if (!_hayQueDescargar) return;
    final m = widget.mensaje;
    Future.microtask(() {
      if (mounted) ref.read(adjuntosCacheProvider.notifier).cargar(m.incidenciaId, m.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final adjunto = _adjunto;
    if (!adjunto.esImagen) return ArchivoPdf(nombre: adjunto.nombre, bytes: adjunto.tamano);

    final local = adjunto.bytes;
    final estado = local != null
        ? AsyncData<Uint8List>(local)
        : ref.watch(adjuntosCacheProvider.select((c) => c[widget.mensaje.id])) ??
            const AsyncLoading<Uint8List>();

    return switch (estado) {
      AsyncData(:final value) => _Miniatura(bytes: value),
      AsyncError() => IconButton(
          tooltip: 'No se pudo cargar la imagen. Toca para reintentar',
          icon: const Icon(Icons.broken_image_outlined, size: 48),
          onPressed: () => ref
              .read(adjuntosCacheProvider.notifier)
              .cargar(widget.mensaje.incidenciaId, widget.mensaje.id),
        ),
      _ => const SizedBox(
          height: 160,
          width: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
    };
  }
}

/// Miniatura de 160 px de alto; al tocarla se abre la imagen completa.
class _Miniatura extends StatelessWidget {
  final Uint8List bytes;
  const _Miniatura({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          height: 160,
          fit: BoxFit.cover,
          cacheHeight: 320, // decodifica una versión pequeña: ahorra memoria
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 48),
        ),
      ),
    );
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
