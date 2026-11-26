import 'package:floor/floor.dart';
import 'partida_en_curso.dart';

@dao
abstract class PartidaEnCursoDao {
  @Query('SELECT * FROM partida_en_curso WHERE correo = :correo AND juego = :juego')
  Future<PartidaEnCurso?> obtener(String correo, String juego);

  /// Inserta o reemplaza la partida de ese (correo, juego).
  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> guardar(PartidaEnCurso partida);

  @Query('DELETE FROM partida_en_curso WHERE correo = :correo AND juego = :juego')
  Future<void> borrar(String correo, String juego);

  @Query('DELETE FROM partida_en_curso WHERE correo = :correo')
  Future<void> borrarTodasDe(String correo);
}
