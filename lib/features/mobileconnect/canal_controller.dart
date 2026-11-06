import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import 'mobileconnect_model.dart';

/// Reloj de la app. Es un provider para que las pruebas usen una hora fija.
final relojProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// El "canal" de comunicación entre Dispositivo A y Dispositivo B.
/// Vive en memoria: no usa red ni backend. No es autoDispose, así la
/// conversación se conserva mientras la app esté abierta.
final canalProvider = NotifierProvider<CanalController, CanalState>(
    CanalController.new);

class CanalController extends Notifier<CanalState> {
  @override
  CanalState build() {
    // Si cambia el usuario (logout / otra cuenta) la conversación se reinicia.
    ref.watch(authControllerProvider.select((s) => s.correo));
    return const CanalState();
  }

  /// Cambia el dispositivo que va a enviar (SegmentedButton).
  void cambiarEmisor(Dispositivo d) => state = state.copyWith(emisor: d);

  /// Envía [texto] desde el emisor actual hacia el otro dispositivo.
  /// Devuelve el mensaje enviado, o null si estaba vacío o solo tenía espacios.
  Mensaje? enviar(String texto) {
    final limpio = texto.trim();
    if (limpio.isEmpty) return null;

    final mensaje = Mensaje(
      emisor: state.emisor,
      // Se recorta por seguridad aunque el campo ya limita la longitud.
      texto: limpio.length > maxLongitudMensaje
          ? limpio.substring(0, maxLongitudMensaje)
          : limpio,
      hora: ref.read(relojProvider)(),
    );
    state = state.copyWith(mensajes: [...state.mensajes, mensaje]);
    return mensaje;
  }

  /// Borra el historial (los contadores vuelven a 0). Se conserva el emisor.
  void limpiar() => state = state.copyWith(mensajes: const []);
}
