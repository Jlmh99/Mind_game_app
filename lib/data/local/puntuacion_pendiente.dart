import 'package:floor/floor.dart';

/// Puntuación que no se pudo enviar al servidor (sin red o error 5xx) y
/// espera en el teléfono para reenviarse al reconectar (Práctica 14).
///
/// Es por usuario (correo): cada quien solo reenvía las suyas. No se borra al
/// cerrar sesión; se envía la próxima vez que ese usuario tenga sesión y red.
@Entity(tableName: 'puntuacion_pendiente')
class PuntuacionPendiente {
  @PrimaryKey(autoGenerate: true)
  final int? id;
  final String correo;
  final String juego; // 'SUDOKU' o 'CRUCIGRAMA'
  final int tiempoSegundos;
  final int puntuacion;
  final int creadoEn; // epoch en milisegundos: orden de envío
  final int intentos; // reenvíos fallidos (solo informativo)

  const PuntuacionPendiente({
    this.id,
    required this.correo,
    required this.juego,
    required this.tiempoSegundos,
    required this.puntuacion,
    required this.creadoEn,
    this.intentos = 0,
  });
}
