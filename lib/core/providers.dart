import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/local/app_database.dart';
import '../data/local/partida_en_curso_dao.dart';
import '../data/local/puntuacion_pendiente_dao.dart';
import 'api_client.dart';

// Providers compartidos por toda la app. Están en core/ para que cualquier
// feature (auth, sudoku, perfil...) pueda usarlos sin depender de otra feature.

/// Base de datos local (Floor). Se abre en main() y se inyecta con
/// overrideWithValue; si alguien la usa sin inicializar, lanza un error claro.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider no inicializado'),
);

/// DAO de partidas en curso (Sudoku/Crucigrama sin terminar).
/// Por defecto es null = sin persistencia: los juegos funcionan igual que
/// antes (así lo usan las pruebas que montan los juegos sin base de datos).
/// main() lo sobrescribe con el DAO real de Floor.
final partidaEnCursoDaoProvider = Provider<PartidaEnCursoDao?>((ref) => null);

/// DAO de la cola offline de puntuaciones. Igual que el anterior: null por
/// defecto (sin cola; un fallo al guardar se reporta como antes) y main() lo
/// sobrescribe con el DAO real.
final puntuacionPendienteDaoProvider = Provider<PuntuacionPendienteDao?>((ref) => null);

/// true cada vez que el teléfono queda con alguna red (WiFi, datos...),
/// false cuando se queda sin red. Solo se usa si hay cola (DAO real), así las
/// pruebas sin base de datos nunca tocan el plugin. En pruebas se sobrescribe
/// con un Stream controlado.
final conectividadProvider = Provider<Stream<bool>>((ref) => Connectivity()
    .onConnectivityChanged
    .map((r) => r.any((tipo) => tipo != ConnectivityResult.none)));

/// Cliente HTTP compartido. Lee el token de la sesión local cuando
/// una petición se marca como autenticada.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(databaseProvider).sesionDao),
);

/// Repositorio de autenticación (login, registro, 2FA y sesión local).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(databaseProvider), ref.watch(apiClientProvider)),
);
