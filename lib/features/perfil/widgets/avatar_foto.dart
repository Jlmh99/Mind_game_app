import 'package:flutter/material.dart';
import '../foto_perfil_controller.dart';

/// Avatar redondo con la foto de perfil (o un icono por defecto),
/// un indicador de carga encima y el botón de cámara en la esquina.
class AvatarFoto extends StatelessWidget {
  final FotoPerfilState estado;
  final VoidCallback onTomarFoto;
  final double radio;

  const AvatarFoto({
    super.key,
    required this.estado,
    required this.onTomarFoto,
    this.radio = 48,
  });

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final lado = radio * 2;

    return SizedBox(
      width: lado + 8,
      height: lado + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Foto o avatar por defecto.
          ClipOval(
            child: SizedBox.square(
              dimension: lado,
              child: estado.foto != null
                  ? Image.memory(
                      estado.foto!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true, // sin parpadeo al cambiar de foto
                      // Si los bytes estuvieran dañados, se muestra el avatar por defecto.
                      errorBuilder: (_, _, _) => _porDefecto(colores),
                    )
                  : _porDefecto(colores),
            ),
          ),

          // Capa semitransparente con spinner mientras carga o sube.
          if (estado.ocupado)
            ClipOval(
              child: Container(
                width: lado,
                height: lado,
                color: Colors.black38,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // Botón de cámara en la esquina inferior derecha.
          Positioned(
            right: 0,
            bottom: 0,
            child: IconButton.filled(
              tooltip: 'Tomar foto',
              icon: const Icon(Icons.photo_camera),
              onPressed: estado.ocupado ? null : onTomarFoto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _porDefecto(ColorScheme colores) => Container(
        color: colores.primary,
        alignment: Alignment.center,
        child: Icon(Icons.person, size: radio, color: colores.onPrimary),
      );
}
