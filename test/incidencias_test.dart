import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/core/errores_api.dart';
import 'package:mindgames_app/core/sesion_expirada_exception.dart';
import 'package:mindgames_app/data/incidencias_repository.dart';
import 'package:mindgames_app/data/local/sesion.dart';
import 'package:mindgames_app/data/local/sesion_dao.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/features/incidencias/crear_incidencia_page.dart';
import 'package:mindgames_app/features/incidencias/detalle_incidencia_controller.dart';
import 'package:mindgames_app/features/incidencias/detalle_incidencia_page.dart';
import 'package:mindgames_app/features/incidencias/incidencias_comun.dart';
import 'package:mindgames_app/features/incidencias/incidencias_page.dart';
import 'package:mindgames_app/features/incidencias/lista_incidencias_controller.dart';

// ---------------------------------------------------------------------------
// Dobles de prueba
// ---------------------------------------------------------------------------

const _creador = UsuarioResumen(id: 1, username: 'usuario_a', email: 'usuario.a@prueba.com', rol: 'USER');
const _agente = UsuarioResumen(id: 3, username: 'agente', email: 'agente@prueba.com', rol: 'AGENTE');

Incidencia incidencia({int version = 0, UsuarioResumen? asignado, EstadoIncidencia estado = EstadoIncidencia.pendiente}) =>
    Incidencia(
      id: 7,
      titulo: 'No carga el Sudoku',
      descripcion: 'Pantalla en blanco',
      estado: estado,
      prioridad: PrioridadIncidencia.media,
      creadoPor: _creador,
      asignadoA: asignado,
      fechaCreacion: DateTime(2026, 11, 11, 9, 0),
      fechaActualizacion: DateTime(2026, 11, 11, 9, 0),
      version: version,
    );

/// Repositorio falso: cuenta llamadas y puede fallar con la excepción indicada.
class _RepoFalso implements IncidenciasRepository {
  Object? fallaAlGuardar; // excepción a lanzar en actualizar/asignar
  Object? fallaAlListar;
  Incidencia actual = incidencia(asignado: _agente);
  int llamadasListar = 0;
  int llamadasObtener = 0;
  int? versionEnviada;
  EstadoIncidencia? estadoEnviado;

  @override
  ApiClient get api => throw UnimplementedError();

  @override
  Future<List<Incidencia>> listar() async {
    llamadasListar++;
    if (fallaAlListar != null) throw fallaAlListar!;
    return [
      actual,
      incidencia(estado: EstadoIncidencia.resuelta).copiarConId(8),
    ];
  }

  @override
  Future<Incidencia> obtener(int id) async {
    llamadasObtener++;
    return actual;
  }

  @override
  Future<Incidencia> crear({required String titulo, required String descripcion, required PrioridadIncidencia prioridad}) async =>
      incidencia().copiarConId(99);

  @override
  Future<Incidencia> actualizar(int id,
      {required int version, String? titulo, String? descripcion, EstadoIncidencia? estado, PrioridadIncidencia? prioridad}) async {
    versionEnviada = version;
    estadoEnviado = estado;
    if (fallaAlGuardar != null) throw fallaAlGuardar!;
    return actual = incidencia(version: version + 1, asignado: _agente, estado: estado ?? actual.estado);
  }

  @override
  Future<Incidencia> asignar(int id, int agenteId) async {
    if (fallaAlGuardar != null) throw fallaAlGuardar!;
    return actual = incidencia(version: actual.version + 1, asignado: _agente);
  }

  @override
  Future<void> eliminar(int id) async {
    if (fallaAlGuardar != null) throw fallaAlGuardar!;
  }

  @override
  Future<List<UsuarioResumen>> agentes() async => [_agente];
}

extension on Incidencia {
  Incidencia copiarConId(int nuevoId) => Incidencia(
        id: nuevoId,
        titulo: titulo,
        descripcion: descripcion,
        estado: estado,
        prioridad: prioridad,
        creadoPor: creadoPor,
        asignadoA: asignadoA,
        fechaCreacion: fechaCreacion,
        fechaActualizacion: fechaActualizacion,
        version: version,
      );
}

/// AuthController falso con el rol y correo indicados.
class _AuthFalso extends AuthController {
  _AuthFalso(this.correo, this.rol);
  final String correo;
  final String rol;
  bool sesionExpiradaLlamada = false;

  @override
  AuthState build() => AuthState(status: AuthStatus.autenticado, correo: correo, rol: rol);

  @override
  Future<void> sesionExpirada() async {
    sesionExpiradaLlamada = true;
    state = const AuthState(status: AuthStatus.noAutenticado, error: 'Tu sesión expiró');
  }
}

ProviderContainer _contenedor(_RepoFalso repo, {String correo = 'usuario.a@prueba.com', String rol = 'USER'}) =>
    ProviderContainer(overrides: [
      incidenciasRepositoryProvider.overrideWithValue(repo),
      authControllerProvider.overrideWith(() => _AuthFalso(correo, rol)),
    ]);

/// ApiClient falso para revisar qué envía el repositorio.
class _DaoFalso implements SesionDao {
  @override
  Future<Sesion?> obtener() async => null;
  @override
  Future<void> guardar(Sesion sesion) async {}
  @override
  Future<void> limpiar() async {}
}

class _ApiQueAnota extends ApiClient {
  _ApiQueAnota() : super(_DaoFalso());
  Map<String, dynamic>? cuerpo;
  String? ruta;

  @override
  Future<dynamic> put(String ruta, Map<String, dynamic> cuerpo, {bool autenticado = false}) async {
    this.ruta = ruta;
    this.cuerpo = cuerpo;
    return {
      'id': 7, 'titulo': 't', 'descripcion': 'd', 'estado': 'EN_PROCESO', 'prioridad': 'CRITICA',
      'creadoPor': {'id': 1, 'username': 'u', 'email': 'u@x.com', 'rol': 'USER'}, 'asignadoA': null,
      'fechaCreacion': '2026-11-11T09:00:00.123456', 'fechaActualizacion': '2026-11-11T09:05:00',
      'version': 4,
    };
  }
}

/// Cierra la suscripción, deja que Riverpod destruya el provider autoDispose
/// (lo programa para el siguiente ciclo) y libera el contenedor.
Future<void> cerrar(WidgetTester tester, ProviderSubscription<Object?> sub, ProviderContainer c) async {
  sub.close();
  await tester.pump(const Duration(seconds: 1));
  c.dispose();
}

void main() {
  // ---------------- Validaciones ----------------
  group('validaciones', () {
    test('título obligatorio, sin solo espacios y máx. 80', () {
      expect(validarTituloIncidencia(''), isNotNull);
      expect(validarTituloIncidencia('    '), isNotNull);
      expect(validarTituloIncidencia('a' * 80), isNull);
      expect(validarTituloIncidencia('a' * 81), isNotNull);
    });
    test('descripción máx. 500 (y obligatoria porque el backend la exige)', () {
      expect(validarDescripcionIncidencia('   '), isNotNull);
      expect(validarDescripcionIncidencia('a' * 500), isNull);
      expect(validarDescripcionIncidencia('a' * 501), isNotNull);
    });
  });

  // ---------------- Repositorio ----------------
  test('actualizar envía la versión y solo los campos que cambian', () async {
    final api = _ApiQueAnota();
    final inc = await IncidenciasRepository(api)
        .actualizar(7, version: 3, estado: EstadoIncidencia.enProceso);
    expect(api.ruta, '/api/incidencias/7');
    expect(api.cuerpo, {'version': 3, 'estado': 'EN_PROCESO'});
    expect(inc.version, 4);
    expect(inc.prioridad, PrioridadIncidencia.critica);
  });

  // ---------------- Lista ----------------
  group('lista y sincronización', () {
    testWidgets('USER: sin Timer (solo pull-to-refresh)', (tester) async {
      final repo = _RepoFalso();
      final c = _contenedor(repo);
      final sub = c.listen(listaIncidenciasProvider, (_, _) {});
      await tester.pump();
      expect(repo.llamadasListar, 1);
      await tester.pump(const Duration(seconds: 11));
      expect(repo.llamadasListar, 1); // no se actualiza solo
      await cerrar(tester, sub, c);
    });

    testWidgets('ADMIN: se actualiza cada 5 s y el Timer se cancela al salir', (tester) async {
      final repo = _RepoFalso();
      final c = _contenedor(repo, correo: 'admin@prueba.com', rol: 'ADMIN');
      final sub = c.listen(listaIncidenciasProvider, (_, _) {});
      await tester.pump();
      expect(repo.llamadasListar, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(repo.llamadasListar, 2);
      await tester.pump(const Duration(seconds: 5));
      expect(repo.llamadasListar, 3);
      expect(c.read(listaIncidenciasProvider).ultimaActualizacion, isNotNull);

      // Salir de la pantalla: nadie escucha -> autoDispose -> onDispose cancela el Timer.
      sub.close();
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(repo.llamadasListar, 3);
      c.dispose(); // testWidgets fallaría si quedara un Timer vivo
    });

    testWidgets('filtro por estado', (tester) async {
      final c = _contenedor(_RepoFalso());
      final sub = c.listen(listaIncidenciasProvider, (_, _) {});
      await tester.pump();
      c.read(listaIncidenciasProvider.notifier).cambiarFiltro(EstadoIncidencia.resuelta);
      expect(c.read(listaIncidenciasProvider).visibles.single.id, 8);
      c.read(listaIncidenciasProvider.notifier).cambiarFiltro(null);
      expect(c.read(listaIncidenciasProvider).visibles.length, 2);
      await cerrar(tester, sub, c);
    });

    testWidgets('sesión expirada al listar -> authController.sesionExpirada()', (tester) async {
      final repo = _RepoFalso()..fallaAlListar = const SesionExpiradaException();
      final c = _contenedor(repo);
      final auth = c.read(authControllerProvider.notifier) as _AuthFalso;
      final sub = c.listen(listaIncidenciasProvider, (_, _) {});
      await tester.pump();
      expect(auth.sesionExpiradaLlamada, isTrue);
      await cerrar(tester, sub, c);
    });
  });

  // ---------------- Detalle ----------------
  group('detalle: versión, 409 y 403', () {
    testWidgets('cambiar estado envía la versión actual', (tester) async {
      final repo = _RepoFalso()..actual = incidencia(version: 5, asignado: _agente);
      final c = _contenedor(repo, correo: 'agente@prueba.com', rol: 'AGENTE');
      final sub = c.listen(detalleIncidenciaProvider(7), (_, _) {});
      await tester.pump();
      final r = await c.read(detalleIncidenciaProvider(7).notifier).cambiarEstado(EstadoIncidencia.enProceso);
      expect(r, ResultadoAccion.ok);
      expect(repo.versionEnviada, 5);
      expect(c.read(detalleIncidenciaProvider(7)).incidencia!.version, 6);
      await cerrar(tester, sub, c);
    });

    testWidgets('409 -> conflicto y "Recargar" lo quita', (tester) async {
      final repo = _RepoFalso()..fallaAlGuardar = const ErrorHttpException(409);
      final c = _contenedor(repo);
      final sub = c.listen(detalleIncidenciaProvider(7), (_, _) {});
      await tester.pump();
      final ctrl = c.read(detalleIncidenciaProvider(7).notifier);
      expect(await ctrl.editarTexto(titulo: 'x', descripcion: 'y', version: 0), ResultadoAccion.conflicto);
      expect(mensajeDe(ResultadoAccion.conflicto), 'El registro fue modificado desde otro dispositivo');
      expect(c.read(detalleIncidenciaProvider(7)).conflicto, isTrue);
      await ctrl.recargar();
      expect(c.read(detalleIncidenciaProvider(7)).conflicto, isFalse);
      await cerrar(tester, sub, c);
    });

    testWidgets('403 del servidor -> "No tienes permiso para esta acción" sin cerrar sesión', (tester) async {
      final repo = _RepoFalso()..fallaAlGuardar = const PermisoDenegadoException();
      final c = _contenedor(repo);
      final auth = c.read(authControllerProvider.notifier) as _AuthFalso;
      final sub = c.listen(detalleIncidenciaProvider(7), (_, _) {});
      await tester.pump();
      final r = await c.read(detalleIncidenciaProvider(7).notifier).cambiarPrioridad(PrioridadIncidencia.alta);
      expect(r, ResultadoAccion.sinPermiso);
      expect(mensajeDe(r), 'No tienes permiso para esta acción');
      expect(auth.sesionExpiradaLlamada, isFalse);
      await cerrar(tester, sub, c);
    });

    testWidgets('sesión expirada al guardar -> sesionExpirada()', (tester) async {
      final repo = _RepoFalso()..fallaAlGuardar = const SesionExpiradaException();
      final c = _contenedor(repo);
      final auth = c.read(authControllerProvider.notifier) as _AuthFalso;
      final sub = c.listen(detalleIncidenciaProvider(7), (_, _) {});
      await tester.pump();
      await c.read(detalleIncidenciaProvider(7).notifier).asignar(3);
      expect(auth.sesionExpiradaLlamada, isTrue);
      await cerrar(tester, sub, c);
    });
  });

  // ---------------- Pantallas ----------------
  group('pantallas', () {
    Future<_RepoFalso> montar(WidgetTester tester, Widget pantalla,
        {required String correo, required String rol, _RepoFalso? repo}) async {
      final r = repo ?? _RepoFalso();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          incidenciasRepositoryProvider.overrideWithValue(r),
          authControllerProvider.overrideWith(() => _AuthFalso(correo, rol)),
        ],
        child: MaterialApp(home: pantalla),
      ));
      await tester.pump();
      await tester.pump();
      return r;
    }

    Future<void> salir(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }

    testWidgets('creador (USER): editar y eliminar; sin estado, prioridad ni asignar', (tester) async {
      await montar(tester, const DetalleIncidenciaPage(id: 7), correo: 'usuario.a@prueba.com', rol: 'USER');
      expect(find.text('Editar título y descripción'), findsOneWidget);
      expect(find.text('Eliminar incidencia'), findsOneWidget);
      expect(find.text('Estado'), findsNothing);
      expect(find.text('Prioridad'), findsNothing);
      expect(find.text('Asignar a agente'), findsNothing);
      expect(find.textContaining('desliza hacia abajo'), findsOneWidget); // USER: pull-to-refresh
      await salir(tester);
    });

    testWidgets('agente asignado: solo cambia el estado', (tester) async {
      await montar(tester, const DetalleIncidenciaPage(id: 7), correo: 'agente@prueba.com', rol: 'AGENTE');
      expect(find.text('Estado'), findsOneWidget);
      expect(find.text('Prioridad'), findsNothing);
      expect(find.text('Editar título y descripción'), findsNothing);
      expect(find.text('Eliminar incidencia'), findsNothing);
      expect(find.textContaining('automático cada 5 s'), findsOneWidget);
      await salir(tester);
    });

    testWidgets('ADMIN: estado, prioridad y asignar agente', (tester) async {
      await montar(tester, const DetalleIncidenciaPage(id: 7), correo: 'admin@prueba.com', rol: 'ADMIN');
      expect(find.text('Estado'), findsOneWidget);
      expect(find.text('Prioridad'), findsOneWidget);
      expect(find.text('Asignar a agente'), findsOneWidget);
      await salir(tester);
    });

    testWidgets('si el servidor responde 403 se muestra el mensaje de permiso', (tester) async {
      final repo = _RepoFalso()..fallaAlGuardar = const PermisoDenegadoException();
      await montar(tester, const DetalleIncidenciaPage(id: 7),
          correo: 'agente@prueba.com', rol: 'AGENTE', repo: repo);
      await tester.tap(find.text('Pendiente').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('En proceso').last);
      await tester.pump();
      await tester.pump();
      expect(find.text('No tienes permiso para esta acción'), findsOneWidget);
      await salir(tester);
    });

    testWidgets('409 muestra el aviso con "Recargar"', (tester) async {
      final repo = _RepoFalso()..fallaAlGuardar = const ErrorHttpException(409);
      await montar(tester, const DetalleIncidenciaPage(id: 7),
          correo: 'agente@prueba.com', rol: 'AGENTE', repo: repo);
      await tester.tap(find.text('Pendiente').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('En proceso').last);
      await tester.pump();
      await tester.pump();
      expect(find.text('El registro fue modificado desde otro dispositivo'), findsWidgets);
      repo.fallaAlGuardar = null;
      await tester.tap(find.text('Recargar'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Recargar'), findsNothing);
      await salir(tester);
    });

    testWidgets('lista: vista por rol, filtros con conteo y botón "Nueva"', (tester) async {
      await montar(tester, const IncidenciasPage(), correo: 'usuario.a@prueba.com', rol: 'USER');
      expect(find.textContaining('tus incidencias'), findsOneWidget);
      expect(find.text('Todos (2)'), findsOneWidget);
      expect(find.text('Resuelta (1)'), findsOneWidget);
      expect(find.text('Nueva'), findsOneWidget);
      await tester.tap(find.text('Resuelta (1)'));
      await tester.pump();
      expect(find.byType(Card), findsOneWidget);
      await salir(tester);
    });

    testWidgets('lista de AGENTE: sin botón "Nueva"', (tester) async {
      await montar(tester, const IncidenciasPage(), correo: 'agente@prueba.com', rol: 'AGENTE');
      expect(find.textContaining('asignadas a ti'), findsOneWidget);
      expect(find.text('Nueva'), findsNothing);
      await salir(tester);
    });

    testWidgets('crear: valida título vacío, solo espacios y descripción', (tester) async {
      await montar(tester, const CrearIncidenciaPage(), correo: 'usuario.a@prueba.com', rol: 'USER');
      await tester.enterText(find.widgetWithText(TextFormField, 'Título'), '    ');
      await tester.tap(find.text('Crear incidencia'));
      await tester.pump();
      expect(find.text('Escribe un título'), findsOneWidget);
      expect(find.text('Describe el problema'), findsOneWidget);
      // maxLength corta el título a 80.
      await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'a' * 100);
      final campo = tester.widget<TextField>(find.descendant(
          of: find.widgetWithText(TextFormField, 'Título'), matching: find.byType(TextField)));
      expect(campo.controller!.text.length, 80);
      await salir(tester);
    });
  });
}
