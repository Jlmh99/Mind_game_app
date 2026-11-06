import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../data/local/app_database.dart';
import 'api_client.dart';

// Providers compartidos por toda la app. Están en core/ para que cualquier
// feature (auth, sudoku, perfil...) pueda usarlos sin depender de otra feature.

/// Base de datos local (Floor). Se abre en main() y se inyecta con
/// overrideWithValue; si alguien la usa sin inicializar, lanza un error claro.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider no inicializado'),
);

/// Cliente HTTP compartido. Lee el token de la sesión local cuando
/// una petición se marca como autenticada.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(databaseProvider).sesionDao),
);

/// Repositorio de autenticación (login, registro, 2FA y sesión local).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(databaseProvider), ref.watch(apiClientProvider)),
);
