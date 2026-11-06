import 'package:flutter/material.dart';
import '../../core/widgets/pantalla_en_construccion.dart';

/// Pantalla MobileConnect (placeholder).
/// Aquí se integrará la comunicación entre dispositivos más adelante.
class MobileConnectPage extends StatelessWidget {
  const MobileConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PantallaEnConstruccion(
      titulo: 'MobileConnect',
      icono: Icons.devices,
      descripcion: 'La conexión entre dispositivos estará disponible pronto.',
    );
  }
}
