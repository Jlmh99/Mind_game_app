import 'package:flutter/material.dart';
import '../chat_comun.dart';

/// Participantes del canal con el número de mensajes que ha enviado cada uno
/// (en la vista actual: al limpiar el historial vuelven a 0).
class ParticipantesChat extends StatelessWidget {
  final List<Participante> participantes;
  const ParticipantesChat({super.key, required this.participantes});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final colores = Theme.of(context).colorScheme;

    IconData icono(String papel) => switch (papel) {
          'Creador' => Icons.person_outline,
          'Agente' => Icons.support_agent,
          _ => Icons.admin_panel_settings_outlined,
        };

    // Una sola fila con scroll horizontal: ocupa siempre una línea, así la
    // conversación cabe aunque el teclado esté abierto.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final p in participantes)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: p.soyYo ? colores.primaryContainer : colores.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icono(p.papel), size: 16),
              const SizedBox(width: 6),
              Text(
                '${p.soyYo ? 'Tú' : p.nombre} (${p.papel}) · '
                '${p.enviados} ${p.enviados == 1 ? 'enviado' : 'enviados'}',
                style: textos.labelMedium,
              ),
            ]),
          ),
      ]),
    );
  }
}
