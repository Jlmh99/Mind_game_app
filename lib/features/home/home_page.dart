import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import '../crucigrama/crucigrama_page.dart';
import '../mobileconnect/mobileconnect_page.dart';
import '../perfil/perfil_page.dart';
import '../sudoku/sudoku_page.dart';

/// Pantalla principal que se muestra cuando el usuario ya inició sesión.
/// Contiene: saludo, accesos a los juegos, perfil, MobileConnect y cerrar sesión.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  /// Abre una pantalla encima del inicio (con flecha para regresar).
  void _abrir(BuildContext context, Widget pantalla) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Solo leemos el correo del estado de autenticación (nunca el token).
    final correo = ref.watch(authControllerProvider).correo ?? '';
    final textos = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Mind Games')),
      body: SafeArea(
        // ListView permite hacer scroll en pantallas pequeñas.
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Saludo(correo: correo),
            const SizedBox(height: 24),

            // ---------- Juegos ----------
            Text('Juegos', style: textos.titleMedium),
            const SizedBox(height: 8),
            _TarjetaJuego(
              titulo: 'Sudoku',
              descripcion: 'Completa la cuadrícula con números del 1 al 9.',
              icono: Icons.grid_on,
              onTap: () => _abrir(context, const SudokuPage()),
            ),
            const SizedBox(height: 12),
            _TarjetaJuego(
              titulo: 'Crucigrama',
              descripcion: 'Resuelve las pistas y llena las palabras.',
              icono: Icons.abc,
              onTap: () => _abrir(context, const CrucigramaPage()),
            ),
            const SizedBox(height: 24),

            // ---------- Otras opciones ----------
            Text('Más opciones', style: textos.titleMedium),
            const SizedBox(height: 8),
            _Acceso(
              titulo: 'Mi perfil',
              icono: Icons.person_outline,
              onTap: () => _abrir(context, const PerfilPage()),
            ),
            _Acceso(
              titulo: 'MobileConnect',
              icono: Icons.devices_outlined,
              onTap: () => _abrir(context, const MobileConnectPage()),
            ),
            const SizedBox(height: 24),

            // ---------- Cerrar sesión ----------
            // Al cerrar sesión el estado cambia a noAutenticado y main.dart
            // muestra automáticamente la pantalla de login.
            OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).cerrarSesion(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta superior con el saludo y el correo del usuario.
class _Saludo extends StatelessWidget {
  final String correo;
  const _Saludo({required this.correo});

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Card(
      color: colores.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colores.primary,
              child: Icon(Icons.waving_hand, color: colores.onPrimary),
            ),
            const SizedBox(width: 16),
            // Expanded evita que un correo largo desborde la pantalla.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¡Hola!',
                      style: textos.headlineSmall
                          ?.copyWith(color: colores.onPrimaryContainer)),
                  const SizedBox(height: 4),
                  Text(
                    correo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textos.bodyLarge
                        ?.copyWith(color: colores.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta grande para entrar a un juego.
class _TarjetaJuego extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final VoidCallback onTap;

  const _TarjetaJuego({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    return Card.filled(
      // clipBehavior hace que el efecto al tocar respete las esquinas redondeadas.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icono, size: 48, color: colores.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: textos.titleLarge),
                    const SizedBox(height: 4),
                    Text(descripcion,
                        style: textos.bodyMedium
                            ?.copyWith(color: colores.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de acceso secundario (Mi perfil, MobileConnect).
class _Acceso extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final VoidCallback onTap;

  const _Acceso({required this.titulo, required this.icono, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icono),
        title: Text(titulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
