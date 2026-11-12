import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/local/sesion_dao.dart';
import 'api_config.dart';
import 'errores_api.dart';
import 'sesion_expirada_exception.dart';

/// Cliente HTTP único para hablar con el backend de Spring Boot.
///
/// Centraliza en un solo lugar:
///  - la URL base y el encabezado Content-Type,
///  - el timeout (Render puede tardar en despertar),
///  - la normalización de la respuesta (JSON o texto plano),
///  - el envío del token JWT cuando la petición es autenticada,
///  - la traducción de errores HTTP a excepciones de la app.
///
/// IMPORTANTE: este cliente nunca imprime tokens, contraseñas ni respuestas.
class ApiClient {
  final SesionDao _sesionDao;
  final http.Client _http;

  /// [cliente] es opcional: solo se pasa en las pruebas (MockClient).
  ApiClient(this._sesionDao, {http.Client? cliente})
      : _http = cliente ?? http.Client();

  static const Duration _timeout = Duration(seconds: 30);

  /// GET a [ruta]. Si [autenticado] es true, envía `Authorization: Bearer <token>`.
  Future<dynamic> get(String ruta, {bool autenticado = false}) async {
    final headers = await _headers(autenticado);
    final resp = await _http
        .get(Uri.parse('$baseUrl$ruta'), headers: headers)
        .timeout(_timeout);
    return _procesar(resp, autenticado);
  }

  /// POST a [ruta] con [cuerpo] en JSON.
  Future<dynamic> post(String ruta, Map<String, dynamic> cuerpo,
      {bool autenticado = false}) async {
    final headers = await _headers(autenticado);
    final resp = await _http
        .post(Uri.parse('$baseUrl$ruta'),
            headers: headers, body: jsonEncode(cuerpo))
        .timeout(_timeout);
    return _procesar(resp, autenticado);
  }

  /// PUT a [ruta] con [cuerpo] en JSON.
  Future<dynamic> put(String ruta, Map<String, dynamic> cuerpo,
      {bool autenticado = false}) async {
    final headers = await _headers(autenticado);
    final resp = await _http
        .put(Uri.parse('$baseUrl$ruta'),
            headers: headers, body: jsonEncode(cuerpo))
        .timeout(_timeout);
    return _procesar(resp, autenticado);
  }

  /// DELETE a [ruta].
  Future<dynamic> delete(String ruta, {bool autenticado = false}) async {
    final headers = await _headers(autenticado);
    final resp = await _http
        .delete(Uri.parse('$baseUrl$ruta'), headers: headers)
        .timeout(_timeout);
    return _procesar(resp, autenticado);
  }

  /// Arma los encabezados. En peticiones autenticadas lee el token
  /// guardado en la sesión local (Floor).
  Future<Map<String, String>> _headers(bool autenticado) async {
    final headers = {'Content-Type': 'application/json'};
    if (autenticado) {
      final sesion = await _sesionDao.obtener();
      final token = sesion?.token ?? '';
      // Sin token no tiene caso llamar al servidor: la sesión ya no es válida.
      if (token.isEmpty) throw const SesionExpiradaException();
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Revisa el código HTTP y normaliza el cuerpo de la respuesta.
  ///
  /// El backend responde 200 incluso en errores lógicos y a veces devuelve
  /// texto plano (por ejemplo /register). Por eso:
  ///  - si el cuerpo es JSON (objeto o lista) se devuelve tal cual,
  ///  - si es texto plano se envuelve en {'mensaje': texto}.
  dynamic _procesar(http.Response resp, bool autenticado) {
    final texto = utf8.decode(resp.bodyBytes);

    if (autenticado) {
      // 401: el backend no reconoce la sesión (usuario borrado/deshabilitado).
      if (resp.statusCode == 401) throw const SesionExpiradaException();

      // 403 tiene dos significados en el backend:
      //  - Sin token / token vencido: lo responde Spring Security SIN un JSON
      //    con "mensaje" -> la sesión expiró.
      //  - Permiso denegado (incidencias): lo responde ErrorApi CON
      //    {"mensaje": "..."} -> la sesión sigue bien, solo falta permiso.
      if (resp.statusCode == 403) {
        if (_tieneMensaje(texto)) throw const PermisoDenegadoException();
        throw const SesionExpiradaException();
      }
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      // Solo se guarda el código, nunca el cuerpo de la respuesta.
      throw ErrorHttpException(resp.statusCode);
    }

    try {
      final datos = jsonDecode(texto);
      if (datos is Map<String, dynamic> || datos is List) return datos;
    } catch (_) {
      // No era JSON: lo tratamos como texto plano.
    }
    return {'mensaje': texto};
  }

  /// true si el cuerpo es un JSON con la clave "mensaje" (respuesta de ErrorApi).
  static bool _tieneMensaje(String texto) {
    try {
      final datos = jsonDecode(texto);
      return datos is Map && datos['mensaje'] is String;
    } catch (_) {
      return false;
    }
  }
}
