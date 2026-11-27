import 'package:floor/floor.dart';

/// Partida de Sudoku o Crucigrama sin terminar, guardada en el teléfono para
/// poder retomarla si la app se cierra o se pierde la conexión (Práctica 14).
///
/// Hay como máximo una por usuario y juego: la clave es (correo, juego).
/// No se borra al cerrar sesión: al volver a entrar con el mismo correo,
/// el usuario puede continuarla.
@Entity(tableName: 'partida_en_curso', primaryKeys: ['correo', 'juego'])
class PartidaEnCurso {
  final String correo;
  final String juego; // 'SUDOKU' o 'CRUCIGRAMA' (juegoSudoku / juegoCrucigrama)
  final String estadoJson; // SudokuState.toJson() o CrucigramaState.toJson()
  final int segundos;
  final int errores;
  final int actualizadoEn; // epoch en milisegundos

  const PartidaEnCurso({
    required this.correo,
    required this.juego,
    required this.estadoJson,
    required this.segundos,
    required this.errores,
    required this.actualizadoEn,
  });
}
