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
import 'package:mindgames_app/features/sudoku/sudoku_page.dart';

// Revisión final: cada pantalla se dibuja en celulares verticales pequeños,
// con teclado abierto y con texto agrandado. Si algo se desborda
// ("RenderFlex overflowed..."), Flutter reporta un error y la prueba falla.

class _AuthFalso extends AuthController {
  @override
  AuthState build() => const AuthState(
        status: AuthStatus.autenticado,
        correo: 'un.correo.bastante.largo.para.probar@universidad.edu.mx',
        rol: 'USER',
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
