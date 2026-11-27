// Práctica 14 (T6): la app queda bloqueada en vertical.
//  - bloquearVertical() pide a la plataforma solo DeviceOrientation.portraitUp.
//  - main() la llama antes de runApp.
//  - AndroidManifest.xml (principal) declara screenOrientation="portrait".
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgames_app/core/orientacion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('P14-ORIENT: bloquearVertical() pide a SystemChrome solo portraitUp', () async {
    final llamadas = <MethodCall>[];
    final mensajero = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    mensajero.setMockMethodCallHandler(SystemChannels.platform, (llamada) async {
      llamadas.add(llamada);
      return null;
    });
    addTearDown(() => mensajero.setMockMethodCallHandler(SystemChannels.platform, null));

    await bloquearVertical();

    final orientacion = llamadas.where((c) => c.method == 'SystemChrome.setPreferredOrientations').toList();
    expect(orientacion, hasLength(1));
    expect(orientacion.single.arguments, ['DeviceOrientation.portraitUp']);
  });

  test('P14-ORIENT: main() llama a bloquearVertical() antes de runApp', () {
    final main = File('lib/main.dart').readAsStringSync();
    final bloqueo = main.indexOf('await bloquearVertical()');
    expect(bloqueo, isNonNegative, reason: 'main.dart debe llamar a bloquearVertical()');
    expect(bloqueo, lessThan(main.indexOf('runApp(')), reason: 'antes de runApp');
  });

  test('P14-ORIENT: el AndroidManifest principal declara screenOrientation="portrait"', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:screenOrientation="portrait"'));
  });
}
