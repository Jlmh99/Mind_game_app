// Práctica 14: nota "el servidor puede tardar hasta un minuto si estuvo
// inactivo" bajo los errores de carga (Render dormido: 1.ª petición de 36 s,
// más que el timeout de 30 s de la app). Se conserva el mensaje de siempre y
// el "Reintentar"; con un 403 de permiso NO se muestra (esperar no lo arregla).
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/core/errores_api.dart';
import 'package:mindgames_app/core/widgets/nota_servidor_inactivo.dart';
import 'package:mindgames_app/data/foto_perfil_repository.dart';
import 'package:mindgames_app/data/incidencias_repository.dart';
import 'package:mindgames_app/data/mensajes_repository.dart';
import 'package:mindgames_app/data/partidas_repository.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/features/incidencias/chat/chat_controller.dart';
import 'package:mindgames_app/features/incidencias/chat/chat_incidencia_page.dart';
import 'package:mindgames_app/features/incidencias/incidencias_comun.dart';
import 'package:mindgames_app/features/incidencias/incidencias_page.dart';
import 'package:mindgames_app/features/perfil/perfil_page.dart';
import 'apoyo_p14.dart';

class _PartidasQueFallan implements PartidasRepository {
  @override
  Future<List<Partida>> misPartidas() async => throw const ErrorHttpException(503);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _SinFoto implements FotoPerfilRepository {
  @override
  Future<Uint8List?> obtener() async => null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _IncidenciasQueFallan implements IncidenciasRepository {
  _IncidenciasQueFallan(this.falla);
  final Object falla;
  @override
  Future<List<Incidencia>> listar() async => throw falla;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _MensajesQueFallan implements MensajesRepository {
  _MensajesQueFallan(this.falla);
  final Object falla;
  @override
  Future<List<MensajeIncidencia>> listar(int incidenciaId, CanalChat canal) async => throw falla;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

final _incidencia = Incidencia(
  id: 1,
  titulo: 'PRUEBA',
  descripcion: 'd',
  estado: EstadoIncidencia.pendiente,
  prioridad: PrioridadIncidencia.media,
  creadoPor: const UsuarioResumen(id: 19, username: 'prueba', email: 'a@ejemplo.com', rol: 'USER'),
  asignadoA: null,
  fechaCreacion: DateTime.utc(2026, 11, 26, 17),
  fechaActualizacion: DateTime.utc(2026, 11, 26, 17),
  version: 0,
);

Future<void> montar(WidgetTester tester, Widget pantalla, List<Override> overrides) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [authControllerProvider.overrideWith(() => AuthFalso('a@ejemplo.com')), ...overrides],
    child: MaterialApp(home: pantalla),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> salir(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  test('P14-NOTA: el texto explica la espera de hasta un minuto', () {
    expect(notaServidorInactivo, contains('hasta un minuto'));
    expect(notaServidorInactivo, contains('inactivo'));
  });

  testWidgets('P14-NOTA: Mi perfil, error al cargar partidas -> mensaje, nota y "Reintentar"', (tester) async {
    await montar(tester, const PerfilPage(), [
      partidasRepositoryProvider.overrideWithValue(_PartidasQueFallan()),
      fotoPerfilRepositoryProvider.overrideWithValue(_SinFoto()),
    ]);
    expect(find.text('No se pudieron cargar tus partidas'), findsOneWidget);
    expect(find.text(notaServidorInactivo), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    await salir(tester);
  });

  testWidgets('P14-NOTA: lista de incidencias, error de carga -> mensaje y nota', (tester) async {
    await montar(tester, const IncidenciasPage(), [
      incidenciasRepositoryProvider.overrideWithValue(_IncidenciasQueFallan(const ErrorHttpException(500))),
    ]);
    expect(find.text(mensajeErrorCarga), findsOneWidget);
    expect(find.text(notaServidorInactivo), findsOneWidget);
    expect(find.text('Desliza hacia abajo para reintentar'), findsOneWidget);
    await salir(tester);
  });

  testWidgets('P14-NOTA: lista de incidencias con 403 de permiso -> SIN nota', (tester) async {
    await montar(tester, const IncidenciasPage(), [
      incidenciasRepositoryProvider.overrideWithValue(_IncidenciasQueFallan(const PermisoDenegadoException())),
    ]);
    expect(find.text(mensajeSinPermiso), findsOneWidget);
    expect(find.text(notaServidorInactivo), findsNothing);
    await salir(tester);
  });

  testWidgets('P14-NOTA: chat, error al cargar mensajes -> mensaje y nota', (tester) async {
    await montar(tester, ChatIncidenciaPage(incidencia: _incidencia), [
      mensajesRepositoryProvider.overrideWithValue(_MensajesQueFallan(const ErrorHttpException(502))),
    ]);
    expect(find.text(mensajeErrorCargaMensajes), findsOneWidget);
    expect(find.text(notaServidorInactivo), findsOneWidget);
    await salir(tester);
  });

  testWidgets('P14-NOTA: chat con 403 de permiso -> SIN nota', (tester) async {
    await montar(tester, ChatIncidenciaPage(incidencia: _incidencia), [
      mensajesRepositoryProvider.overrideWithValue(_MensajesQueFallan(const PermisoDenegadoException())),
    ]);
    expect(find.text(mensajeSinPermiso), findsOneWidget);
    expect(find.text(notaServidorInactivo), findsNothing);
    await salir(tester);
  });
}
