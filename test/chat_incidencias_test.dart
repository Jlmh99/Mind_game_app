import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/core/errores_api.dart';
import 'package:mindgames_app/core/sesion_expirada_exception.dart';
import 'package:mindgames_app/data/incidencias_repository.dart';
import 'package:mindgames_app/data/local/sesion.dart';
import 'package:mindgames_app/data/local/sesion_dao.dart';
import 'package:mindgames_app/data/mensajes_repository.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/features/incidencias/chat/chat_comun.dart';
import 'package:mindgames_app/features/incidencias/chat/chat_controller.dart';
import 'package:mindgames_app/features/incidencias/chat/chat_incidencia_page.dart';
import 'package:mindgames_app/features/incidencias/chat/selector_archivos.dart';
import 'package:mindgames_app/features/incidencias/chat/widgets/burbuja_chat.dart';

// ---------------------------------------------------------------------------
// Datos y dobles de prueba
// ---------------------------------------------------------------------------

const _creador = UsuarioResumen(id: 1, username: 'usuario_a', email: 'usuario.a@prueba.com', rol: 'USER');
const _agente = UsuarioResumen(id: 3, username: 'agente', email: 'agente@prueba.com', rol: 'AGENTE');
const _admin = UsuarioResumen(id: 4, username: 'admin', email: 'admin@prueba.com', rol: 'ADMIN');

final _incidencia = Incidencia(
  id: 7,
  titulo: 'No carga',
  descripcion: 'x',
  estado: EstadoIncidencia.enProceso,
  prioridad: PrioridadIncidencia.media,
  creadoPor: _creador,
  asignadoA: _agente,
  fechaCreacion: DateTime(2026, 11, 11),
  fechaActualizacion: DateTime(2026, 11, 11),
  version: 1,
);

final Uint8List _png = img.encodePng(img.Image(width: 4, height: 4));
final Uint8List _pdf = Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF\n'));

MensajeIncidencia _msg(int id, UsuarioResumen emisor, String texto,
        {CanalChat canal = CanalChat.publico, AdjuntoMensaje? adjunto}) =>
    MensajeIncidencia(
      id: id,
      incidenciaId: 7,
      emisor: emisor,
      texto: texto,
      canal: canal,
      fecha: DateTime(2026, 11, 11, 9, 5 + id),
      adjunto: adjunto,
    );

class _RepoFalso implements MensajesRepository {
  final Map<CanalChat, List<MensajeIncidencia>> servidor = {
    CanalChat.publico: [_msg(1, _creador, 'Hola, no carga')],
    CanalChat.interno: [],
  };
  Object? falla; // excepción a lanzar al listar
  int llamadasListar = 0;
  int llamadasEnviar = 0;
  AdjuntoMensaje? ultimoAdjunto;
  late UsuarioResumen yo;

  @override
  ApiClient get api => throw UnimplementedError();

  @override
  Future<List<MensajeIncidencia>> listar(int incidenciaId, CanalChat canal) async {
    llamadasListar++;
    if (falla != null) throw falla!;
    return List.of(servidor[canal]!);
  }

  @override
  Future<MensajeIncidencia> enviar(int incidenciaId,
      {required String texto, required CanalChat canal, AdjuntoMensaje? adjunto}) async {
    llamadasEnviar++;
    ultimoAdjunto = adjunto;
    final m = _msg(100 + llamadasEnviar, yo, texto, canal: canal, adjunto: adjunto);
    servidor[canal]!.add(m);
    return m;
  }
}

class _AuthFalso extends AuthController {
  _AuthFalso(this.usuario);
  final UsuarioResumen usuario;
  bool sesionExpiradaLlamada = false;

  @override
  AuthState build() =>
      AuthState(status: AuthStatus.autenticado, correo: usuario.email, rol: usuario.rol);

  @override
  Future<void> sesionExpirada() async {
    sesionExpiradaLlamada = true;
    state = const AuthState(status: AuthStatus.noAutenticado, error: 'Tu sesión expiró');
  }
}

class _SelectorFalso extends SelectorArchivos {
  ArchivoElegido? siguiente;
  @override
  Future<ArchivoElegido?> imagen(ImageSource origen) async => siguiente;
  @override
  Future<ArchivoElegido?> pdf() async => siguiente;
}

List<Override> _overrides(_RepoFalso repo, UsuarioResumen yo, {_SelectorFalso? selector}) {
  repo.yo = yo;
  return [
    mensajesRepositoryProvider.overrideWithValue(repo),
    authControllerProvider.overrideWith(() => _AuthFalso(yo)),
    if (selector != null) selectorArchivosProvider.overrideWithValue(selector),
  ];
}

Future<void> _cerrar(WidgetTester t, ProviderSubscription<Object?> s, ProviderContainer c) async {
  s.close();
  await t.pump(const Duration(seconds: 1)); // Riverpod destruye el provider autoDispose
  c.dispose();
}

// ApiClient falso para revisar la ruta y el cuerpo que arma el repositorio.
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
  String? ruta;
  Map<String, dynamic>? cuerpo;

  Map<String, dynamic> _respuesta(String canal) => {
        'id': 5, 'incidenciaId': 7, 'texto': 'Captura', 'canal': canal,
        'fecha': '2026-11-11T09:07:00.123456',
        'emisor': {'id': 1, 'username': 'u', 'email': 'u@x.com', 'rol': 'USER'},
        'adjunto': {'nombre': 'c.png', 'tipo': 'image/png', 'contenido': base64Encode(_png)},
      };

  @override
  Future<dynamic> get(String ruta, {bool autenticado = false}) async {
    this.ruta = ruta;
    return [_respuesta('INTERNO')];
  }

  @override
  Future<dynamic> post(String ruta, Map<String, dynamic> cuerpo, {bool autenticado = false}) async {
    this.ruta = ruta;
    this.cuerpo = cuerpo;
    return _respuesta(cuerpo['canal'] as String);
  }
}

void main() {
  // ---------------- Repositorio ----------------
  group('MensajesRepository', () {
    test('listar pide el canal y decodifica el adjunto', () async {
      final api = _ApiQueAnota();
      final lista = await MensajesRepository(api).listar(7, CanalChat.interno);
      expect(api.ruta, '/api/incidencias/7/mensajes?canal=INTERNO');
      expect(lista.single.canal, CanalChat.interno);
      expect(lista.single.adjunto!.bytes, _png);
    });

    test('enviar manda texto, canal y adjunto en Base64', () async {
      final api = _ApiQueAnota();
      await MensajesRepository(api).enviar(7,
          texto: 'Captura',
          canal: CanalChat.publico,
          adjunto: AdjuntoMensaje(nombre: 'c.png', tipo: 'image/png', bytes: _png));
      expect(api.ruta, '/api/incidencias/7/mensajes');
      expect(api.cuerpo!['canal'], 'PUBLICO');
      expect(api.cuerpo!['adjunto'],
          {'nombre': 'c.png', 'tipo': 'image/png', 'contenido': base64Encode(_png)});
    });
  });

  // ---------------- Reglas ----------------
  group('validaciones y adjuntos', () {
    test('texto: obligatorio, sin solo espacios y máx. 1000', () {
      expect(validarTextoMensaje(''), isNotNull);
      expect(validarTextoMensaje('     '), isNotNull);
      expect(validarTextoMensaje('a' * 1000), isNull);
      expect(validarTextoMensaje('a' * 1001), isNotNull);
    });

    test('adjunto: tipo por sus bytes y máximo 2 MB', () {
      expect(prepararAdjunto('foto.png', _png).tipo, 'image/png');
      expect(prepararAdjunto('doc.pdf', _pdf).tipo, 'application/pdf');
      // Un ejecutable renombrado no pasa aunque diga ".png".
      expect(() => prepararAdjunto('x.png', Uint8List.fromList([0x4D, 0x5A, 0x90, 0, 0])),
          throwsA(isA<AdjuntoInvalidoException>()));
      final grande = Uint8List(maxAdjuntoBytes + 1)..setAll(0, _pdf);
      expect(() => prepararAdjunto('g.pdf', grande), throwsA(isA<AdjuntoInvalidoException>()));
    });

    test('participantes: el creador solo en el canal público y contadores', () {
      final mensajes = [_msg(1, _creador, 'a'), _msg(2, _creador, 'b'), _msg(3, _admin, 'c')];
      final pub = participantesDe(_incidencia, CanalChat.publico, mensajes, _creador.email);
      expect(pub.map((p) => p.papel), ['Creador', 'Agente', 'Administración']);
      expect(pub.first.enviados, 2);
      expect(pub.first.soyYo, isTrue);
      expect(pub.last.nombre, 'admin');

      final interno = participantesDe(_incidencia, CanalChat.interno, const [], _agente.email);
      expect(interno.map((p) => p.papel), ['Agente', 'Administración']);
      expect(interno.last.nombre, 'Administración'); // ningún admin ha escrito
    });

    test('hora de envío en HH:mm', () {
      expect(horaMensaje(DateTime(2026, 1, 1, 9, 5)), '09:05');
    });
  });

  // ---------------- Controller ----------------
  group('ChatController', () {
    const clave = (7, CanalChat.publico);

    testWidgets('ADMIN: se actualiza cada 3 s y avisa los mensajes nuevos de otros', (t) async {
      final repo = _RepoFalso();
      final c = ProviderContainer(overrides: _overrides(repo, _admin));
      final sub = c.listen(chatProvider(clave), (_, _) {});
      await t.pump();
      expect(repo.llamadasListar, 1);
      expect(c.read(chatProvider(clave)).avisosNuevos, 0); // la primera carga no avisa

      repo.servidor[CanalChat.publico]!.add(_msg(2, _creador, '¿Hay novedades?'));
      await t.pump(const Duration(seconds: 3));
      expect(repo.llamadasListar, 2);
      final estado = c.read(chatProvider(clave));
      expect(estado.avisosNuevos, 1);
      expect(estado.textoAviso, 'Nuevo mensaje de usuario_a');

      // Mis propios mensajes no generan aviso.
      await c.read(chatProvider(clave).notifier).enviar('Lo reviso');
      await t.pump(const Duration(seconds: 3));
      expect(c.read(chatProvider(clave)).avisosNuevos, 1);
      await _cerrar(t, sub, c);
    });

    testWidgets('USER: sin Timer (pull-to-refresh)', (t) async {
      final repo = _RepoFalso();
      final c = ProviderContainer(overrides: _overrides(repo, _creador));
      final sub = c.listen(chatProvider(clave), (_, _) {});
      await t.pump();
      await t.pump(const Duration(seconds: 10));
      expect(repo.llamadasListar, 1);
      await _cerrar(t, sub, c);
    });

    testWidgets('limpiar historial oculta lo visible sin borrar del servidor', (t) async {
      final repo = _RepoFalso();
      final c = ProviderContainer(overrides: _overrides(repo, _creador));
      final sub = c.listen(chatProvider(clave), (_, _) {});
      await t.pump();
      c.read(chatProvider(clave).notifier).limpiarHistorial();
      expect(c.read(chatProvider(clave)).visibles, isEmpty);
      expect(repo.servidor[CanalChat.publico], hasLength(1)); // sigue en el servidor

      await c.read(chatProvider(clave).notifier).enviar('Nuevo después de limpiar');
      expect(c.read(chatProvider(clave)).visibles.single.texto, 'Nuevo después de limpiar');
      await _cerrar(t, sub, c);
    });

    testWidgets('403 en el canal interno -> "No tienes permiso para esta acción"', (t) async {
      final repo = _RepoFalso()..falla = const PermisoDenegadoException();
      final c = ProviderContainer(overrides: _overrides(repo, _creador));
      final sub = c.listen(chatProvider((7, CanalChat.interno)), (_, _) {});
      await t.pump();
      expect(c.read(chatProvider((7, CanalChat.interno))).error, 'No tienes permiso para esta acción');
      await _cerrar(t, sub, c);
    });

    testWidgets('texto inválido no llama al servidor', (t) async {
      final repo = _RepoFalso();
      final c = ProviderContainer(overrides: _overrides(repo, _creador));
      final sub = c.listen(chatProvider(clave), (_, _) {});
      await t.pump();
      await c.read(chatProvider(clave).notifier).enviar('    ');
      await c.read(chatProvider(clave).notifier).enviar('a' * 1001);
      expect(repo.llamadasEnviar, 0);
      await _cerrar(t, sub, c);
    });

    testWidgets('sesión expirada -> authController.sesionExpirada()', (t) async {
      final repo = _RepoFalso()..falla = const SesionExpiradaException();
      final c = ProviderContainer(overrides: _overrides(repo, _creador));
      final sub = c.listen(chatProvider(clave), (_, _) {});
      await t.pump();
      expect((c.read(authControllerProvider.notifier) as _AuthFalso).sesionExpiradaLlamada, isTrue);
      await _cerrar(t, sub, c);
    });
  });

  // ---------------- Pantalla ----------------
  group('pantalla del chat', () {
    Future<_RepoFalso> montar(WidgetTester t, UsuarioResumen yo,
        {_RepoFalso? repo, _SelectorFalso? selector}) async {
      final r = repo ?? _RepoFalso();
      await t.pumpWidget(ProviderScope(
        overrides: _overrides(r, yo, selector: selector),
        child: MaterialApp(home: ChatIncidenciaPage(incidencia: _incidencia)),
      ));
      await t.pump();
      await t.pump();
      return r;
    }

    Future<void> salir(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    }

    Future<void> escribirYEnviar(WidgetTester t, String texto) async {
      await t.enterText(find.byType(TextField), texto);
      await t.tap(find.byTooltip('Enviar'));
      await t.pump();
      await t.pump();
    }

    testWidgets('USER: sin pestaña "Interno"', (t) async {
      await montar(t, _creador);
      expect(find.text('Interno'), findsNothing);
      expect(find.textContaining('desliza hacia abajo'), findsOneWidget);
      await salir(t);
    });

    testWidgets('ADMIN: pestañas "Con el usuario" e "Interno"', (t) async {
      await montar(t, _admin);
      expect(find.text('Con el usuario'), findsOneWidget);
      expect(find.text('Interno'), findsOneWidget);
      expect(find.textContaining('automático cada 3 s'), findsOneWidget);
      await salir(t);
    });

    testWidgets('burbujas: lo mío a la derecha, lo de otros a la izquierda; SnackBar al enviar',
        (t) async {
      await montar(t, _creador);
      await escribirYEnviar(t, '    ');
      expect(find.text('Escribe un mensaje antes de enviar'), findsOneWidget);

      await escribirYEnviar(t, 'Sigue sin cargar');
      expect(find.text('Mensaje enviado'), findsOneWidget);
      expect(find.text('Tú (Creador) · 2 enviados'), findsOneWidget);

      Alignment alineacion(String texto) => t
          .widget<Align>(find.ancestor(of: find.text(texto), matching: find.byType(Align)).first)
          .alignment as Alignment;
      expect(alineacion('Sigue sin cargar'), Alignment.centerRight);
      await salir(t);
    });

    testWidgets('ADMIN: SnackBar cuando llega un mensaje nuevo', (t) async {
      final repo = await montar(t, _admin);
      repo.servidor[CanalChat.publico]!.add(_msg(2, _creador, 'Ya probé otra vez'));
      await t.pump(const Duration(seconds: 3));
      await t.pump();
      expect(find.text('Nuevo mensaje de usuario_a'), findsOneWidget);
      await salir(t);
    });

    testWidgets('adjuntar PDF: vista previa con ícono y nombre, y se envía', (t) async {
      final selector = _SelectorFalso()..siguiente = ArchivoElegido('manual.pdf', _pdf);
      final repo = await montar(t, _creador, selector: selector);
      await t.tap(find.byTooltip('Adjuntar imagen o PDF'));
      await t.pumpAndSettle();
      await t.tap(find.text('Documento PDF'));
      await t.pump();
      await t.pump();
      expect(find.text('manual.pdf'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);

      await escribirYEnviar(t, 'Te mando el manual');
      expect(repo.ultimoAdjunto!.tipo, 'application/pdf');
      expect(find.byType(BurbujaChat), findsNWidgets(2));
      await salir(t);
    });

    testWidgets('adjunto de tipo no permitido muestra un aviso', (t) async {
      final selector = _SelectorFalso()
        ..siguiente = ArchivoElegido('virus.png', Uint8List.fromList([0x4D, 0x5A, 0, 0, 0]));
      await montar(t, _creador, selector: selector);
      await t.tap(find.byTooltip('Adjuntar imagen o PDF'));
      await t.pumpAndSettle();
      await t.tap(find.text('Imagen de la galería'));
      await t.pump();
      expect(find.text('Formato no permitido (usa JPG, PNG o PDF)'), findsOneWidget);
      await salir(t);
    });

    testWidgets('limpiar historial pide confirmación', (t) async {
      await montar(t, _creador);
      await t.tap(find.byTooltip('Limpiar historial'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      expect(find.byType(BurbujaChat), findsOneWidget);

      await t.tap(find.byTooltip('Limpiar historial'));
      await t.pumpAndSettle();
      await t.tap(find.text('Limpiar'));
      await t.pumpAndSettle();
      expect(find.byType(BurbujaChat), findsNothing);
      expect(find.text('Aún no hay mensajes en este canal.'), findsOneWidget);
      await salir(t);
    });
  });
}
