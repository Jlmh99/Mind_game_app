import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/widgets/nota_servidor_inactivo.dart';
import '../../../data/incidencias_repository.dart';
import '../../../data/mensajes_repository.dart';
import '../../auth/auth_controller.dart';
import '../../perfil/camara.dart';
import '../incidencias_comun.dart';
import '../widgets/incidencia_widgets.dart';
import 'chat_comun.dart';
import 'chat_controller.dart';
import 'selector_archivos.dart';
import 'widgets/burbuja_chat.dart';
import 'widgets/participantes_chat.dart';

/// Chat de una incidencia (extiende la idea de MobileConnect con mensajes
/// reales del backend). Pestañas:
///  - "Con el usuario" (canal PUBLICO): para todos los participantes.
///  - "Interno" (canal INTERNO): solo aparece para ADMIN y AGENTE.
class ChatIncidenciaPage extends ConsumerWidget {
  final Incidencia incidencia;
  const ChatIncidenciaPage({super.key, required this.incidencia});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = rolDesde(ref.watch(authControllerProvider.select((s) => s.rol)));
    final titulo = Text('Chat · #${incidencia.id}', overflow: TextOverflow.ellipsis);

    // USER: solo el canal público, sin pestañas.
    if (!puedeVerInterno(rol)) {
      return Scaffold(
        appBar: AppBar(title: titulo),
        body: _VistaCanal(incidencia: incidencia, canal: CanalChat.publico),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: titulo,
          bottom: TabBar(tabs: [
            Tab(icon: const Icon(Icons.forum_outlined), text: textoCanal(CanalChat.publico)),
            Tab(icon: const Icon(Icons.lock_outline), text: textoCanal(CanalChat.interno)),
          ]),
        ),
        body: TabBarView(children: [
          _VistaCanal(incidencia: incidencia, canal: CanalChat.publico),
          _VistaCanal(incidencia: incidencia, canal: CanalChat.interno),
        ]),
      ),
    );
  }
}

/// Un canal: participantes, conversación y redactor.
class _VistaCanal extends ConsumerStatefulWidget {
  final Incidencia incidencia;
  final CanalChat canal;
  const _VistaCanal({required this.incidencia, required this.canal});

  @override
  ConsumerState<_VistaCanal> createState() => _VistaCanalState();
}

enum _Origen { camara, galeria, pdf }

class _VistaCanalState extends ConsumerState<_VistaCanal> {
  final _texto = TextEditingController();
  AdjuntoMensaje? _adjunto; // adjunto listo para enviar (ya validado)

  ClaveChat get _clave => (widget.incidencia.id, widget.canal);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _enviar() async {
    // No se permiten mensajes vacíos, de solo espacios ni de más de 1000.
    final error = validarTextoMensaje(_texto.text);
    if (error != null) {
      _aviso(error);
      return;
    }
    final r = await ref.read(chatProvider(_clave).notifier).enviar(_texto.text, adjunto: _adjunto);
    if (!mounted) return;
    if (r == ResultadoAccion.ok) {
      _texto.clear();
      setState(() => _adjunto = null);
      _aviso('Mensaje enviado');
    } else if (mensajeDe(r) case final mensaje?) {
      _aviso(mensaje);
    }
  }

  Future<void> _adjuntar() async {
    final origen = await showModalBottomSheet<_Origen>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(c, _Origen.camara),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Imagen de la galería'),
            onTap: () => Navigator.pop(c, _Origen.galeria),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Documento PDF'),
            subtitle: const Text('Máximo 2 MB'),
            onTap: () => Navigator.pop(c, _Origen.pdf),
          ),
        ]),
      ),
    );
    if (origen == null) return;

    final selector = ref.read(selectorArchivosProvider);
    try {
      final archivo = switch (origen) {
        _Origen.camara => await selector.imagen(ImageSource.camera),
        _Origen.galeria => await selector.imagen(ImageSource.gallery),
        _Origen.pdf => await selector.pdf(),
      };
      if (archivo == null || !mounted) return; // canceló
      // Valida tamaño (2 MB) y tipo real (JPG, PNG o PDF).
      setState(() => _adjunto = prepararAdjunto(archivo.nombre, archivo.bytes));
    } on AdjuntoInvalidoException catch (e) {
      _aviso(e.mensaje);
    } on CamaraDenegadaException {
      _aviso('Sin permiso no podemos usar la cámara o las fotos. Puedes activarlo en Ajustes.');
    } catch (_) {
      _aviso('No se pudo adjuntar el archivo');
    }
  }

  Future<void> _confirmarLimpiar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_outlined),
        title: const Text('¿Limpiar historial?'),
        content: const Text(
            'Se ocultarán los mensajes de esta pantalla. No se borran del servidor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Limpiar')),
        ],
      ),
    );
    if (ok == true && mounted) {
      ref.read(chatProvider(_clave).notifier).limpiarHistorial();
      _aviso('Historial limpiado en este dispositivo');
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(chatProvider(_clave));
    final controller = ref.read(chatProvider(_clave).notifier);
    final auth = ref.watch(authControllerProvider);
    final rol = rolDesde(auth.rol);
    final miCorreo = (auth.correo ?? '').trim().toLowerCase();
    final visibles = estado.visibles;

    // SnackBar cuando llega un mensaje nuevo de otro participante.
    ref.listen(chatProvider(_clave), (anterior, nuevo) {
      if (nuevo.avisosNuevos > (anterior?.avisosNuevos ?? 0) && nuevo.textoAviso != null) {
        _aviso(nuevo.textoAviso!);
      }
    });

    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: ParticipantesChat(
                participantes: participantesDe(
                    widget.incidencia, widget.canal, visibles, auth.correo),
              ),
            ),
            IconButton(
              tooltip: 'Limpiar historial',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: visibles.isEmpty ? null : _confirmarLimpiar,
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: BarraSincronizacion(
              ultima: estado.ultimaActualizacion, rol: rol, segundos: intervaloChat.inSeconds),
        ),
        if (estado.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(estado.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (estado.error == mensajeErrorCargaMensajes)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: NotaServidorInactivo(alineacion: TextAlign.start),
          ),
        const Divider(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.cargar,
            child: estado.cargando && estado.mensajes.isEmpty
                ? const _Lleno(child: CircularProgressIndicator())
                : visibles.isEmpty
                    ? const _Lleno(
                        child: Text('Aún no hay mensajes en este canal.',
                            textAlign: TextAlign.center))
                    : ListView.builder(
                        // reverse: el mensaje más reciente queda abajo y visible.
                        reverse: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: visibles.length,
                        itemBuilder: (_, i) {
                          final m = visibles[visibles.length - 1 - i];
                          final esMio =
                              (m.emisor?.email ?? '').trim().toLowerCase() == miCorreo;
                          return BurbujaChat(mensaje: m, esMio: esMio);
                        },
                      ),
          ),
        ),
        _Redactor(
          controller: _texto,
          adjunto: _adjunto,
          enviando: estado.enviando,
          canal: widget.canal,
          onAdjuntar: _adjuntar,
          onQuitarAdjunto: () => setState(() => _adjunto = null),
          onEnviar: _enviar,
        ),
      ]),
    );
  }
}

/// Parte inferior: vista previa del adjunto, botón adjuntar, texto y enviar.
class _Redactor extends StatelessWidget {
  final TextEditingController controller;
  final AdjuntoMensaje? adjunto;
  final bool enviando;
  final CanalChat canal;
  final VoidCallback onAdjuntar;
  final VoidCallback onQuitarAdjunto;
  final VoidCallback onEnviar;

  const _Redactor({
    required this.controller,
    required this.adjunto,
    required this.enviando,
    required this.canal,
    required this.onAdjuntar,
    required this.onQuitarAdjunto,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Material(
      color: colores.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (adjunto != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                // Vista previa: miniatura de la imagen o ícono con el nombre del PDF.
                Expanded(
                  child: adjunto!.esImagen
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(adjunto!.bytes!,
                                height: 72, cacheHeight: 144, fit: BoxFit.cover),
                          ),
                        )
                      : ArchivoPdf(nombre: adjunto!.nombre, bytes: adjunto!.tamano),
                ),
                IconButton(
                  tooltip: 'Quitar adjunto',
                  icon: const Icon(Icons.close),
                  onPressed: enviando ? null : onQuitarAdjunto,
                ),
              ]),
            ),
          Row(children: [
            IconButton(
              tooltip: 'Adjuntar imagen o PDF',
              icon: const Icon(Icons.attach_file),
              onPressed: enviando ? null : onAdjuntar,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !enviando,
                maxLength: maxTextoMensaje, // máximo 1000 caracteres
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onEnviar(),
                decoration: InputDecoration(
                  hintText: canal == CanalChat.interno
                      ? 'Mensaje interno (agente y admin)'
                      : 'Escribe un mensaje',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: 'Enviar',
              icon: enviando
                  ? const SizedBox.square(
                      dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              onPressed: enviando ? null : onEnviar,
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Contenido centrado que igual permite el gesto de pull-to-refresh.
class _Lleno extends StatelessWidget {
  final Widget child;
  const _Lleno({required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: c.maxHeight,
            child: Center(child: Padding(padding: const EdgeInsets.all(24), child: child)),
          ),
        ),
      );
}
