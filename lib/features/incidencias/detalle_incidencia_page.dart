import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/formato.dart';
import '../../data/incidencias_repository.dart';
import '../auth/auth_controller.dart';
import 'chat/chat_incidencia_page.dart';
import 'detalle_incidencia_controller.dart';
import 'incidencias_comun.dart';
import 'widgets/incidencia_widgets.dart';

/// Detalle de una incidencia con las acciones que permite el rol:
///  - Creador: editar título/descripción y eliminar.
///  - Agente asignado: cambiar el estado.
///  - ADMIN: estado, prioridad, asignar agente (y también editar/eliminar).
/// Los botones que el rol no puede usar se ocultan, pero el backend vuelve a
/// validar: si responde 403 se muestra "No tienes permiso para esta acción".
class DetalleIncidenciaPage extends ConsumerWidget {
  final int id;
  const DetalleIncidenciaPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(detalleIncidenciaProvider(id));
    final controller = ref.read(detalleIncidenciaProvider(id).notifier);
    final auth = ref.watch(authControllerProvider);
    final rol = rolDesde(auth.rol);
    final inc = estado.incidencia;

    // El ScaffoldMessenger es el de toda la app: sirve aunque esta pantalla
    // ya se haya cerrado (por ejemplo, después de eliminar).
    final messenger = ScaffoldMessenger.of(context);

    /// Muestra el mensaje genérico del resultado (si hay que mostrar algo).
    void avisar(ResultadoAccion r, {String? exito}) {
      final texto = r == ResultadoAccion.ok ? exito : mensajeDe(r);
      if (texto == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(texto)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(inc == null ? 'Incidencia' : 'Incidencia #${inc.id}'),
        bottom: estado.procesando
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.cargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              BarraSincronizacion(ultima: estado.ultimaActualizacion, rol: rol),
              const SizedBox(height: 8),
              if (estado.conflicto) AvisoConflicto(onRecargar: controller.recargar),
              if (estado.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(estado.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (inc == null && estado.cargando)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (inc != null) ...[
                _Informacion(inc),
                const SizedBox(height: 12),
                // Chat de la incidencia (canal con el usuario y, para ADMIN/AGENTE, interno).
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Abrir chat'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatIncidenciaPage(incidencia: inc))),
                ),
                const SizedBox(height: 16),
                _Acciones(
                  incidencia: inc,
                  estado: estado,
                  correo: auth.correo,
                  rol: rol,
                  onEstado: (e) async => avisar(await controller.cambiarEstado(e),
                      exito: 'Estado actualizado'),
                  onPrioridad: (p) async => avisar(await controller.cambiarPrioridad(p),
                      exito: 'Prioridad actualizada'),
                  onAsignar: (agenteId) async => avisar(await controller.asignar(agenteId),
                      exito: 'Agente asignado'),
                  onEditar: () async {
                    final cambios = await showDialog<(String, String)>(
                      context: context,
                      builder: (_) => _DialogoEditar(incidencia: inc),
                    );
                    if (cambios == null) return;
                    // Se envía la versión que había al ABRIR el formulario.
                    avisar(
                        await controller.editarTexto(
                            titulo: cambios.$1, descripcion: cambios.$2, version: inc.version),
                        exito: 'Cambios guardados');
                  },
                  onEliminar: () async {
                    if (!await _confirmarEliminar(context)) return;
                    final r = await controller.eliminar();
                    if (r == ResultadoAccion.ok && context.mounted) {
                      Navigator.of(context).pop();
                    }
                    avisar(r, exito: 'Incidencia eliminada');
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmarEliminar(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.delete_outline),
          title: const Text('¿Eliminar incidencia?'),
          content: const Text('También se borrarán sus mensajes. No se puede deshacer.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
          ],
        ),
      ) ??
      false;
}

/// Título, etiquetas, descripción y datos del registro.
class _Informacion extends StatelessWidget {
  final Incidencia inc;
  const _Informacion(this.inc);

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    Widget dato(IconData icono, String texto) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Icon(icono, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(texto, style: textos.bodyMedium)),
          ]),
        );

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(inc.titulo, style: textos.titleLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4, children: [
            ChipEstado(inc.estado),
            ChipPrioridad(inc.prioridad),
          ]),
          const SizedBox(height: 12),
          Text(inc.descripcion, style: textos.bodyLarge),
          const Divider(height: 24),
          dato(Icons.person_outline, 'Creada por: ${inc.creadoPor?.username ?? '—'}'),
          dato(Icons.support_agent, 'Agente: ${inc.asignadoA?.username ?? 'sin asignar'}'),
          dato(Icons.event, 'Creada: ${formatoFecha(inc.fechaCreacion)}'),
          dato(Icons.update, 'Actualizada: ${formatoFecha(inc.fechaActualizacion)}'),
          dato(Icons.tag, 'Versión: ${inc.version}'),
        ]),
      ),
    );
  }
}

/// Controles según el rol. Lo que el rol no puede usar no se muestra.
class _Acciones extends StatelessWidget {
  final Incidencia incidencia;
  final DetalleIncidenciaState estado;
  final String? correo;
  final RolApp rol;
  final ValueChanged<EstadoIncidencia> onEstado;
  final ValueChanged<PrioridadIncidencia> onPrioridad;
  final ValueChanged<int> onAsignar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _Acciones({
    required this.incidencia,
    required this.estado,
    required this.correo,
    required this.rol,
    required this.onEstado,
    required this.onPrioridad,
    required this.onAsignar,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final inc = incidencia;
    final ocupado = estado.procesando;
    final controles = <Widget>[
      if (puedeCambiarEstado(inc, correo, rol))
        DropdownButtonFormField<EstadoIncidencia>(
          // key con la versión: al llegar datos nuevos el valor se actualiza.
          key: ValueKey('estado-${inc.id}-${inc.version}'),
          initialValue: inc.estado,
          decoration:
              const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
          items: [
            for (final e in EstadoIncidencia.values)
              DropdownMenuItem(value: e, child: Text(textoEstado(e))),
          ],
          onChanged: ocupado
              ? null
              : (e) {
                  if (e != null && e != inc.estado) onEstado(e);
                },
        ),
      if (puedeCambiarPrioridad(rol))
        DropdownButtonFormField<PrioridadIncidencia>(
          key: ValueKey('prioridad-${inc.id}-${inc.version}'),
          initialValue: inc.prioridad,
          decoration:
              const InputDecoration(labelText: 'Prioridad', border: OutlineInputBorder()),
          items: [
            for (final p in PrioridadIncidencia.values)
              DropdownMenuItem(value: p, child: Text(textoPrioridad(p))),
          ],
          onChanged: ocupado
              ? null
              : (p) {
                  if (p != null && p != inc.prioridad) onPrioridad(p);
                },
        ),
      if (puedeAsignar(rol))
        _SelectorAgente(
          key: ValueKey('agente-${inc.id}-${inc.version}'),
          agentes: estado.agentes,
          actual: inc.asignadoA?.id,
          habilitado: !ocupado,
          onAsignar: onAsignar,
        ),
      if (puedeEditarTexto(inc, correo, rol))
        OutlinedButton.icon(
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar título y descripción'),
          onPressed: ocupado ? null : onEditar,
        ),
      if (puedeEliminar(inc, correo, rol))
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Eliminar incidencia'),
          onPressed: ocupado ? null : onEliminar,
        ),
    ];

    if (controles.isEmpty) {
      return Text('Solo puedes consultar esta incidencia.',
          style: Theme.of(context).textTheme.bodyMedium);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final c in controles) ...[c, const SizedBox(height: 12)],
    ]);
  }
}

/// Lista de agentes (de /api/incidencias/agentes) y botón para asignar.
class _SelectorAgente extends StatefulWidget {
  final List<UsuarioResumen> agentes;
  final int? actual;
  final bool habilitado;
  final ValueChanged<int> onAsignar;
  const _SelectorAgente(
      {super.key,
      required this.agentes,
      required this.actual,
      required this.habilitado,
      required this.onAsignar});

  @override
  State<_SelectorAgente> createState() => _SelectorAgenteState();
}

class _SelectorAgenteState extends State<_SelectorAgente> {
  int? _elegido;

  @override
  void initState() {
    super.initState();
    _elegido = widget.agentes.any((a) => a.id == widget.actual) ? widget.actual : null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.agentes.isEmpty) {
      return const Text('No hay agentes disponibles para asignar.');
    }
    return Row(children: [
      Expanded(
        child: DropdownButtonFormField<int>(
          initialValue: _elegido,
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Asignar a agente', border: OutlineInputBorder()),
          items: [
            for (final a in widget.agentes)
              DropdownMenuItem(
                  value: a.id, child: Text(a.username, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: widget.habilitado ? (v) => setState(() => _elegido = v) : null,
        ),
      ),
      const SizedBox(width: 8),
      FilledButton(
        onPressed: widget.habilitado && _elegido != null && _elegido != widget.actual
            ? () => widget.onAsignar(_elegido!)
            : null,
        child: const Text('Asignar'),
      ),
    ]);
  }
}

/// Diálogo para editar título y descripción (mismas validaciones que al crear).
/// Devuelve (título, descripción) o null si se canceló.
class _DialogoEditar extends StatefulWidget {
  final Incidencia incidencia;
  const _DialogoEditar({required this.incidencia});

  @override
  State<_DialogoEditar> createState() => _DialogoEditarState();
}

class _DialogoEditarState extends State<_DialogoEditar> {
  final _form = GlobalKey<FormState>();
  late final _titulo = TextEditingController(text: widget.incidencia.titulo);
  late final _descripcion = TextEditingController(text: widget.incidencia.descripcion);

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar incidencia'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _titulo,
              maxLength: maxTituloIncidencia,
              validator: validarTituloIncidencia,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            TextFormField(
              controller: _descripcion,
              maxLength: maxDescripcionIncidencia,
              minLines: 2,
              maxLines: 5,
              validator: validarDescripcionIncidencia,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(context, (_titulo.text.trim(), _descripcion.text.trim()));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
