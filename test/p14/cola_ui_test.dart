// Práctica 14: interfaz de la cola offline y tope del Crucigrama.
//  - SnackBar del caso "pendiente".
//  - Estado del guardado DENTRO del diálogo de victoria (el diálogo es modal y
//    su barrera queda encima del SnackBar: hallazgo de P12).
//  - Contador de pendientes en "Mi perfil".
//  - calcularPuntuacionCrucigrama acotada entre 0 y 1000 (como el Sudoku).
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/core/api_client.dart';
import 'package:mindgames_app/data/foto_perfil_repository.dart';
import 'package:mindgames_app/data/partidas_repository.dart';
import 'package:mindgames_app/features/auth/auth_controller.dart';
import 'package:mindgames_app/features/crucigrama/crucigrama_model.dart';
import 'package:mindgames_app/features/partidas/cola_puntuaciones.dart';
import 'package:mindgames_app/features/partidas/guardar_partida.dart';
import 'package:mindgames_app/features/partidas/partidas_controller.dart';
import 'package:mindgames_app/features/perfil/perfil_page.dart';
import 'apoyo_p14.dart';

/// PartidasController que responde siempre [resultado] al guardar.
class _PartidasQueResponde extends PartidasController {
  _PartidasQueResponde(this.resultado);
  final ResultadoGuardado resultado;

  @override
  Future<ResultadoGuardado> guardar({
    required String juego,
    required int tiempoSegundos,
    required int puntuacion,
  }) async =>
      resultado;
}

/// Cola falsa con un número fijo de pendientes.
class _ColaCon extends ColaPuntuacionesController {
  _ColaCon(this.n);
  final int n;
  @override
  int build() => n;
  @override
  Future<void> refrescarConteo() async {}
}

class _PartidasSinNada implements PartidasRepository {
  @override
  ApiClient get api => throw UnimplementedError();
  @override
  Future<Partida> guardar({required String juego, required int tiempoSegundos, required int puntuacion}) =>
      throw UnimplementedError();
  @override
  Future<List<Partida>> misPartidas() async => [];
}

class _SinFoto implements FotoPerfilRepository {
  @override
  ApiClient get api => throw UnimplementedError();
  @override
  Future<Uint8List?> obtener() async => null;
  @override
  Future<void> subir(Uint8List bytes) async {}
}

void main() {
  group('P14 UI cola', () {
    testWidgets('P14-UI: resultado "pendiente" -> SnackBar con el aviso de la cola offline', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => AuthFalso('a@ejemplo.com')),
          partidasControllerProvider.overrideWith(() => _PartidasQueResponde(ResultadoGuardado.pendiente)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () =>
                    guardarPartidaYAvisar(context, ref, juego: 'SUDOKU', tiempoSegundos: 10, puntuacion: 990),
                child: const Text('guardar'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('guardar'));
      await tester.pump();
      await tester.pump();
      expect(find.text(mensajePuntuacionPendiente), findsOneWidget);
      expect(mensajePuntuacionPendiente,
          'Sin conexión: tu puntuación se guardó en el teléfono y se enviará al reconectar');
    });

    testWidgets('P14-UI: el estado del guardado se ve DENTRO del diálogo de victoria (no tapado por la barrera)',
        (tester) async {
      for (final (resultado, texto) in [
        (ResultadoGuardado.pendiente, 'Sin conexión: se enviará al reconectar'),
        (ResultadoGuardado.guardada, 'Puntuación guardada'),
        (ResultadoGuardado.fallo, 'No se pudo guardar la puntuación'),
      ]) {
        await tester.pumpWidget(const SizedBox()); // desmonta el diálogo de la vuelta anterior
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('¡Sudoku completado!'),
                  content: EstadoGuardadoPartida(guardado: Future.value(resultado)),
                ),
              ),
              child: const Text('ganar'),
            ),
          ),
        ));
        await tester.tap(find.text('ganar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final enDialogo = find.descendant(of: find.byType(AlertDialog), matching: find.text(texto));
        expect(enDialogo, findsOneWidget, reason: '$resultado');
        expect(enDialogo.hitTestable(), findsOneWidget, reason: 'visible y por encima de la barrera');
      }
    });

    testWidgets('P14-UI: "Mi perfil" muestra cuántas puntuaciones faltan por enviar', (tester) async {
      Future<void> montar(int pendientes) async {
        // Un ProviderScope ya montado conserva sus overrides: se desmonta antes.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => AuthFalso('a@ejemplo.com')),
            partidasRepositoryProvider.overrideWithValue(_PartidasSinNada()),
            fotoPerfilRepositoryProvider.overrideWithValue(_SinFoto()),
            colaPuntuacionesProvider.overrideWith(() => _ColaCon(pendientes)),
          ],
          child: const MaterialApp(home: PerfilPage()),
        ));
        await tester.pump();
        await tester.pump();
      }

      await montar(3);
      expect(find.text('3 puntuaciones pendientes de enviar'), findsOneWidget);
      expect(find.text('Se enviarán automáticamente al reconectar.'), findsOneWidget);

      await montar(1);
      expect(find.text('1 puntuación pendiente de enviar'), findsOneWidget);

      await montar(0);
      expect(find.textContaining('pendiente'), findsNothing);
    });
  });

  group('P14 Crucigrama: puntuación acotada', () {
    test('P14-CRU: calcularPuntuacionCrucigrama queda entre 0 y 1000', () {
      expect(calcularPuntuacionCrucigrama(0, 0), 1000);
      expect(calcularPuntuacionCrucigrama(60, 4), 840);
      expect(calcularPuntuacionCrucigrama(990, 1), 0);
      expect(calcularPuntuacionCrucigrama(-5, 0), 1000, reason: 'antes daba 1005');
      expect(calcularPuntuacionCrucigrama(0, -4), 1000, reason: 'antes daba 1100');
      expect(calcularPuntuacionCrucigrama(1 << 40, 0), 0);
    });
  });
}
