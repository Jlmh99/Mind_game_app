import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/orientacion.dart';
import 'core/providers.dart';
import 'data/local/app_database.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_pages.dart';
import 'features/home/home_page.dart';
import 'features/partidas/cola_puntuaciones.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await bloquearVertical(); // la app solo funciona en vertical
  final db = await $FloorAppDatabase
      .databaseBuilder('mindgames.db')
      .addMigrations(migracionesApp) // v1 -> v2 -> v3
      .build();
  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      partidaEnCursoDaoProvider.overrideWithValue(db.partidaEnCursoDao),
      puntuacionPendienteDaoProvider.overrideWithValue(db.puntuacionPendienteDao),
    ],
    child: const MindGamesApp(),
  ));
}

// Llave del Navigator principal: permite cerrar pantallas abiertas
// (Sudoku, Perfil...) sin tener un BuildContext a la mano.
final _navigatorKey = GlobalKey<NavigatorState>();

// Llave del ScaffoldMessenger principal: permite mostrar SnackBars
// (como "Acceso exitoso") aunque la pantalla de login ya no exista.
final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class MindGamesApp extends ConsumerWidget {
  const MindGamesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    // Cola offline de puntuaciones (Práctica 14): se mantiene viva toda la
    // app para reenviar al volver la red o al iniciar con sesión. listen (y no
    // watch) para no reconstruir la app cada vez que cambia el contador.
    ref.listen(colaPuntuacionesProvider, (_, _) {});

    // Si la sesión se cierra (o expira) mientras hay pantallas encima del
    // inicio, las quitamos para que el login quede visible.
    ref.listen(authControllerProvider, (anterior, nuevo) {
      if (anterior?.status == AuthStatus.autenticado &&
          nuevo.status == AuthStatus.noAutenticado) {
        _navigatorKey.currentState?.popUntil((ruta) => ruta.isFirst);
      }

      // Login correcto (directo o tras el código 2FA): mensaje de acceso exitoso.
      // No se muestra al restaurar una sesión guardada (estado "cargando").
      final veniaDelLogin = anterior?.status == AuthStatus.noAutenticado ||
          anterior?.status == AuthStatus.esperandoCodigo;
      if (veniaDelLogin && nuevo.status == AuthStatus.autenticado) {
        _messengerKey.currentState?.showSnackBar(const SnackBar(
          content: Text('Acceso exitoso. ¡Bienvenido!'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    });

    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      title: 'Mind Games',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: switch (auth.status) {
        AuthStatus.cargando =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
        AuthStatus.noAutenticado => const LoginPage(),
        AuthStatus.esperandoCodigo => const VerifyCodePage(),
        AuthStatus.autenticado => const HomePage(),
      },
    );
  }
}
