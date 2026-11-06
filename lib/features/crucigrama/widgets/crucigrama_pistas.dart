import 'package:flutter/material.dart';
import '../crucigrama_model.dart';

/// Lista de pistas separadas en Horizontales y Verticales.
/// Al tocar una pista se avisa con [onTocarPista] para seleccionar su palabra.
class CrucigramaPistas extends StatelessWidget {
  final CrucigramaState estado;
  final void Function(PalabraCrucigrama palabra) onTocarPista;

  const CrucigramaPistas({
    super.key,
    required this.estado,
    required this.onTocarPista,
  });

  @override
  Widget build(BuildContext context) {
    List<PalabraCrucigrama> de(Orientacion o) =>
        palabrasCrucigrama.where((p) => p.orientacion == o).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _seccion(context, 'Horizontales', Icons.arrow_forward,
            de(Orientacion.horizontal)),
        const SizedBox(height: 12),
        _seccion(context, 'Verticales', Icons.arrow_downward,
            de(Orientacion.vertical)),
      ],
    );
  }

  Widget _seccion(BuildContext context, String titulo, IconData icono,
      List<PalabraCrucigrama> palabras) {
    final textos = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(children: [
              Icon(icono, size: 20, color: colores.primary),
              const SizedBox(width: 8),
              Text(titulo,
                  style: textos.titleMedium?.copyWith(color: colores.primary)),
            ]),
          ),
          for (final p in palabras)
            ListTile(
              selected: identical(estado.palabraSeleccionada, p),
              selectedTileColor: colores.secondaryContainer,
              title: Text(p.pista),
              subtitle: Text('${p.palabra.length} letras'),
              // Palomita verde cuando la palabra ya está correcta.
              trailing: estado.esCorrecta(p)
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () => onTocarPista(p),
            ),
        ],
      ),
    );
  }
}
