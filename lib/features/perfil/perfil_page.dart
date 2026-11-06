import 'package:flutter/material.dart';
import '../../core/widgets/pantalla_en_construccion.dart';

/// Pantalla "Mi perfil" (placeholder).
/// Aquí se mostrarán los datos del usuario y sus estadísticas más adelante.
class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PantallaEnConstruccion(
      titulo: 'Mi perfil',
      icono: Icons.person,
      descripcion: 'Tus datos y estadísticas estarán disponibles pronto.',
    );
  }
}
