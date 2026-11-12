import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../perfil/camara.dart'; // reutiliza CamaraDenegadaException
import 'chat_comun.dart';

/// Archivo elegido por el usuario (todavía sin validar).
class ArchivoElegido {
  final String nombre;
  final Uint8List bytes;
  const ArchivoElegido(this.nombre, this.bytes);
}

/// Envoltura de image_picker (imágenes) y file_picker (PDF).
/// Está en su propio provider para poder reemplazarla en las pruebas.
class SelectorArchivos {
  final ImagePicker _picker = ImagePicker();

  /// Imagen de la cámara o la galería. null si el usuario canceló.
  /// Se reduce al tomarla (ancho 1600, calidad 85) para que pese poco.
  Future<ArchivoElegido?> imagen(ImageSource origen) async {
    try {
      final archivo = await _picker.pickImage(source: origen, maxWidth: 1600, imageQuality: 85);
      if (archivo == null) return null;
      return ArchivoElegido(archivo.name, await archivo.readAsBytes());
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied' || e.code == 'photo_access_denied') {
        throw const CamaraDenegadaException();
      }
      rethrow;
    }
  }

  /// Un PDF del almacenamiento. null si el usuario canceló.
  /// Revisa el tamaño ANTES de leerlo para no cargar archivos enormes en memoria.
  Future<ArchivoElegido?> pdf() async {
    final elegidos =
        await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
    if (elegidos.isEmpty) return null;
    final archivo = elegidos.first;
    final tamano = archivo.lengthSync() ?? await archivo.length();
    if (tamano != null && tamano > maxAdjuntoBytes) {
      throw const AdjuntoInvalidoException('El archivo no debe superar 2 MB');
    }
    return ArchivoElegido(archivo.name, await archivo.readAsBytes());
  }
}

final selectorArchivosProvider = Provider<SelectorArchivos>((ref) => SelectorArchivos());
