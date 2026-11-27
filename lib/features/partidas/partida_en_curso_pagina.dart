import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'guardado_en_curso.dart';

/// Comportamiento común de las pantallas de juego (Práctica 14):
///  - Al abrir: si el usuario tiene una partida guardada, pregunta
///    "Continuar partida / Nueva partida" (el cronómetro espera la respuesta).
///    Sin partida guardada (o sin base de datos) todo sigue como antes.
///  - Ciclo de vida de la app (AppLifecycleListener):
///    inactive / hidden / paused -> guarda ya y pausa el cronómetro;
///    resumed -> reanuda el cronómetro.
mixin PartidaEnCursoEnPagina<W extends ConsumerStatefulWidget, S> on ConsumerState<W> {
  /// Controller del juego (ref.read(...notifier)).
  ControladorConPartidaEnCurso<S> get controladorEnCurso;

  /// "Sudoku" o "Crucigrama", para el texto del diálogo.
  String get nombreJuego;

  /// Resumen de la partida guardada para el diálogo (tiempo y errores).
  String resumenPartida(S guardada);

  late final AppLifecycleListener _cicloDeVida;

  /// true mientras se busca la partida guardada o el diálogo está abierto:
  /// en ese tiempo el cronómetro no debe reanudarse.
  bool _decidiendo = false;

  @override
  void initState() {
    super.initState();
    _cicloDeVida = AppLifecycleListener(onStateChange: _alCambiarCiclo);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ofrecerContinuar());
  }

  @override
  void dispose() {
    _cicloDeVida.dispose();
    super.dispose();
  }

  void _alCambiarCiclo(AppLifecycleState estado) {
    final c = controladorEnCurso;
    switch (estado) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        c.guardarEnCurso(inmediato: true);
        c.pausar();
      case AppLifecycleState.resumed:
        if (!_decidiendo) c.reanudar();
    }
  }

  Future<void> _ofrecerContinuar() async {
    if (!mounted) return;
    final c = controladorEnCurso;
    if (!c.persistenciaActiva) return; // sin base de datos: igual que antes

    _decidiendo = true;
    c.pausar();
    final guardada = await c.partidaGuardada();
    if (!mounted) return;
    if (guardada == null) {
      _decidiendo = false;
      c.reanudar();
      return;
    }

    final continuar = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // tocar fuera no lo cierra
      // El botón "atrás" de Android tampoco: antes lo cerraba sin respuesta y
      // eso se trataba como "Nueva partida", borrando la guardada (hallazgo P14).
      builder: (dialogo) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.save_outlined, size: 40),
          title: Text('$nombreJuego sin terminar'),
          content: Text('Tienes una partida guardada (${resumenPartida(guardada)}). '
              '¿Quieres continuarla?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(false),
              child: const Text('Nueva partida'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogo).pop(true),
              child: const Text('Continuar partida'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    _decidiendo = false;
    final ctrl = controladorEnCurso;
    if (continuar == null) {
      // Cerrado sin elegir (no debería pasar con PopScope): NO se borra nada;
      // se sale del juego para que la partida nueva no pise la guardada.
      Navigator.of(context).maybePop();
      return;
    }
    if (continuar == true) {
      ctrl.restaurar(guardada); // el cronómetro sigue desde los segundos guardados
    } else {
      await ctrl.borrarEnCurso();
      if (mounted) ctrl.reanudar();
    }
  }
}
