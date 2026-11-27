// Modelo del Sudoku: datos del juego y reglas puras (sin Flutter ni Riverpod).
// Las reglas son las mismas de la versión web (referenciaweb/sudoku/sudoku.ts).
// Convención: el 0 representa una celda vacía.

/// Tableros predefinidos (los mismos de la versión web).
const List<List<List<int>>> tablerosSudoku = [
  [
    [5, 3, 0, 0, 7, 0, 0, 0, 0],
    [6, 0, 0, 1, 9, 5, 0, 0, 0],
    [0, 9, 8, 0, 0, 0, 0, 6, 0],
    [8, 0, 0, 0, 6, 0, 0, 0, 3],
    [4, 0, 0, 8, 0, 3, 0, 0, 1],
    [7, 0, 0, 0, 2, 0, 0, 0, 6],
    [0, 6, 0, 0, 0, 0, 2, 8, 0],
    [0, 0, 0, 4, 1, 9, 0, 0, 5],
    [0, 0, 0, 0, 8, 0, 0, 7, 9],
  ],
  [
    [0, 0, 0, 2, 6, 0, 7, 0, 1],
    [6, 8, 0, 0, 7, 0, 0, 9, 0],
    [1, 9, 0, 0, 0, 4, 5, 0, 0],
    [8, 2, 0, 1, 0, 0, 0, 4, 0],
    [0, 0, 4, 6, 0, 2, 9, 0, 0],
    [0, 5, 0, 0, 0, 3, 0, 2, 8],
    [0, 0, 9, 3, 0, 0, 0, 7, 4],
    [0, 4, 0, 0, 5, 0, 0, 3, 6],
    [7, 0, 3, 0, 1, 8, 0, 0, 0],
  ],
];

/// Copia profunda de un tablero (equivale al JSON.parse(JSON.stringify()) de la web).
List<List<int>> copiarTablero(List<List<int>> tablero) =>
    [for (final fila in tablero) [...fila]];

/// true si el número en (fila, col) se repite en su fila, su columna
/// o su bloque 3x3. Una celda vacía nunca es conflicto. (esError en la web)
bool hayConflicto(List<List<int>> tablero, int fila, int col) {
  final valor = tablero[fila][col];
  if (valor == 0) return false;

  // Fila
  for (var x = 0; x < 9; x++) {
    if (x != col && tablero[fila][x] == valor) return true;
  }

  // Columna
  for (var x = 0; x < 9; x++) {
    if (x != fila && tablero[x][col] == valor) return true;
  }

  // Bloque 3x3
  final filaInicio = (fila ~/ 3) * 3;
  final colInicio = (col ~/ 3) * 3;
  for (var f = filaInicio; f < filaInicio + 3; f++) {
    for (var c = colInicio; c < colInicio + 3; c++) {
      if ((f != fila || c != col) && tablero[f][c] == valor) return true;
    }
  }

  return false;
}

/// true si no quedan celdas vacías y ningún número tiene conflicto.
/// (equivale a verificar() de la web cuando muestra "¡Correcto!")
bool estaCompleto(List<List<int>> tablero) {
  for (var f = 0; f < 9; f++) {
    for (var c = 0; c < 9; c++) {
      if (tablero[f][c] == 0 || hayConflicto(tablero, f, c)) return false;
    }
  }
  return true;
}

/// Puntuación = 1000 - segundos - 50 * errores, acotada entre 0 y 1000
/// (con tiempo o errores negativos nunca supera la partida perfecta).
int calcularPuntuacion(int segundos, int errores) {
  final puntos = 1000 - segundos - 50 * errores;
  return puntos.clamp(0, 1000);
}

/// Convierte segundos a "m:ss" (igual que formatoTiempo() de la web).
String formatoTiempo(int segundos) {
  final min = segundos ~/ 60;
  final seg = segundos % 60;
  return '$min:${seg.toString().padLeft(2, '0')}';
}

/// Estado inmutable de una partida de Sudoku.
class SudokuState {
  final int indiceTablero; // cuál de tablerosSudoku se está jugando
  final List<List<int>> inicial; // números fijos (no editables)
  final List<List<int>> tablero; // estado actual con lo que escribe el usuario
  final int? filaSel; // celda seleccionada (null = ninguna)
  final int? colSel;
  final int segundos;
  final int errores;
  final bool terminado;

  const SudokuState({
    required this.indiceTablero,
    required this.inicial,
    required this.tablero,
    this.filaSel,
    this.colSel,
    this.segundos = 0,
    this.errores = 0,
    this.terminado = false,
  });

  /// Partida nueva a partir de uno de los tableros predefinidos.
  factory SudokuState.nuevo(int indice) {
    final base = copiarTablero(tablerosSudoku[indice]);
    return SudokuState(
      indiceTablero: indice,
      inicial: base,
      tablero: copiarTablero(base),
    );
  }

  // ---------------- Persistencia (partida en curso) ----------------

  /// Datos para guardar la partida en curso. NO incluye el tablero inicial:
  /// se reconstruye con tablerosSudoku[indiceTablero]. Tampoco "terminado":
  /// una partida terminada no se guarda.
  Map<String, dynamic> toJson() => {
        'indiceTablero': indiceTablero,
        'tablero': tablero,
        'filaSel': filaSel,
        'colSel': colSel,
        'segundos': segundos,
        'errores': errores,
      };

  /// Reconstruye una partida guardada. Lanza FormatException si los datos no
  /// cuadran (índice inexistente, tablero que no es 9x9, valores fuera de
  /// 0-9 o números fijos cambiados), para descartar una partida corrupta.
  factory SudokuState.fromJson(Map<String, dynamic> j) {
    final indice = j['indiceTablero'];
    if (indice is! int || indice < 0 || indice >= tablerosSudoku.length) {
      throw const FormatException('indiceTablero inválido');
    }
    final base = copiarTablero(tablerosSudoku[indice]);
    final filas = j['tablero'];
    if (filas is! List || filas.length != 9) {
      throw const FormatException('tablero inválido');
    }
    final tablero = <List<int>>[];
    for (var f = 0; f < 9; f++) {
      final fila = filas[f];
      if (fila is! List || fila.length != 9) {
        throw const FormatException('tablero inválido');
      }
      tablero.add([
        for (var c = 0; c < 9; c++)
          if (fila[c] is int && fila[c] >= 0 && fila[c] <= 9 &&
              (base[f][c] == 0 || fila[c] == base[f][c]))
            fila[c] as int
          else
            throw const FormatException('celda inválida'),
      ]);
    }
    int? posicion(Object? v) => v is int && v >= 0 && v < 9 ? v : null;
    final segundos = j['segundos'], errores = j['errores'];
    return SudokuState(
      indiceTablero: indice,
      inicial: base,
      tablero: tablero,
      filaSel: posicion(j['filaSel']),
      colSel: posicion(j['colSel']),
      segundos: segundos is int && segundos >= 0 ? segundos : 0,
      errores: errores is int && errores >= 0 ? errores : 0,
    );
  }

  bool get haySeleccion => filaSel != null && colSel != null;

  /// Número de la celda seleccionada (0 si está vacía o no hay selección).
  int get valorSeleccionado =>
      haySeleccion ? tablero[filaSel!][colSel!] : 0;

  int get puntuacion => calcularPuntuacion(segundos, errores);

  bool esFija(int fila, int col) => inicial[fila][col] != 0;

  bool esConflicto(int fila, int col) => hayConflicto(tablero, fila, col);

  SudokuState copyWith({
    List<List<int>>? tablero,
    int? filaSel,
    int? colSel,
    int? segundos,
    int? errores,
    bool? terminado,
  }) =>
      SudokuState(
        indiceTablero: indiceTablero,
        inicial: inicial,
        tablero: tablero ?? this.tablero,
        filaSel: filaSel ?? this.filaSel,
        colSel: colSel ?? this.colSel,
        segundos: segundos ?? this.segundos,
        errores: errores ?? this.errores,
        terminado: terminado ?? this.terminado,
      );
}
