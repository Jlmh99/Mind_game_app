import 'package:flutter/services.dart';

/// La app está diseñada solo en vertical (Práctica 14, T6): se bloquea la
/// orientación para que girar el teléfono no cambie la pantalla.
/// Se llama en main() antes de runApp. Además, AndroidManifest.xml declara
/// android:screenOrientation="portrait" en la actividad, así Android tampoco
/// la gira mientras arranca.
Future<void> bloquearVertical() =>
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
