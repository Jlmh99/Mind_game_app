// Funciones de formato para mostrar datos en pantalla (sin paquetes extra).

/// Segundos -> "m:ss" (ej. 245 -> "4:05").
String formatoDuracion(int segundos) {
  final min = segundos ~/ 60;
  final seg = segundos % 60;
  return '$min:${seg.toString().padLeft(2, '0')}';
}

/// Hora -> "hh:mm:ss" (ej. "09:05:07"), para "última actualización".
/// Se muestra en la hora del teléfono (toLocal: no cambia una fecha ya local).
String formatoHora(DateTime f) {
  final l = f.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(l.hour)}:${dos(l.minute)}:${dos(l.second)}';
}

/// Fecha -> "dd/mm/aaaa hh:mm" (ej. "05/11/2026 21:30"), en la hora del teléfono.
String formatoFecha(DateTime f) {
  final l = f.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(l.day)}/${dos(l.month)}/${l.year} ${dos(l.hour)}:${dos(l.minute)}';
}

/// Zona al final de un texto ISO-8601 con hora: "Z", "+hh:mm", "-hhmm" o "+hh"
/// (se exige la "T" de la hora para no confundir el "-26" de "2026-11-26").
final RegExp _conZona = RegExp(r'T.*(Z|[+-]\d{2}(:?\d{2})?)$', caseSensitive: false);

/// Convierte una fecha que manda el backend a DateTime en UTC.
///
/// El backend guarda LocalDateTime.now() y en Render la JVM corre en UTC, así
/// que manda la hora UTC SIN zona ("2026-11-26T17:15:42.123456"). DateTime.parse
/// la tomaría como hora local del teléfono (6 h de diferencia en México). Por eso:
///  - sin zona  -> se interpreta como UTC,
///  - con zona  -> se respeta y se pasa a UTC.
/// Para mostrarla se usa formatoFecha / formatoHora, que la pasan a hora local.
/// Limitación: con el backend LOCAL (JVM en hora de México) las fechas sin zona
/// son hora de México y se verían 6 h atrasadas.
DateTime fechaDelServidor(String texto) {
  final t = texto.trim();
  return _conZona.hasMatch(t) ? DateTime.parse(t).toUtc() : DateTime.parse('${t}Z');
}
