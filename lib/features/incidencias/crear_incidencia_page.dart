import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/incidencias_repository.dart';
import 'incidencias_comun.dart';
import 'lista_incidencias_controller.dart';

/// Formulario para crear una incidencia: título, descripción y prioridad.
class CrearIncidenciaPage extends ConsumerStatefulWidget {
  const CrearIncidenciaPage({super.key});

  @override
  ConsumerState<CrearIncidenciaPage> createState() => _CrearIncidenciaPageState();
}

class _CrearIncidenciaPageState extends ConsumerState<CrearIncidenciaPage> {
  final _form = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  PrioridadIncidencia _prioridad = PrioridadIncidencia.media;
  bool _enviando = false;

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    // No se envía nada si el formulario no es válido.
    if (!_form.currentState!.validate()) return;
    setState(() => _enviando = true);

    final r = await ref.read(listaIncidenciasProvider.notifier).crear(
          titulo: _titulo.text.trim(),
          descripcion: _descripcion.text.trim(),
          prioridad: _prioridad,
        );
    if (!mounted) return;
    setState(() => _enviando = false);

    final messenger = ScaffoldMessenger.of(context);
    if (r == ResultadoAccion.ok) {
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Incidencia creada')));
    } else if (mensajeDe(r) case final mensaje?) {
      messenger.showSnackBar(SnackBar(content: Text(mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva incidencia')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(
                controller: _titulo,
                enabled: !_enviando,
                maxLength: maxTituloIncidencia, // límite de 80
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                validator: validarTituloIncidencia, // obligatorio, sin solo espacios
                decoration: const InputDecoration(
                    labelText: 'Título', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descripcion,
                enabled: !_enviando,
                maxLength: maxDescripcionIncidencia, // límite de 500
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                validator: validarDescripcionIncidencia,
                decoration: const InputDecoration(
                    labelText: 'Descripción',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PrioridadIncidencia>(
                initialValue: _prioridad,
                decoration: const InputDecoration(
                    labelText: 'Prioridad', border: OutlineInputBorder()),
                items: [
                  for (final p in PrioridadIncidencia.values)
                    DropdownMenuItem(value: p, child: Text(textoPrioridad(p))),
                ],
                onChanged: _enviando ? null : (p) => setState(() => _prioridad = p!),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: _enviando
                    ? const SizedBox.square(
                        dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text('Crear incidencia'),
                onPressed: _enviando ? null : _crear,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
