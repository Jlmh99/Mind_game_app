import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/api_config.dart';
import '../core/providers.dart';
import 'incidencias_repository.dart';

/// Canal del chat de una incidencia (mismos valores que el backend).
///  - publico: creador, agente asignado y ADMIN ("Con el usuario").
///  - interno: solo agente asignado y ADMIN ("Interno").
enum CanalChat { publico, interno }

String canalAApi(CanalChat c) => c == CanalChat.publico ? 'PUBLICO' : 'INTERNO';
CanalChat canalDesdeApi(String? s) => s == 'INTERNO' ? CanalChat.interno : CanalChat.publico;

/// Archivo adjunto de un mensaje (JPG, PNG o PDF).
class AdjuntoMensaje {
  final String nombre;
  final String tipo; // image/jpeg, image/png o application/pdf
  final Uint8List bytes; // ya decodificado del Base64 (se decodifica una sola vez)

  const AdjuntoMensaje({required this.nombre, required this.tipo, required this.bytes});

  bool get esImagen => tipo.startsWith('image/');

  static AdjuntoMensaje? opcional(dynamic j) {
    if (j is! Map<String, dynamic>) return null;
    final contenido = j['contenido'];
    if (contenido is! String || contenido.isEmpty) return null;
    try {
      return AdjuntoMensaje(
        nombre: (j['nombre'] ?? 'adjunto').toString(),
        tipo: (j['tipo'] ?? '').toString(),
        bytes: base64Decode(contenido),
      );
    } on FormatException {
      return null; // Base64 dañado: se muestra el mensaje sin adjunto
    }
  }
}

/// Mensaje tal como lo devuelve /api/incidencias/{id}/mensajes.
class MensajeIncidencia {
  final int id;
  final int incidenciaId;
  final UsuarioResumen? emisor;
  final String texto;
  final CanalChat canal;
  final DateTime fecha;
  final AdjuntoMensaje? adjunto;

  const MensajeIncidencia({
    required this.id,
    required this.incidenciaId,
    required this.emisor,
    required this.texto,
    required this.canal,
    required this.fecha,
    this.adjunto,
  });

  factory MensajeIncidencia.fromJson(Map<String, dynamic> j) => MensajeIncidencia(
        id: (j['id'] as num).toInt(),
        incidenciaId: (j['incidenciaId'] as num).toInt(),
        emisor: UsuarioResumen.opcional(j['emisor']),
        texto: (j['texto'] ?? '').toString(),
        canal: canalDesdeApi(j['canal']?.toString()),
        fecha: DateTime.parse(j['fecha'] as String),
        adjunto: AdjuntoMensaje.opcional(j['adjunto']),
      );
}

/// GET y POST de /api/incidencias/{id}/mensajes con el ApiClient autenticado.
/// Puede lanzar SesionExpiradaException, PermisoDenegadoException (403, por
/// ejemplo un USER pidiendo el canal INTERNO) o ErrorHttpException.
class MensajesRepository {
  final ApiClient api;
  MensajesRepository(this.api);

  Future<List<MensajeIncidencia>> listar(int incidenciaId, CanalChat canal) async {
    final r = await api.get(
        '$rutaIncidencias/$incidenciaId/mensajes?canal=${canalAApi(canal)}',
        autenticado: true);
    if (r is List) {
      return [for (final j in r) MensajeIncidencia.fromJson(j as Map<String, dynamic>)];
    }
    throw Exception('Respuesta inesperada del servidor');
  }

  /// Envía el mensaje con su canal. El adjunto se manda en Base64.
  Future<MensajeIncidencia> enviar(
    int incidenciaId, {
    required String texto,
    required CanalChat canal,
    AdjuntoMensaje? adjunto,
  }) async {
    final r = await api.post(
      '$rutaIncidencias/$incidenciaId/mensajes',
      {
        'texto': texto,
        'canal': canalAApi(canal),
        if (adjunto != null)
          'adjunto': {
            'nombre': adjunto.nombre,
            'tipo': adjunto.tipo,
            'contenido': base64Encode(adjunto.bytes),
          },
      },
      autenticado: true,
    );
    if (r is Map<String, dynamic> && r['id'] != null) return MensajeIncidencia.fromJson(r);
    throw Exception('Respuesta inesperada del servidor');
  }
}

final mensajesRepositoryProvider = Provider<MensajesRepository>(
  (ref) => MensajesRepository(ref.watch(apiClientProvider)),
);
