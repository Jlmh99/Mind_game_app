import 'package:floor/floor.dart';
import 'sesion.dart';

@dao
abstract class SesionDao {
  @Query('SELECT * FROM sesion WHERE id = 1')
  Future<Sesion?> obtener();

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> guardar(Sesion sesion);

  @Query('DELETE FROM sesion')
  Future<void> limpiar();
}
