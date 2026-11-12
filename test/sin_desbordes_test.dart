import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/data/foto_perfil_repository.dart';
import 'package:mindgames_app/data/partidas_repository.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/features/auth/auth_pages.dart';
import 'package:mindgames_app/features/crucigrama/crucigrama_page.dart';
import 'package:mindgames_app/features/home/home_page.dart';
import 'package:mindgames_app/features/mobileconnect/canal_controller.dart';
import 'package:mindgames_app/features/mobileconnect/mobileconnect_page.dart';
import 'package:mindgames_app/features/perfil/perfil_page.dart';
import 'package:mindgames_app/data/incidencias_repository.dart';
import 'package:mindgames_app/data/usuario_repository.dart';
import 'package:mindgames_app/data/mensajes_repository.dart';
import 'package:mindgames_app/features/incidencias/chat/chat_incidencia_page.dart';
import 'package:image/image.dart' as img;
import 'package:mindgames_app/features/incidencias/crear_incidencia_page.dart';
import 'package:mindgames_app/features/incidencias/detalle_incidencia_page.dart';
import 'package:mindgames_app/features/incidencias/incidencias_page.dart';
import 'package:mindgames_app/features/sudoku/sudoku_page.dart';

// Revisión final: cada pantalla se dibuja en celulares verticales pequeños,
// con teclado abierto y con texto agrandado. Si algo se desborda
// ("RenderFlex overflowed..."), Flutter reporta un error y la prueba falla.

class _AuthFalso extends AuthController {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.autenticado,
        correo: 'un.correo.bastante.largo.para.probar@universidad.edu.mx',
        rol: 'ADMIN', // ADMIN: muestra todos los controles de incidencias
        // Error largo para comprobar que también cabe en login/registro.
        error: 'No se pudo conectar, intenta de nuevo',
      );
}

class _PartidasFalsas implements PartidasRepository {
  @override
  ApiClient get api => throw UnimplementedError();
  @override
  Future<Partida> guardar(
          {required String juego,
          required int tiempoSegundos,
          required int puntuacion}) =>
      throw UnimplementedError();
  @override
  Future<List<Partida>> misPartidas() async => [
        for (var i = 0; i < 8; i++)
          Partida(
            id: i,
            juego: i.isEven ? juegoSudoku : juegoCrucigrama,
            tiempoSegundos: 3599,
            puntuacion: 1000,
            fecha: DateTime(2026, 12, 31, 23, 59),
          ),
      ];
}

/// Incidencia con textos largos para el peor caso de diseño.
final _incidenciaLarga = Incidencia(
  id: 12345,
  titulo: 'El crucigrama no valida la palabra aunque esté bien escrita en mayúsculas',
  descripcion: 'Descripción larga ' * 20,
  estado: EstadoIncidencia.enProceso,
  prioridad: PrioridadIncidencia.critica,
  creadoPor: const UsuarioResumen(id: 1, username: 'usuario_con_nombre_largo', email: 'a@b.com'),
  asignadoA: const UsuarioResumen(id: 3, username: 'agente_con_nombre_muy_largo', email: 'c@d.com'),
  fechaCreacion: DateTime(2026, 12, 31, 23, 59),
  fechaActualizacion: DateTime(2026, 12, 31, 23, 59),
  version: 999,
);

class _IncidenciasFalsas implements IncidenciasRepository {
  @override
  ApiClient get api => throw UnimplementedError();
  @override
  Future<List<Incidencia>> listar() async => List.filled(6, _incidenciaLarga);
  @override
  Future<Incidencia> obtener(int id) async => _incidenciaLarga;
  @override
  Future<List<UsuarioResumen>> agentes() async =>
      [const UsuarioResumen(id: 3, username: 'agente_con_nombre_muy_largo', email: 'c@d.com')];
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

/// Mensajes con nombres largos, una imagen y un PDF (peor caso del chat).
class _MensajesFalsos implements MensajesRepository {
  @override
  ApiClient get api => throw UnimplementedError();
  @override
  Future<List<MensajeIncidencia>> listar(int incidenciaId, CanalChat canal) async => [
        for (var i = 0; i < 6; i++)
          MensajeIncidencia(
            id: i + 1,
            incidenciaId: incidenciaId,
            emisor: UsuarioResumen(
                id: i,
                username: 'participante_con_nombre_largo_$i',
                email: 'p$i@x.com',
                rol: i.isEven ? 'USER' : 'ADMIN'),
            texto: 'Mensaje con bastante texto para ver cómo se acomoda la burbuja $i',
            canal: canal,
            fecha: DateTime(2026, 11, 11, 9, i),
            // Como los manda el servidor desde la Práctica 12: sin contenido.
            adjunto: i == 1
                ? AdjuntoMensaje.remoto(nombre: 'captura.png', tipo: 'image/png', tamano: _png.length)
                : i == 3
                    ? const AdjuntoMensaje.remoto(
                        nombre: 'documento_con_un_nombre_de_archivo_muy_largo.pdf',
                        tipo: 'application/pdf',
                        tamano: 8)
                    : null,
          ),
      ];

  /// La imagen se descarga aparte (adjuntosCacheProvider).
  @override
  Future<Uint8List> descargarAdjunto(int incidenciaId, int mensajeId) async => _png;

  static final Uint8List _png = img.encodePng(img.Image(width: 8, height: 8));
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _UsuarioFalso implements UsuarioRepository {
  @override
  ApiClient get api => throw UnimplementedError();
  @override
  Future<UsuarioActual> actual() async =>
      const UsuarioActual(id: 123456, username: 'u', email: 'u@x.com', rol: 'AGENTE');
}

class _FotoFalsa implements FotoPerfilRepository {
  @override
  ApiClient get api => throw UnimplementedError();
  @override
  Future<Uint8List?> obtener() async => null;
  @override
  Future<void> subir(Uint8List bytes) async {}
}

/// Configuración del "celular" de prueba.
class _Pantalla {
  final String nombre;
  final Size tamano;
  final double tecladoAlto; // 0 = teclado cerrado
  final double escalaTexto;
  const _Pantalla(this.nombre, this.tamano,
      {this.tecladoAlto = 0, this.escalaTexto = 1});
}

const _pantallas = [
  _Pantalla('360x640', Size(360, 640)),
  _Pantalla('320x568 (pequeño)', Size(320, 568)),
  _Pantalla('360x640 con teclado', Size(360, 640), tecladoAlto: 280),
  _Pantalla('360x640 texto 130 %', Size(360, 640), escalaTexto: 1.3),
];

/// Pantallas de la app a revisar.
final Map<String, Widget Function()> _vistas = {
  'Login': () => const LoginPage(),
  'Registro': () => const RegisterPage(),
  'Código 2FA': () => const VerifyCodePage(),
  'Inicio': () => const HomePage(),
  'Mi perfil': () => const PerfilPage(),
  'Sudoku': () => const SudokuPage(),
  'Crucigrama': () => const CrucigramaPage(),
  'MobileConnect': () => const MobileConnectPage(),
  'Incidencias': () => const IncidenciasPage(),
  'Nueva incidencia': () => const CrearIncidenciaPage(),
  'Detalle de incidencia': () => const DetalleIncidenciaPage(id: 12345),
  'Chat de incidencia': () => ChatIncidenciaPage(incidencia: _incidenciaLarga),
};

void main() {
  for (final p in _pantallas) {
    for (final vista in _vistas.entries) {
      testWidgets('${vista.key} cabe en ${p.nombre}', (tester) async {
        tester.view.physicalSize = p.tamano;
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = FakeViewPadding(bottom: p.tecladoAlto);
        tester.platformDispatcher.textScaleFactorTestValue = p.escalaTexto;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final contenedor = ProviderContainer(overrides: [
          authControllerProvider.overrideWith(_AuthFalso.new),
          partidasRepositoryProvider.overrideWithValue(_PartidasFalsas()),
          fotoPerfilRepositoryProvider.overrideWithValue(_FotoFalsa()),
          incidenciasRepositoryProvider.overrideWithValue(_IncidenciasFalsas()),
          usuarioRepositoryProvider.overrideWithValue(_UsuarioFalso()),
          mensajesRepositoryProvider.overrideWithValue(_MensajesFalsos()),
        ]);
        addTearDown(contenedor.dispose);

        // MobileConnect con conversación larga de ambos dispositivos.
        if (vista.key == 'MobileConnect') {
          final canal = contenedor.read(canalProvider.notifier);
          for (var i = 0; i < 6; i++) {
            canal.enviar('Mensaje número $i con un texto algo largo para ver '
                'cómo se acomoda la burbuja en pantallas angostas');
            canal.cambiarEmisor(canal.state.emisor.otro);
          }
        }

        await tester.pumpWidget(UncontrolledProviderScope(
          container: contenedor,
          child: MaterialApp(home: vista.value()),
        ));
        await tester.pump(); // cargas iniciales (perfil)
        await tester.pump();

        // Si hubo un desborde, Flutter ya habría registrado una excepción.
        // Si hubo un desborde, Flutter ya habría registrado una excepción.
        expect(tester.takeException(), isNull);

        // Salir de la pantalla como en la app: el ProviderScope sigue montado
        // y solo se quita la pantalla. Riverpod destruye los providers
        // autoDispose (Sudoku/Crucigrama) en el siguiente frame y ahí se
        // cancela el Timer; si quedara uno vivo, testWidgets fallaría.
        await tester.pumpWidget(UncontrolledProviderScope(
          container: contenedor,
          child: const MaterialApp(home: SizedBox()),
        ));
        await tester.pump();
      });
    }
  }
}
