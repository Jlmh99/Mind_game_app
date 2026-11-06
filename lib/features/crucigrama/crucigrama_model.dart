// Modelo del Crucigrama: datos del juego y reglas puras (sin Flutter ni Riverpod).
// Las reglas son las mismas de la versión web (referenciaweb/crucigrama/crucigrama.ts).
// Convención del tablero: null = bloque negro, '' = casilla vacía, 'A' = letra.

enum Orientacion { horizontal, vertical }

/// Posición en el tablero: (fila, columna).
typedef Posicion = (int, int);

/// Una palabra del crucigrama con su pista (equivale a "soluciones" en la web).
class PalabraCrucigrama {
  final String palabra;
  final List<Posicion> posiciones;
  final String pista;
  final Orientacion orientacion;

  const PalabraCrucigrama({
    required this.palabra,
    required this.posiciones,
    required this.pista,
    required this.orientacion,
  });

  bool contiene(int fila, int col) => posiciones.contains((fila, col));
}

/// Tablero inicial (el mismo de la web). La 'C' es una letra fija de ayuda.
const List<List<String?>> tableroInicialCrucigrama = [
  ['C', '', '', ''], //  CASA (H) y C de CLIMA
  ['', null, null, null], // L de CLIMA
  ['', '', '', ''], //  IRIS (H) e I de CLIMA
  ['', null, null, null], // M de CLIMA
  ['', null, null, null], // A de CLIMA
];

/// Palabras y pistas (las mismas de la web).
const List<PalabraCrucigrama> palabrasCrucigrama = [
  PalabraCrucigrama(
    palabra: 'CASA',
    posiciones: [(0, 0), (0, 1), (0, 2), (0, 3)],
    pista: 'Lugar donde vives con tu familia.',
    orientacion: Orientacion.horizontal,
  ),
  PalabraCrucigrama(
    palabra: 'CLIMA',
    posiciones: [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)],
    pista: 'Estado del tiempo (calor, frío, lluvia).',
    orientacion: Orientacion.vertical,
  ),
  PalabraCrucigrama(
    palabra: 'IRIS',
    posiciones: [(2, 0), (2, 1), (2, 2), (2, 3)],
    pista: 'Parte coloreada del ojo o arco...',
    orientacion: Orientacion.horizontal,
  ),
];

/// Copia de cada fila para no compartir referencias (igual que generarCopiaTablero()).
List<List<String?>> copiarTableroCrucigrama(List<List<String?>> tablero) =>
    [for (final fila in tablero) [...fila]];

/// Palabras que pasan por la casilla (fila, col).
List<PalabraCrucigrama> palabrasEn(int fila, int col) =>
    palabrasCrucigrama.where((p) => p.contiene(fila, col)).toList();

/// true si la letra escrita en (fila, col) no coincide con la letra esperada
/// en alguna de las palabras que pasan por ahí. Vacía = no es error.
/// (esError en la web)
bool hayError(List<List<String?>> tablero, int fila, int col) {
  final letra = (tablero[fila][col] ?? '').toUpperCase();
  if (letra.isEmpty) return false;

  for (final p in palabrasEn(fila, col)) {
    final indice = p.posiciones.indexOf((fila, col));
    if (letra != p.palabra[indice]) return true;
  }
  return false;
}

/// Lo que el usuario lleva escrito en una palabra, en mayúsculas.
String palabraEscrita(List<List<String?>> tablero, PalabraCrucigrama p) =>
    p.posiciones.map((pos) => tablero[pos.$1][pos.$2] ?? '').join().toUpperCase();

/// true si la palabra escrita es igual a la solución (regla de verificar() en la web).
bool palabraCorrecta(List<List<String?>> tablero, PalabraCrucigrama p) =>
    palabraEscrita(tablero, p) == p.palabra;

/// true si todas las palabras están correctas.
bool crucigramaCompleto(List<List<String?>> tablero) =>
    palabrasCrucigrama.every((p) => palabraCorrecta(tablero, p));

/// Puntuación = max(0, 1000 - segundos - 25 * errores).
int calcularPuntuacionCrucigrama(int segundos, int errores) {
  final puntos = 1000 - segundos - 25 * errores;
  return puntos < 0 ? 0 : puntos;
}

/// Convierte segundos a "m:ss" (igual que formatoTiempo de la web).
String formatoTiempoCrucigrama(int segundos) {
  final min = segundos ~/ 60;
  final seg = segundos % 60;
  return '$min:${seg.toString().padLeft(2, '0')}';
}

/// Estado inmutable de una partida de Crucigrama.
class CrucigramaState {
  final List<List<String?>> tablero;
  final int? filaSel; // casilla seleccionada (null = ninguna)
  final int? colSel;
  final Orientacion orientacion; // dirección en la que se escribe
  final int segundos;
  final int errores;
  final bool terminado;

  const CrucigramaState({
    required this.tablero,
    this.filaSel,
    this.colSel,
    this.orientacion = Orientacion.horizontal,
    this.segundos = 0,
    this.errores = 0,
    this.terminado = false,
  });

  factory CrucigramaState.nuevo() =>
      CrucigramaState(tablero: copiarTableroCrucigrama(tableroInicialCrucigrama));

  int get filas => tablero.length;
  int get columnas => tablero.first.length;

  bool get haySeleccion => filaSel != null && colSel != null;

  bool esBloque(int fila, int col) => tablero[fila][col] == null;

  /// Las letras que ya venían en el tablero inicial no se pueden editar.
  bool esFija(int fila, int col) =>
      (tableroInicialCrucigrama[fila][col] ?? '').isNotEmpty;

  bool esError(int fila, int col) => hayError(tablero, fila, col);

  bool esCorrecta(PalabraCrucigrama p) => palabraCorrecta(tablero, p);

  /// Palabra que se está escribiendo: la que pasa por la casilla
  /// seleccionada en la orientación actual.
  PalabraCrucigrama? get palabraSeleccionada {
    if (!haySeleccion) return null;
    for (final p in palabrasEn(filaSel!, colSel!)) {
      if (p.orientacion == orientacion) return p;
    }
    return null;
  }

  int get puntuacion => calcularPuntuacionCrucigrama(segundos, errores);

  CrucigramaState copyWith({
    List<List<String?>>? tablero,
    int? filaSel,
    int? colSel,
    Orientacion? orientacion,
    int? segundos,
    int? errores,
    bool? terminado,
  }) =>
      CrucigramaState(
        tablero: tablero ?? this.tablero,
        filaSel: filaSel ?? this.filaSel,
        colSel: colSel ?? this.colSel,
        orientacion: orientacion ?? this.orientacion,
        segundos: segundos ?? this.segundos,
        errores: errores ?? this.errores,
        terminado: terminado ?? this.terminado,
      );
}
