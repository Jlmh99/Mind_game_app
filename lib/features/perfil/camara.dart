import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// El usuario negó el permiso de cámara.
class CamaraDenegadaException implements Exception {
  const CamaraDenegadaException();
}

/// Envoltura de image_picker para tomar la foto de perfil.
/// Está en su propia clase (y provider) para poder reemplazarla en las pruebas.
class Camara {
  final ImagePicker _picker = ImagePicker();

  /// Primera compresión al tomar la foto: así casi siempre queda muy por
  /// debajo de 2 MB. Si no, compresor_foto.dart sigue reduciéndola.
  static const double anchoMaximo = 1080;
  static const int calidad = 85;

  /// Abre la cámara (ImageSource.camera). Devuelve los bytes de la foto,
  /// o null si el usuario canceló sin tomarla.
  ///
  /// image_picker pide el permiso CAMERA (declarado en AndroidManifest);
  /// si el usuario lo niega lanza PlatformException 'camera_access_denied',
  /// que aquí convertimos en CamaraDenegadaException.
  Future<Uint8List?> tomarFoto() async {
    try {
      final archivo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front, // selfie para el perfil
        maxWidth: anchoMaximo,
        imageQuality: calidad,
      );
      return archivo == null ? null : await archivo.readAsBytes();
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') throw const CamaraDenegadaException();
      rethrow;
    }
  }
}

final camaraProvider = Provider<Camara>((ref) => Camara());
