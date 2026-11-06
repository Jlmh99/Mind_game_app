import 'package:floor/floor.dart';

@Entity(tableName: 'sesion')
class Sesion {
  @PrimaryKey()
  final int id; // siempre 1: solo hay una sesión activa
  final String correo;
  final String token;
  final String rol;

  Sesion({this.id = 1, required this.correo, required this.token, this.rol = 'USER'});
}
