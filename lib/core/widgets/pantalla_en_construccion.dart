import 'package:flutter/material.dart';

/// Pantalla genérica para secciones que todavía no están implementadas.
/// La usan Sudoku, Crucigrama, Mi perfil y MobileConnect mientras se desarrollan,
/// así evitamos repetir el mismo diseño en cada feature.
class PantallaEnConstruccion extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final String descripcion;

  const PantallaEnConstruccion({
    super.key,
    required this.titulo,
    required this.icono,
    this.descripcion = 'Esta sección estará disponible pronto.',
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      // El AppBar incluye automáticamente la flecha para regresar al inicio.
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 96, color: colores.primary),
              const SizedBox(height: 24),
              Text(titulo, style: textos.headlineSmall),
              const SizedBox(height: 8),
              Text(
                descripcion,
                textAlign: TextAlign.center,
                style: textos.bodyLarge?.copyWith(color: colores.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
