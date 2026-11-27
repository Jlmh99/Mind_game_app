import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/formato.dart';
import '../core/providers.dart';

// ---------------------------------------------------------------------------
// Modelos (mismos nombres y valores que el backend)
// ---------------------------------------------------------------------------

enum EstadoIncidencia { pendiente, enProceso, resuelta }

enum PrioridadIncidencia { baja, media, alta, critica }

/// Conversión enum <-> texto del backend ("EN_PROCESO", "CRITICA"...).
const _estadoApi = {
  EstadoIncidencia.pendiente: 'PENDIENTE',
  EstadoIncidencia.enProceso: 'EN_PROCESO',
  EstadoIncidencia.resuelta: 'RESUELTA',
};
const _prioridadApi = {
  PrioridadIncidencia.baja: 'BAJA',
  PrioridadIncidencia.media: 'MEDIA',
  PrioridadIncidencia.alta: 'ALTA',
  PrioridadIncidencia.critica: 'CRITICA',
};

String estadoAApi(EstadoIncidencia e) => _estadoApi[e]!;
String prioridadAApi(PrioridadIncidencia p) => _prioridadApi[p]!;

EstadoIncidencia estadoDesdeApi(String? s) => _estadoApi.entries
    .firstWhere((e) => e.value == s, orElse: () => _estadoApi.entries.first)
    .key;
PrioridadIncidencia prioridadDesdeApi(String? s) => _prioridadApi.entries
    .firstWhere((e) => e.value == s,
        orElse: () => const MapEntry(PrioridadIncidencia.media, 'MEDIA'))
    .key;

/// Datos públicos de un usuario (creador, agente asignado o agente disponible).
class UsuarioResumen {
  final int id;
  final String username;
  final String email;
  final String? rol;

  const UsuarioResumen(
      {required this.id, required this.username, required this.email, this.rol});

  factory UsuarioResumen.fromJson(Map<String, dynamic> j) => UsuarioResumen(
        id: (j['id'] as num).toInt(),
        username: (j['username'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        rol: j['rol']?.toString(),
      );

  static UsuarioResumen? opcional(dynamic j) =>
      j is Map<String, dynamic> ? UsuarioResumen.fromJson(j) : null;
}

/// Incidencia tal como la devuelve /api/incidencias.
/// [version] se reenvía al editar para detectar cambios desde otro dispositivo.
class Incidencia {
  final int id;
  final String titulo;
  final String descripcion;
  final EstadoIncidencia estado;
  final PrioridadIncidencia prioridad;
  final UsuarioResumen? creadoPor;
  final UsuarioResumen? asignadoA;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;
  final int version;

  const Incidencia({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.estado,
    required this.prioridad,
    required this.creadoPor,
    required this.asignadoA,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    required this.version,
  });

  factory Incidencia.fromJson(Map<String, dynamic> j) => Incidencia(
        id: (j['id'] as num).toInt(),
        titulo: (j['titulo'] ?? '').toString(),
        descripcion: (j['descripcion'] ?? '').toString(),
        estado: estadoDesdeApi(j['estado']?.toString()),
        prioridad: prioridadDesdeApi(j['prioridad']?.toString()),
        creadoPor: UsuarioResumen.opcional(j['creadoPor']),
        asignadoA: UsuarioResumen.opcional(j['asignadoA']),
        // UTC (el backend manda la hora sin zona; ver fechaDelServidor).
        fechaCreacion: fechaDelServidor(j['fechaCreacion'] as String),
        fechaActualizacion: fechaDelServidor(j['fechaActualizacion'] as String),
        version: (j['version'] as num).toInt(),
      );
}

// ---------------------------------------------------------------------------
// Repositorio
// ---------------------------------------------------------------------------

/// Acceso a /api/incidencias. Todo el HTTP y el token los resuelve ApiClient
/// (autenticado: true). Puede lanzar:
///  - SesionExpiradaException (token vencido o sin token),
///  - PermisoDenegadoException (403 del backend por permisos),
///  - ErrorHttpException (409 conflicto de versión, 404, etc.).
class IncidenciasRepository {
  final ApiClient api;
  IncidenciasRepository(this.api);

  /// El backend ya filtra por rol: USER las suyas, AGENTE las asignadas, ADMIN todas.
  Future<List<Incidencia>> listar() async {
    final r = await api.get(rutaIncidencias, autenticado: true);
    if (r is List) {
      return [for (final j in r) Incidencia.fromJson(j as Map<String, dynamic>)];
    }
    throw Exception('Respuesta inesperada del servidor');
  }

  Future<Incidencia> obtener(int id) async =>
      _incidencia(await api.get('$rutaIncidencias/$id', autenticado: true));

  Future<Incidencia> crear({
    required String titulo,
    required String descripcion,
    required PrioridadIncidencia prioridad,
  }) async =>
      _incidencia(await api.post(
        rutaIncidencias,
        {
          'titulo': titulo,
          'descripcion': descripcion,
          'prioridad': prioridadAApi(prioridad),
        },
        autenticado: true,
      ));

  /// Solo se envían los campos que cambian, más la [version] leída.
  Future<Incidencia> actualizar(
    int id, {
    required int version,
    String? titulo,
    String? descripcion,
    EstadoIncidencia? estado,
    PrioridadIncidencia? prioridad,
  }) async =>
      _incidencia(await api.put(
        '$rutaIncidencias/$id',
        {
          'version': version,
          // La clave solo se incluye si el valor no es null. (Antes se usaba
          // "'clave': ?valor", pero floor_generator 1.5.0 no entiende esa
          // sintaxis de Dart 3.8 y build_runner fallaba; por eso se ignora
          // aquí la regla use_null_aware_elements, que pide justo esa sintaxis.)
          // ignore: use_null_aware_elements
          if (titulo != null) 'titulo': titulo,
          // ignore: use_null_aware_elements
          if (descripcion != null) 'descripcion': descripcion,
          if (estado != null) 'estado': estadoAApi(estado),
          if (prioridad != null) 'prioridad': prioridadAApi(prioridad),
        },
        autenticado: true,
      ));

  Future<Incidencia> asignar(int id, int agenteId) async => _incidencia(await api.put(
        '$rutaIncidencias/$id/asignar',
        {'agenteId': agenteId},
        autenticado: true,
      ));

  Future<void> eliminar(int id) =>
      api.delete('$rutaIncidencias/$id', autenticado: true);

  /// Solo ADMIN (el backend responde 403 a los demás).
  Future<List<UsuarioResumen>> agentes() async {
    final r = await api.get(rutaAgentes, autenticado: true);
    if (r is List) {
      return [for (final j in r) UsuarioResumen.fromJson(j as Map<String, dynamic>)];
    }
    throw Exception('Respuesta inesperada del servidor');
  }

  static Incidencia _incidencia(dynamic r) {
    if (r is Map<String, dynamic> && r['id'] != null) return Incidencia.fromJson(r);
    throw Exception('Respuesta inesperada del servidor');
  }
}

final incidenciasRepositoryProvider = Provider<IncidenciasRepository>(
  (ref) => IncidenciasRepository(ref.watch(apiClientProvider)),
);
