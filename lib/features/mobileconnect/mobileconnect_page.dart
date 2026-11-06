import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'canal_controller.dart';
import 'mobileconnect_model.dart';
import 'widgets/burbuja_mensaje.dart';
import 'widgets/panel_dispositivos.dart';

/// MobileConnect: simula el intercambio de mensajes entre dos dispositivos
/// dentro de la app. El "canal" es el Notifier canalProvider (en memoria).
class MobileConnectPage extends ConsumerStatefulWidget {
  const MobileConnectPage({super.key});

  @override
  ConsumerState<MobileConnectPage> createState() => _MobileConnectPageState();
}

class _MobileConnectPageState extends ConsumerState<MobileConnectPage> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  /// Muestra un SnackBar reemplazando el anterior (no se forman colas).
  void _aviso(String mensaje) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(mensaje),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  void _enviar() {
    final enviado = ref.read(canalProvider.notifier).enviar(_texto.text);
    if (enviado == null) {
      // No se permiten mensajes vacíos ni con solo espacios.
      _aviso('Escribe un mensaje antes de enviar');
      return;
    }
    _texto.clear();
    _aviso('Mensaje enviado de ${enviado.emisor.letra} a ${enviado.receptor.letra}');
  }

  Future<void> _confirmarLimpiar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_outlined),
        title: const Text('¿Borrar historial?'),
        content: const Text(
            'Se eliminarán todos los mensajes y los contadores volverán a 0.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      ref.read(canalProvider.notifier).limpiar();
      _aviso('Historial borrado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(canalProvider);
    final canal = ref.read(canalProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MobileConnect'),
        actions: [
          IconButton(
            tooltip: 'Limpiar historial',
            icon: const Icon(Icons.delete_sweep_outlined),
            // Sin mensajes no hay nada que borrar.
            onPressed: estado.mensajes.isEmpty ? null : _confirmarLimpiar,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Nombres de los dispositivos y contador de enviados.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              // Con el teclado abierto se usa la versión compacta (una línea)
              // para que la conversación y el campo de texto quepan.
              child: PanelDispositivos(
                estado: estado,
                compacto: MediaQuery.viewInsetsOf(context).bottom > 0,
              ),
            ),
            const Divider(height: 16),

            // Conversación.
            Expanded(
              child: estado.mensajes.isEmpty
                  ? const _SinMensajes()
                  : ListView.builder(
                      // reverse: el último mensaje queda abajo y siempre visible.
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: estado.mensajes.length,
                      itemBuilder: (_, i) => BurbujaMensaje(
                        mensaje: estado.mensajes[estado.mensajes.length - 1 - i],
                      ),
                    ),
            ),

            // Redactar: selector de emisor + campo + enviar.
            _Redactor(
              emisor: estado.emisor,
              controller: _texto,
              onCambiarEmisor: canal.cambiarEmisor,
              onEnviar: _enviar,
            ),
          ],
        ),
      ),
    );
  }
}

/// Texto cuando aún no hay mensajes.
class _SinMensajes extends StatelessWidget {
  const _SinMensajes();

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.forum_outlined, size: 56, color: colores.onSurfaceVariant),
          const SizedBox(height: 8),
          Text('Aún no hay mensajes.\nElige un dispositivo y escribe el primero.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colores.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// Parte inferior: SegmentedButton para el emisor, campo de texto y botón enviar.
class _Redactor extends StatelessWidget {
  final Dispositivo emisor;
  final TextEditingController controller;
  final ValueChanged<Dispositivo> onCambiarEmisor;
  final VoidCallback onEnviar;

  const _Redactor({
    required this.emisor,
    required this.controller,
    required this.onCambiarEmisor,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;

    return Material(
      color: colores.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(children: [
          Row(children: [
            const Text('Enviar como:'),
            const SizedBox(width: 8),
            Expanded(
              child: SegmentedButton<Dispositivo>(
                segments: [
                  for (final d in Dispositivo.values)
                    ButtonSegment(
                      value: d,
                      label: Text(d.letra),
                      icon: const Icon(Icons.smartphone),
                      tooltip: d.nombre,
                    ),
                ],
                selected: {emisor},
                onSelectionChanged: (s) => onCambiarEmisor(s.first),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLength: maxLongitudMensaje,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onEnviar(),
                decoration: InputDecoration(
                  hintText: 'Mensaje de ${emisor.nombre} para ${emisor.otro.nombre}',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Enviar',
              icon: const Icon(Icons.send),
              onPressed: onEnviar,
            ),
          ]),
        ]),
      ),
    );
  }
}
