// Modelo de MobileConnect: dos dispositivos simulados que se mandan mensajes
// dentro de la misma app (sin red ni backend).

/// Los dos dispositivos simulados.
enum Dispositivo {
  a('Dispositivo A', 'A'),
  b('Dispositivo B', 'B');

  final String nombre;
  final String letra;
  const Dispositivo(this.nombre, this.letra);

  /// El otro dispositivo: el que recibe lo que este envía.
  Dispositivo get otro => this == Dispositivo.a ? Dispositivo.b : Dispositivo.a;
}

/// Longitud máxima de un mensaje (evita textos desmedidos).
const int maxLongitudMensaje = 500;

/// Un mensaje de la conversación.
class Mensaje {
  final Dispositivo emisor;
  final String texto;
  final DateTime hora; // hora de envío

  const Mensaje({required this.emisor, required this.texto, required this.hora});

  Dispositivo get receptor => emisor.otro;

  /// Hora de envío en formato HH:mm (ej. "09:05").
  String get horaTexto =>
      '${hora.hour.toString().padLeft(2, '0')}:'
      '${hora.minute.toString().padLeft(2, '0')}';
}

/// Estado del canal: el historial y quién está enviando.
class CanalState {
  final List<Mensaje> mensajes; // en orden de envío (el último al final)
  final Dispositivo emisor; // dispositivo elegido en el selector

  const CanalState({this.mensajes = const [], this.emisor = Dispositivo.a});

  /// Cuántos mensajes ha enviado [d] (se calcula del historial).
  int enviadosPor(Dispositivo d) => mensajes.where((m) => m.emisor == d).length;

  CanalState copyWith({List<Mensaje>? mensajes, Dispositivo? emisor}) =>
      CanalState(
        mensajes: mensajes ?? this.mensajes,
        emisor: emisor ?? this.emisor,
      );
}
