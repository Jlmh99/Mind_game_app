import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Límite del backend: 2 MB de imagen ya decodificada.
const int limiteFotoBytes = 2 * 1024 * 1024;

/// La imagen no se pudo reducir por debajo del límite (o no es una imagen).
class FotoNoValidaException implements Exception {
  const FotoNoValidaException();
}

/// Devuelve la foto con menos de 2 MB, comprimiéndola si hace falta.
/// Corre en otro isolate (compute) para no congelar la pantalla.
Future<Uint8List> comprimirFoto(Uint8List original) =>
    compute(comprimirFotoSync, original);

/// Versión síncrona (pública para poder probarla).
///
/// Si ya pesa menos de 2 MB se devuelve igual. Si no, se re-codifica a JPEG
/// en un bucle: primero baja la calidad (85 -> 55) y después el ancho (-20 %
/// cada vuelta) hasta quedar por debajo del límite.
Uint8List comprimirFotoSync(Uint8List original) {
  if (original.length < limiteFotoBytes) return original;

  final decodificada = img.decodeImage(original);
  if (decodificada == null) throw const FotoNoValidaException();
  // Aplica la rotación EXIF para que la foto no quede de lado al re-codificar.
  final imagen = img.bakeOrientation(decodificada);

  var ancho = min(imagen.width, 1080);
  var calidad = 85;

  while (true) {
    final reducida =
        imagen.width > ancho ? img.copyResize(imagen, width: ancho) : imagen;
    final jpg = img.encodeJpg(reducida, quality: calidad);
    if (jpg.length < limiteFotoBytes) return jpg;

    if (calidad > 55) {
      calidad -= 10;
    } else {
      ancho = (ancho * 0.8).round();
      if (ancho < 200) throw const FotoNoValidaException(); // no tiene caso seguir
    }
  }
}
