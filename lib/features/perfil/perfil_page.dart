import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/formato.dart';
import '../../data/partidas_repository.dart';
import '../auth/auth_controller.dart';
import '../partidas/partidas_controller.dart';
import 'foto_perfil_controller.dart';
import 'widgets/avatar_foto.dart';

/// Pantalla "Mi perfil": datos del usuario y sus últimas partidas.
class PerfilPage extends ConsumerStatefulWidget {
  const PerfilPage({super.key});

  @override
  ConsumerState<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends ConsumerState<PerfilPage> {
  /// Cuántas partidas se muestran como "últimas".
  static const _maxPartidas = 20;

  @override
  void initState() {
    super.initState();
    // Se cargan al abrir la pantalla (microtask: no modificar providers en initState).
    Future.microtask(() {
      ref.read(partidasControllerProvider.notifier).cargar();
      ref.read(fotoPerfilControllerProvider.notifier).cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final partidas = ref.watch(partidasControllerProvider);
    final controller = ref.read(partidasControllerProvider.notifier);
    final foto = ref.watch(fotoPerfilControllerProvider);
    final fotoController = ref.read(fotoPerfilControllerProvider.notifier);
    final textos = Theme.of(context).textTheme;

    // Errores al tomar/subir la foto: se avisan con SnackBar (mensaje genérico).
    ref.listen(fotoPerfilControllerProvider, (anterior, nuevo) {
      if (nuevo.errorSubida != null && nuevo.errorSubida != anterior?.errorSubida) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(nuevo.errorSubida!),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: SafeArea(
        // Deslizar hacia abajo vuelve a pedir las partidas al servidor.
        child: RefreshIndicator(
          onRefresh: () => Future.wait([controller.cargar(), fotoController.cargar()]),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Encabezado(
                correo: auth.correo ?? '',
                rol: auth.rol,
                foto: foto,
                onTomarFoto: fotoController.tomarYSubir,
                onReintentarFoto: fotoController.cargar,
              ),
              const SizedBox(height: 24),
              Text('Últimas partidas', style: textos.titleMedium),
              const SizedBox(height: 8),
              ..._contenidoPartidas(partidas, controller),
            ],
          ),
        ),
      ),
    );
  }

  /// Lista, cargando, error o vacío, según el estado.
  List<Widget> _contenidoPartidas(
      PartidasState estado, PartidasController controller) {
    if (estado.cargando && estado.partidas.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (estado.error != null && estado.partidas.isEmpty) {
      return [
        _Aviso(
          icono: Icons.cloud_off,
          texto: estado.error!,
          accion: TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            onPressed: controller.cargar,
          ),
        ),
      ];
    }
    if (estado.partidas.isEmpty) {
      return const [
        _Aviso(
          icono: Icons.sports_esports_outlined,
          texto: 'Aún no tienes partidas. ¡Juega un Sudoku o un Crucigrama!',
        ),
      ];
    }
    return [
      for (final p in estado.partidas.take(_maxPartidas)) _TarjetaPartida(p),
    ];
  }
}

/// Foto de perfil (con botón de cámara), correo y rol del usuario.
class _Encabezado extends StatelessWidget {
  final String correo;
  final String? rol;
  final FotoPerfilState foto;
  final VoidCallback onTomarFoto;
  final VoidCallback onReintentarFoto;

  const _Encabezado({
    required this.correo,
    this.rol,
    required this.foto,
    required this.onTomarFoto,
    required this.onReintentarFoto,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Card(
      color: colores.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          AvatarFoto(estado: foto, onTomarFoto: onTomarFoto),
          if (foto.subiendo) ...[
            const SizedBox(height: 8),
            Text('Actualizando foto...',
                style: textos.bodySmall
                    ?.copyWith(color: colores.onPrimaryContainer)),
          ],
          // Si falló la descarga de la foto, mensaje genérico y opción de reintentar.
          if (foto.errorCarga != null)
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(foto.errorCarga!),
              onPressed: onReintentarFoto,
            ),
          const SizedBox(height: 12),
          Text(correo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  textos.titleMedium?.copyWith(color: colores.onPrimaryContainer)),
          if (rol != null) ...[
            const SizedBox(height: 4),
            Text('Rol: $rol',
                style: textos.bodyMedium
                    ?.copyWith(color: colores.onPrimaryContainer)),
          ],
        ]),
      ),
    );
  }
}

/// Una partida: juego, puntuación, tiempo y fecha.
class _TarjetaPartida extends StatelessWidget {
  final Partida partida;
  const _TarjetaPartida(this.partida);

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final esSudoku = partida.juego == juegoSudoku;

    return Card.outlined(
      child: ListTile(
        leading: Icon(esSudoku ? Icons.grid_on : Icons.abc,
            color: colores.primary, size: 32),
        title: Text(esSudoku ? 'Sudoku' : 'Crucigrama'),
        subtitle: Text(
          'Tiempo ${formatoDuracion(partida.tiempoSegundos)} · '
          '${formatoFecha(partida.fecha)}',
        ),
        // FittedBox: con letra grande la puntuación se reduce en vez de
        // desbordar el alto fijo del ListTile.
        trailing: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${partida.puntuacion}',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: colores.primary)),
              const Text('puntos', style: TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mensaje centrado con icono (vacío o error) y una acción opcional.
class _Aviso extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Widget? accion;
  const _Aviso({required this.icono, required this.texto, this.accion});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        Icon(icono, size: 48, color: colores.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(texto,
            textAlign: TextAlign.center,
            style: TextStyle(color: colores.onSurfaceVariant)),
        if (accion != null) ...[const SizedBox(height: 8), accion!],
      ]),
    );
  }
}
