import 'dart:typed_data';
import '../../../data/incidencias_repository.dart';
import '../../../data/mensajes_repository.dart';
import '../incidencias_comun.dart';

// Reglas compartidas del chat de incidencias.

/// ADMIN y AGENTE: el chat se actualiza solo cada 3 s. USER: pull-to-refresh.
const intervaloChat = Duration(seconds: 3);

const int maxTextoMensaje = 1000;
const int maxAdjuntoBytes = 2 * 1024 * 1024; // 2 MB

/// La pestaña "Interno" solo existe para ADMIN y AGENTE.
bool puedeVerInterno(RolApp rol) => rol != RolApp.user;

String textoCanal(CanalChat c) => c == CanalChat.publico ? 'Con el usuario' : 'Interno';

/// Texto del mensaje: obligatorio (sin solo espacios) y máximo 1000.
String? validarTextoMensaje(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'Escribe un mensaje antes de enviar';
  if (t.length > maxTextoMensaje) return 'El mensaje no puede superar $maxTextoMensaje caracteres';
  return null;
}

/// Adjunto que no se puede enviar (el mensaje ya es apto para mostrarse).
class AdjuntoInvalidoException implements Exception {
  final String mensaje;
  const AdjuntoInvalidoException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Revisa un archivo elegido y lo prepara para enviarlo:
///  - máximo 2 MB,
///  - tipo detectado por sus primeros bytes (JPG, PNG o PDF), no por el nombre.
AdjuntoMensaje prepararAdjunto(String nombre, Uint8List bytes) {
  if (bytes.isEmpty) throw const AdjuntoInvalidoException('El archivo está vacío');
  if (bytes.length > maxAdjuntoBytes) {
    throw const AdjuntoInvalidoException('El archivo no debe superar 2 MB');
  }
  final tipo = detectarTipo(bytes);
  if (tipo == null) {
    throw const AdjuntoInvalidoException('Formato no permitido (usa JPG, PNG o PDF)');
  }
  return AdjuntoMensaje(nombre: nombre, tipo: tipo, bytes: bytes);
}

/// Tipo MIME según la "firma" del archivo; null si no es JPG, PNG ni PDF.
String? detectarTipo(Uint8List b) {
  if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  if (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
    return 'image/png';
  }
  if (b.length > 4 && b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46) {
    return 'application/pdf';
  }
  return null;
}

/// Un participante del chat con sus mensajes enviados (en la vista actual).
class Participante {
  final String nombre;
  final String papel; // "Creador", "Agente", "Administración"
  final String? email;
  final int enviados;
  final bool soyYo;
  const Participante(
      {required this.nombre,
      required this.papel,
      required this.email,
      required this.enviados,
      required this.soyYo});
}

/// Participantes del canal: creador (solo en PUBLICO), agente asignado y
/// administradores (los que han escrito; si ninguno, "Administración").
/// [mensajes] son los visibles: con ellos se cuentan los enviados.
List<Participante> participantesDe(
    Incidencia inc, CanalChat canal, List<MensajeIncidencia> mensajes, String? miCorreo) {
  String clave(String? email) => (email ?? '').trim().toLowerCase();
  final mio = clave(miCorreo);
  int enviadosPor(String? email) =>
      mensajes.where((m) => clave(m.emisor?.email) == clave(email)).length;

  Participante de(UsuarioResumen u, String papel) => Participante(
        nombre: u.username,
        papel: papel,
        email: u.email,
        enviados: enviadosPor(u.email),
        soyYo: clave(u.email) == mio,
      );

  final lista = <Participante>[
    if (canal == CanalChat.publico && inc.creadoPor != null) de(inc.creadoPor!, 'Creador'),
    if (inc.asignadoA != null)
      de(inc.asignadoA!, 'Agente')
    else
      const Participante(
          nombre: 'Sin agente asignado', papel: 'Agente', email: null, enviados: 0, soyYo: false),
  ];

  // Administradores que aparecen en los mensajes (sin repetir).
  final yaIncluidos = {for (final p in lista) clave(p.email)};
  final admins = <String, UsuarioResumen>{};
  for (final m in mensajes) {
    final e = m.emisor;
    if (e != null && e.rol == 'ADMIN' && !yaIncluidos.contains(clave(e.email))) {
      admins[clave(e.email)] = e;
    }
  }
  if (admins.isEmpty) {
    lista.add(const Participante(
        nombre: 'Administración', papel: 'Administración', email: null, enviados: 0, soyYo: false));
  } else {
    lista.addAll(admins.values.map((u) => de(u, 'Administración')));
  }
  return lista;
}
