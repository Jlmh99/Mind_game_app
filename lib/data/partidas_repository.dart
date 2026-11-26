import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/errores_api.dart';
import '../core/formato.dart';
import '../core/providers.dart';
import '../core/sesion_expirada_exception.dart';

/// Nombres de juego que acepta el backend (PartidaController).
const String juegoSudoku = 'SUDOKU';
const String juegoCrucigrama = 'CRUCIGRAMA';

/// Partida guardada en el servidor (lo que devuelve /api/partidas).
class Partida {
  final int id;
  final String juego;
  final int tiempoSegundos;
  final int puntuacion;
  final DateTime fecha;

  const Partida({
    required this.id,
    required this.juego,
    required this.tiempoSegundos,
    required this.puntuacion,
    required this.fecha,
  });

  /// Convierte el JSON del servidor. La fecha llega como "2026-11-05T21:30:12.123"
  /// (LocalDateTime de Java, sin zona horaria).
  factory Partida.fromJson(Map<String, dynamic> json) => Partida(
        id: (json['id'] as num).toInt(),
        juego: json['juego'] as String,
        tiempoSegundos: (json['tiempoSegundos'] as num).toInt(),
        puntuacion: (json['puntuacion'] as num).toInt(),
        fecha: fechaDelServidor(json['fecha'] as String), // UTC (ver formato.dart)
      );
}

/// Acceso a las partidas del usuario en el backend.
/// Todo el HTTP y el token lo resuelve ApiClient (autenticado: true);
/// aquí solo se arma el cuerpo y se interpreta la respuesta.
/// Puede lanzar SesionExpiradaException (401/403 o sin token).
class PartidasRepository {
  final ApiClient api;
  PartidasRepository(this.api);

  /// POST /api/partidas. Devuelve la partida tal como quedó guardada.
  Future<Partida> guardar({
    required String juego,
    required int tiempoSegundos,
    required int puntuacion,
  }) async {
    final r = await api.post(
      rutaPartidas,
      {
        'juego': juego,
        'tiempoSegundos': tiempoSegundos,
        'puntuacion': puntuacion,
      },
      autenticado: true,
    );
    if (r is Map<String, dynamic> && r['id'] != null) return Partida.fromJson(r);
    throw Exception('Respuesta inesperada del servidor');
  }

  /// GET /api/partidas/me. Partidas del usuario, de la más reciente a la más antigua.
  Future<List<Partida>> misPartidas() async {
    final r = await api.get(rutaMisPartidas, autenticado: true);
    if (r is List) {
      return [for (final item in r) Partida.fromJson(item as Map<String, dynamic>)];
    }
    throw Exception('Respuesta inesperada del servidor');
  }
}

/// Provider del repositorio de partidas (reutiliza el ApiClient compartido).
final partidasRepositoryProvider = Provider<PartidasRepository>(
  (ref) => PartidasRepository(ref.watch(apiClientProvider)),
);

// ---------------------------------------------------------------------------
// Cola offline (Práctica 14): qué hacer cuando guardar() falla.
// ---------------------------------------------------------------------------

/// Tipo de fallo al enviar una partida:
///  - red:       sin conexión, timeout o conexión cortada -> se encola.
///  - servidor:  HTTP 5xx -> se encola (el servidor puede volver).
///  - sesion:    401/403 de sesión -> se cierra la sesión; la cola NO se borra.
///  - rechazada: 400, 422, otros 4xx, 403 de permiso o respuesta inesperada:
///               reintentar no la arreglaría -> no se encola.
enum FalloGuardado { red, servidor, sesion, rechazada }

FalloGuardado clasificarFalloGuardado(Object e) {
  if (e is SesionExpiradaException) return FalloGuardado.sesion;
  if (e is SocketException ||
      e is http.ClientException ||
      e is TimeoutException ||
      e is HandshakeException) {
    return FalloGuardado.red;
  }
  if (e is ErrorHttpException && e.codigo >= 500) return FalloGuardado.servidor;
  return FalloGuardado.rechazada;
}

/// true si el fallo es temporal y vale la pena guardar la puntuación para
/// reenviarla después.
bool seDebeEncolar(FalloGuardado f) => f == FalloGuardado.red || f == FalloGuardado.servidor;
