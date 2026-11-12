import 'package:flutter/material.dart';
import '../../../core/formato.dart';
import '../../../data/incidencias_repository.dart';
import '../incidencias_comun.dart';

/// Etiqueta de color con el estado.
class ChipEstado extends StatelessWidget {
  final EstadoIncidencia estado;
  const ChipEstado(this.estado, {super.key});

  @override
  Widget build(BuildContext context) => _Etiqueta(
        texto: textoEstado(estado),
        color: colorEstado(Theme.of(context).colorScheme, estado),
        icono: Icons.flag_outlined,
      );
}

/// Etiqueta de color con la prioridad.
class ChipPrioridad extends StatelessWidget {
  final PrioridadIncidencia prioridad;
  const ChipPrioridad(this.prioridad, {super.key});

  @override
  Widget build(BuildContext context) => _Etiqueta(
        texto: textoPrioridad(prioridad),
        color: colorPrioridad(Theme.of(context).colorScheme, prioridad),
        icono: Icons.priority_high,
      );
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  final IconData icono;
  const _Etiqueta({required this.texto, required this.color, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: Text(texto,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium),
        ),
      ]),
    );
  }
}

/// Línea con la hora de la última actualización y cómo se sincroniza.
class BarraSincronizacion extends StatelessWidget {
  final DateTime? ultima;
  final RolApp rol;
  final int segundos; // cada cuánto se actualiza solo (lista/detalle 5, chat 3)
  const BarraSincronizacion(
      {super.key, required this.ultima, required this.rol, this.segundos = 5});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final automatico = usaSincronizacionAutomatica(rol);
    final hora = ultima == null ? '—' : formatoHora(ultima!);
    return Row(children: [
      Icon(automatico ? Icons.sync : Icons.swipe_down_alt,
          size: 16, color: colores.onSurfaceVariant),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          automatico
              ? 'Actualizado a las $hora · automático cada $segundos s'
              : 'Actualizado a las $hora · desliza hacia abajo para actualizar',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colores.onSurfaceVariant),
        ),
      ),
    ]);
  }
}

/// Aviso de conflicto de versión (409) con botón para recargar.
class AvisoConflicto extends StatelessWidget {
  final VoidCallback onRecargar;
  const AvisoConflicto({super.key, required this.onRecargar});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Card.filled(
      color: colores.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.sync_problem, color: colores.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(mensajeConflicto,
                  style: TextStyle(color: colores.onErrorContainer)),
            ),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Recargar'),
              onPressed: onRecargar,
            ),
          ),
        ]),
      ),
    );
  }
}
