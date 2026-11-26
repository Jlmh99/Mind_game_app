import 'package:flutter/material.dart';

/// Explicación que acompaña a un error de carga (Práctica 14).
/// El backend está en el plan gratuito de Render: si estuvo inactivo se
/// "duerme" y la primera petición puede tardar hasta un minuto (medido: 36 s),
/// más que el timeout de 30 s de la app. Así el usuario sabe que puede
/// reintentar en un momento en lugar de pensar que la app no funciona.
const notaServidorInactivo =
    'Si el servidor estuvo inactivo, puede tardar hasta un minuto en responder. '
    'Vuelve a intentarlo en un momento.';

class NotaServidorInactivo extends StatelessWidget {
  const NotaServidorInactivo({super.key, this.alineacion = TextAlign.center});

  final TextAlign alineacion;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        notaServidorInactivo,
        textAlign: alineacion,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colores.onSurfaceVariant),
      ),
    );
  }
}
