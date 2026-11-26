import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/nota_servidor_inactivo.dart';
import '../../data/incidencias_repository.dart';
import '../auth/auth_controller.dart';
import 'crear_incidencia_page.dart';
import 'detalle_incidencia_page.dart';
import 'incidencias_comun.dart';
import 'lista_incidencias_controller.dart';
import 'widgets/incidencia_widgets.dart';

/// Lista de incidencias. El backend ya filtra por rol:
/// USER ve las suyas, AGENTE las asignadas y ADMIN todas.
class IncidenciasPage extends ConsumerWidget {
  const IncidenciasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(listaIncidenciasProvider);
    final controller = ref.read(listaIncidenciasProvider.notifier);
    final rol = rolDesde(ref.watch(authControllerProvider.select((s) => s.rol)));
    final visibles = estado.visibles;

    return Scaffold(
      appBar: AppBar(title: const Text('Incidencias')),
      // Un AGENTE atiende las que le asignan; crear es para USER y ADMIN.
      floatingActionButton: rol == RolApp.agente
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Nueva'),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CrearIncidenciaPage())),
            ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(children: [
              Row(children: [
                Icon(Icons.badge_outlined,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(switch (rol) {
                    RolApp.user => 'Vista de ${textoRol(rol)}: tus incidencias',
                    RolApp.agente => 'Vista de ${textoRol(rol)}: incidencias asignadas a ti',
                    RolApp.admin => 'Vista de ${textoRol(rol)}: todas las incidencias',
                  }),
                ),
              ]),
              const SizedBox(height: 4),
              BarraSincronizacion(ultima: estado.ultimaActualizacion, rol: rol),
            ]),
          ),
          // Sin una carga correcta todavía, los chips no muestran números
          // (un "(0)" haría creer que no hay incidencias).
          _FiltroEstados(
              estado: estado,
              conConteo: estado.ultimaActualizacion != null,
              onCambiar: controller.cambiarFiltro),
          if (estado.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(estado.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (estado.error == mensajeErrorCarga)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: NotaServidorInactivo(alineacion: TextAlign.start),
            ),
          Expanded(
            // Pull-to-refresh disponible para todos (USER lo necesita;
            // ADMIN y AGENTE además se actualizan solos cada 5 s).
            child: RefreshIndicator(
              onRefresh: controller.cargar,
              child: estado.cargando && estado.incidencias.isEmpty
                  ? const _Centro(child: CircularProgressIndicator())
                  : visibles.isEmpty
                      ? _Centro(
                          child: Text(
                          // Si nunca cargó bien y hubo error, no se sabe si hay
                          // incidencias: se invita a reintentar (el error ya se
                          // muestra arriba).
                          estado.error != null && estado.ultimaActualizacion == null
                              ? 'Desliza hacia abajo para reintentar'
                              : estado.incidencias.isEmpty
                                  ? 'No hay incidencias todavía'
                                  : 'No hay incidencias con este estado',
                          textAlign: TextAlign.center,
                        ))
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                          itemCount: visibles.length,
                          itemBuilder: (_, i) => _TarjetaIncidencia(
                            incidencia: visibles[i],
                            mostrarPersonas: rol != RolApp.user,
                            onTap: () async {
                              await Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      DetalleIncidenciaPage(id: visibles[i].id)));
                              // Al volver (pudo editarse o borrarse) se refresca.
                              controller.cargar(silencioso: true);
                            },
                          ),
                        ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Fila de chips para filtrar por estado (con el número de cada uno
/// solo si [conConteo]: después de al menos una carga correcta).
class _FiltroEstados extends StatelessWidget {
  final ListaIncidenciasState estado;
  final bool conConteo;
  final ValueChanged<EstadoIncidencia?> onCambiar;
  const _FiltroEstados(
      {required this.estado, required this.conConteo, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    Widget chip(String texto, EstadoIncidencia? valor) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(conConteo ? '$texto (${estado.cuantas(valor)})' : texto),
            selected: estado.filtro == valor,
            onSelected: (_) => onCambiar(valor),
          ),
        );

    // Scroll horizontal: en pantallas angostas los chips no se desbordan.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        chip('Todos', null),
        for (final e in EstadoIncidencia.values) chip(textoEstado(e), e),
      ]),
    );
  }
}

class _TarjetaIncidencia extends StatelessWidget {
  final Incidencia incidencia;
  final bool mostrarPersonas; // AGENTE/ADMIN ven quién la creó y a quién está asignada
  final VoidCallback onTap;
  const _TarjetaIncidencia(
      {required this.incidencia, required this.mostrarPersonas, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(incidencia.titulo,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: textos.titleMedium),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              ChipEstado(incidencia.estado),
              ChipPrioridad(incidencia.prioridad),
            ]),
            if (mostrarPersonas) ...[
              const SizedBox(height: 6),
              Text(
                'De: ${incidencia.creadoPor?.username ?? '—'}'
                ' · Agente: ${incidencia.asignadoA?.username ?? 'sin asignar'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textos.bodySmall,
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Contenido centrado que igual permite el gesto de pull-to-refresh.
class _Centro extends StatelessWidget {
  final Widget child;
  const _Centro({required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: c.maxHeight,
            child: Center(
                child: Padding(padding: const EdgeInsets.all(24), child: child)),
          ),
        ),
      );
}
