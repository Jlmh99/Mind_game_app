// Funciones de formato para mostrar datos en pantalla (sin paquetes extra).

/// Segundos -> "m:ss" (ej. 245 -> "4:05").
String formatoDuracion(int segundos) {
  final min = segundos ~/ 60;
  final seg = segundos % 60;
  return '$min:${seg.toString().padLeft(2, '0')}';
}

/// Fecha -> "dd/mm/aaaa hh:mm" (ej. "05/11/2026 21:30").
String formatoFecha(DateTime f) {
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(f.day)}/${dos(f.month)}/${f.year} ${dos(f.hour)}:${dos(f.minute)}';
}
