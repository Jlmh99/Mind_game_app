import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/sesion_expirada_exception.dart';
import '../../data/foto_perfil_repository.dart';
import '../auth/auth_controller.dart';
import 'camara.dart';
import 'compresor_foto.dart';

class FotoPerfilState {
  final Uint8List? foto; // null = sin foto (se muestra el avatar por defecto)
  final bool cargando; // GET al abrir el perfil
  final bool subiendo; // tomando/comprimiendo/enviando la foto
  final String? errorCarga; // falló el GET (se muestra junto al avatar)
  final String? errorSubida; // falló tomar/enviar (se muestra en SnackBar)

  const FotoPerfilState({
    this.foto,
    this.cargando = false,
    this.subiendo = false,
    this.errorCarga,
    this.errorSubida,
  });

  bool get ocupado => cargando || subiendo;
}

final fotoPerfilControllerProvider =
    NotifierProvider<FotoPerfilController, FotoPerfilState>(
        FotoPerfilController.new);

/// Maneja la foto de perfil: descargarla, tomarla con la cámara,
/// comprimirla y subirla.
class FotoPerfilController extends Notifier<FotoPerfilState> {
  FotoPerfilRepository get _repo => ref.read(fotoPerfilRepositoryProvider);

  @override
  FotoPerfilState build() {
    // Si cambia el usuario se olvida la foto anterior.
    ref.watch(authControllerProvider.select((s) => s.correo));
    return const FotoPerfilState();
  }

  /// GET /api/users/me/foto al abrir el perfil.
  Future<void> cargar() async {
    state = FotoPerfilState(foto: state.foto, cargando: true);
    try {
      final foto = await _repo.obtener();
      state = FotoPerfilState(foto: foto);
    } on SesionExpiradaException {
      // Tal como indica AuthController.sesionExpirada(): borra sesión y va al login.
      await ref.read(authControllerProvider.notifier).sesionExpirada();
    } catch (_) {
      state = FotoPerfilState(
          foto: state.foto, errorCarga: 'No se pudo cargar tu foto');
    }
  }

  /// Toma la foto con la cámara, la deja en menos de 2 MB y la sube con PUT.
  Future<void> tomarYSubir() async {
    if (state.ocupado) return;
    final anterior = state.foto;
    state = FotoPerfilState(foto: anterior, subiendo: true);

    try {
      final original = await ref.read(camaraProvider).tomarFoto();
      if (original == null) {
        // El usuario canceló: todo queda como estaba.
        state = FotoPerfilState(foto: anterior);
        return;
      }
      final comprimida = await comprimirFoto(original);
      await _repo.subir(comprimida);
      state = FotoPerfilState(foto: comprimida);
    } on CamaraDenegadaException {
      state = FotoPerfilState(
        foto: anterior,
        errorSubida:
            'Sin permiso de cámara no podemos tomar tu foto. Puedes activarlo en Ajustes.',
      );
    } on SesionExpiradaException {
      await ref.read(authControllerProvider.notifier).sesionExpirada();
    } catch (_) {
      // Mensaje genérico para cualquier otro problema (red, servidor, imagen).
      state = FotoPerfilState(
          foto: anterior, errorSubida: 'No se pudo actualizar tu foto');
    }
  }
}
