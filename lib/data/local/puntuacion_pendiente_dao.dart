import 'package:floor/floor.dart';
import 'puntuacion_pendiente.dart';

@dao
abstract class PuntuacionPendienteDao {
  /// Devuelve el id asignado.
  @insert
  Future<int> insertar(PuntuacionPendiente pendiente);

  /// Pendientes del usuario, de la más antigua a la más nueva (orden de envío).
  @Query('SELECT * FROM puntuacion_pendiente WHERE correo = :correo ORDER BY creadoEn ASC, id ASC')
  Future<List<PuntuacionPendiente>> pendientesDe(String correo);

  @Query('DELETE FROM puntuacion_pendiente WHERE id = :id')
  Future<void> borrar(int id);

  @Query('SELECT COUNT(*) FROM puntuacion_pendiente WHERE correo = :correo')
  Future<int?> contar(String correo);

  /// Suma un reenvío fallido (informativo; no cambia el orden).
  @Query('UPDATE puntuacion_pendiente SET intentos = intentos + 1 WHERE id = :id')
  Future<void> sumarIntento(int id);
}
