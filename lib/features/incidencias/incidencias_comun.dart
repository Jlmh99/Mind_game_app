import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errores_api.dart';
import '../../core/sesion_expirada_exception.dart';
import '../../data/incidencias_repository.dart';
import '../auth/auth_controller.dart';

// Piezas compartidas del módulo de incidencias: roles, permisos visuales,
// validaciones, textos y manejo genérico de errores.

/// Rol del usuario según AuthState.rol (si no hay, se trata como USER).
enum RolApp { user, agente, admin }

RolApp rolDesde(String? rol) => switch (rol) {
      'ADMIN' => RolApp.admin,
      'AGENTE' => RolApp.agente,
      _ => RolApp.user,
    };

/// ADMIN y AGENTE se sincronizan solos cada 5 s; USER usa pull-to-refresh.
bool usaSincronizacionAutomatica(RolApp rol) => rol != RolApp.user;

const intervaloSincronizacion = Duration(seconds: 5);

// ---------------- Textos ----------------

String textoEstado(EstadoIncidencia e) => switch (e) {
      EstadoIncidencia.pendiente => 'Pendiente',
      EstadoIncidencia.enProceso => 'En proceso',
      EstadoIncidencia.resuelta => 'Resuelta',
    };

String textoPrioridad(PrioridadIncidencia p) => switch (p) {
      PrioridadIncidencia.baja => 'Baja',
      PrioridadIncidencia.media => 'Media',
      PrioridadIncidencia.alta => 'Alta',
      PrioridadIncidencia.critica => 'Crítica',
    };

String textoRol(RolApp r) => switch (r) {
      RolApp.user => 'Usuario',
      RolApp.agente => 'Agente',
      RolApp.admin => 'Administrador',
    };

Color colorEstado(ColorScheme c, EstadoIncidencia e) => switch (e) {
      EstadoIncidencia.pendiente => c.tertiaryContainer,
      EstadoIncidencia.enProceso => c.secondaryContainer,
      EstadoIncidencia.resuelta => const Color(0xFFC8E6C9),
    };

Color colorPrioridad(ColorScheme c, PrioridadIncidencia p) => switch (p) {
      PrioridadIncidencia.baja => c.surfaceContainerHighest,
      PrioridadIncidencia.media => c.primaryContainer,
      PrioridadIncidencia.alta => const Color(0xFFFFE0B2),
      PrioridadIncidencia.critica => c.errorContainer,
    };

// ---------------- Validaciones (crear / editar) ----------------

const int maxTituloIncidencia = 80;
const int maxDescripcionIncidencia = 500;

/// Título: obligatorio, sin solo espacios (trim) y máximo 80 caracteres.
String? validarTituloIncidencia(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'Escribe un título';
  if (t.length > maxTituloIncidencia) return 'Máximo $maxTituloIncidencia caracteres';
  return null;
}

/// Descripción: máximo 500. También es obligatoria porque el backend la exige.
String? validarDescripcionIncidencia(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return 'Describe el problema';
  if (t.length > maxDescripcionIncidencia) {
    return 'Máximo $maxDescripcionIncidencia caracteres';
  }
  return null;
}

// ---------------- Permisos visuales ----------------
// Solo deciden qué botones se MUESTRAN. El backend vuelve a validar todo
// (si responde 403 se muestra "No tienes permiso para esta acción").

bool _mismoCorreo(UsuarioResumen? u, String? correo) =>
    u != null &&
    correo != null &&
    u.email.trim().toLowerCase() == correo.trim().toLowerCase();

bool esCreador(Incidencia i, String? correo) => _mismoCorreo(i.creadoPor, correo);

bool esAgenteAsignado(Incidencia i, String? correo, RolApp rol) =>
    rol == RolApp.agente && _mismoCorreo(i.asignadoA, correo);

bool puedeEditarTexto(Incidencia i, String? correo, RolApp rol) =>
    rol == RolApp.admin || esCreador(i, correo);

bool puedeEliminar(Incidencia i, String? correo, RolApp rol) =>
    rol == RolApp.admin || esCreador(i, correo);

bool puedeCambiarEstado(Incidencia i, String? correo, RolApp rol) =>
    rol == RolApp.admin || esAgenteAsignado(i, correo, rol);

bool puedeCambiarPrioridad(RolApp rol) => rol == RolApp.admin;

bool puedeAsignar(RolApp rol) => rol == RolApp.admin;

// ---------------- Resultado de una acción ----------------

/// Lo que pasó al intentar una acción (crear, editar, asignar, borrar).
enum ResultadoAccion { ok, sinPermiso, conflicto, noExiste, error, sesionExpirada }

const mensajeSinPermiso = 'No tienes permiso para esta acción';
const mensajeConflicto = 'El registro fue modificado desde otro dispositivo';
const mensajeNoExiste = 'La incidencia ya no existe';
const mensajeErrorGenerico = 'No se pudo completar la acción, intenta de nuevo';
const mensajeErrorCarga = 'No se pudieron cargar las incidencias';

/// Ejecuta [accion] y traduce cualquier error a un ResultadoAccion.
/// SesionExpiradaException -> authController.sesionExpirada() (vuelve al login).
/// Nunca se registra el error ni la respuesta del servidor.
Future<ResultadoAccion> ejecutarAccion(Ref ref, Future<void> Function() accion) async {
  try {
    await accion();
    return ResultadoAccion.ok;
  } on SesionExpiradaException {
    await ref.read(authControllerProvider.notifier).sesionExpirada();
    return ResultadoAccion.sesionExpirada;
  } on PermisoDenegadoException {
    return ResultadoAccion.sinPermiso;
  } on ErrorHttpException catch (e) {
    if (e.esConflicto) return ResultadoAccion.conflicto;
    if (e.noEncontrado) return ResultadoAccion.noExiste;
    return ResultadoAccion.error;
  } catch (_) {
    return ResultadoAccion.error;
  }
}

/// Mensaje para mostrar al usuario según el resultado (null si no hay que mostrar nada).
String? mensajeDe(ResultadoAccion r) => switch (r) {
      ResultadoAccion.ok || ResultadoAccion.sesionExpirada => null,
      ResultadoAccion.sinPermiso => mensajeSinPermiso,
      ResultadoAccion.conflicto => mensajeConflicto,
      ResultadoAccion.noExiste => mensajeNoExiste,
      ResultadoAccion.error => mensajeErrorGenerico,
    };
