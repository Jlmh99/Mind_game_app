# Matriz de pruebas de caja negra — Mind Games

> **Nota:** la app móvil (Flutter) consume un backend en **Spring Boot** con base de datos
> **PostgreSQL** y autenticación con **JWT** (`Authorization: Bearer <token>`). **Las reglas
> de seguridad se aplican en el backend:** la app solo oculta los botones que tu rol no puede
> usar, pero quien acepta o rechaza cada acción es el servidor. Por eso algunas pruebas se
> hacen por API (Postman o curl) además de en la app.

Los requisitos (RF-xx) están en [requisitos_caja_negra.md](requisitos_caja_negra.md).

**Cómo llenar las columnas:**
- **Resultado obtenido:** lo que realmente pasó.
- **Estado:** Pasa, Falla o Bloqueada.
- **Evidencia:** nombre de la captura, del video o de la respuesta HTTP guardada.

**Datos de prueba sugeridos:**
- Cuentas `user1` (USER), `user2` (USER), `agente1` (AGENTE) y `admin1` (ADMIN), cargadas con `sql/roles_prueba.sql`.
- Una incidencia **I1** creada por `user1` y asignada a `agente1`.

## 1. Inicio de sesión y registro (RF-01, RF-05)

| ID | Requisito | Datos de entrada | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| CP-01 | RF-01 | Correo y contraseña correctos de `user1` (sin 2FA) | Entra a la pantalla de inicio "Mind Games" | | | |
| CP-02 | RF-01 | Correo correcto y contraseña incorrecta | "Credenciales inválidas"; no entra | | | |
| CP-03 | RF-01 | Correo que no existe | El mismo mensaje "Credenciales inválidas" (no revela que el correo no existe) | | | |
| CP-04 | RF-01 | Cuenta con 2FA: correo y contraseña correctos | Pantalla "Verificación" con "Enviamos un código a <correo>" | | | |
| CP-05 | RF-01 | Cuenta con 2FA: código incorrecto `000000` | "Código inválido"; sigue en Verificación | | | |
| CP-06 | RF-01 | Cuenta con 2FA: código correcto, ingresado después de 5 minutos | "Código inválido" (el código ya venció) | | | |
| CP-07 | RF-05 | Login con correo vacío y contraseña vacía | "Ingresa tu correo" e "Ingresa tu contraseña"; no se envía nada | | | |
| CP-08 | RF-05 | Correo `usuario@correo` (sin dominio) | "Ingresa un correo válido" | | | |
| CP-09 | RF-05 | Correo de 3 espacios | "Ingresa tu correo" (solo espacios cuenta como vacío) | | | |
| CP-10 | RF-05 | Contraseña de 65 caracteres | "Máximo 64 caracteres" | | | |
| CP-11 | RF-05 | Registro con contraseña `abc1234` (7 caracteres) | "Mínimo 8 caracteres"; no se crea la cuenta | | | |
| CP-12 | RF-05 | Registro con usuario de 31 caracteres | "Máximo 30 caracteres" | | | |
| CP-13 | RF-05 | Registro con datos válidos y nuevos | "Cuenta creada. Ahora inicia sesión." y regresa al login | | | |
| CP-14 | RF-05 | Registro con un correo que ya existe | "No se pudo completar el registro" | | | |
| CP-15 | RF-05 | Tocar dos veces seguidas "INICIAR SESIÓN" | El botón se deshabilita mientras procesa; solo se hace un intento | | | |
| CP-16 | RF-05 | Escribir contraseña y tocar el ícono del ojo | Alterna entre "Mostrar contraseña" y "Ocultar contraseña" | | | |

## 2. Incidencias: crear y validar (RF-02, RF-06)

| ID | Requisito | Datos de entrada | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| CP-17 | RF-02 | `user1`: título "No carga el Sudoku", descripción válida, prioridad Alta | "Incidencia creada"; aparece en la lista como Pendiente, Alta, "De: user1" | | | |
| CP-18 | RF-02 | `user1`: crear sin cambiar la prioridad | La incidencia queda con prioridad Media | | | |
| CP-19 | RF-06 | Título vacío | "Escribe un título"; no se crea | | | |
| CP-20 | RF-06 | Título de solo espacios | "Escribe un título" | | | |
| CP-21 | RF-06 | Título de 81 caracteres | "Máximo 80 caracteres" | | | |
| CP-22 | RF-06 | Descripción vacía | "Describe el problema" | | | |
| CP-23 | RF-06 | Descripción de 501 caracteres | "Máximo 500 caracteres" | | | |
| CP-24 | RF-06 | API: `POST /api/incidencias` con `"estado":"XYZ"` o `"prioridad":"URGENTE"` | 400 `{"mensaje":"Datos no válidos"}` | | | |
| CP-25 | RF-06 | API: `POST` con título de 151 caracteres | 400 "El título no puede superar 150 caracteres" | | | |
| CP-26 | RF-02 | Tocar "Crear incidencia" dos veces seguidas | Solo se crea una incidencia | | | |

## 3. Detalle, permisos por rol y navegación (RF-10, RF-11)

| ID | Requisito | Datos de entrada | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| CP-27 | RF-10 | Abrir "Incidencias" como `user1` | "Vista de Usuario: tus incidencias"; solo se ven las de `user1` | | | |
| CP-28 | RF-10 | Abrir "Incidencias" como `agente1` | "Vista de Agente: incidencias asignadas a ti"; solo las asignadas | | | |
| CP-29 | RF-10 | Abrir "Incidencias" como `admin1` | "Vista de Administrador: todas las incidencias" | | | |
| CP-30 | RF-10 | Filtrar por un estado sin incidencias | "No hay incidencias con este estado" | | | |
| CP-31 | RF-11 | `user1` abre I1 (es el creador) | Ve "Editar título y descripción" y "Eliminar incidencia"; no ve estado, prioridad ni asignar | | | |
| CP-32 | RF-11 | `agente1` abre I1 (asignada a él) | Puede cambiar el estado; no ve editar texto, prioridad, asignar ni eliminar | | | |
| CP-33 | RF-11 | `admin1` abre I1 | Ve todos los controles, incluidos "Prioridad" y "Asignar a agente" | | | |
| CP-34 | RF-11 | `admin1` asigna I1 a `agente1` | "Agente asignado"; el detalle muestra "Agente: agente1" | | | |
| CP-35 | RF-11 | `admin1` abre "Asignar a agente" sin agentes habilitados en la BD | "No hay agentes disponibles para asignar." | | | |
| CP-36 | RF-11 | `user1` elimina I1 y toca **Cancelar** en el diálogo | La incidencia sigue existiendo | | | |
| CP-37 | RF-11 | `user1` elimina I1 y confirma **Eliminar** | "Incidencia eliminada"; regresa a la lista y ya no aparece | | | |
| CP-38 | RF-11 | API como `agente1`: `PUT /api/incidencias/{I1}` cambiando el título | 403 "No tienes permiso para realizar esta acción" | | | |
| CP-39 | RF-11 | API como `user1`: `PUT` cambiando la prioridad de su incidencia | 403 (solo ADMIN cambia la prioridad) | | | |
| CP-40 | RF-11 | API como `user1`: `PUT /api/incidencias/{id}/asignar` | 403 | | | |
| CP-41 | RF-11 | API como `agente1`: `DELETE /api/incidencias/{I1}` | 403 (el agente no puede borrar) | | | |
| CP-42 | RF-11 | API como `user1`: `GET /api/incidencias/agentes` | 403 (solo ADMIN) | | | |
| CP-43 | RF-10 | API: `GET /api/incidencias/999999` (no existe) | 404 "Incidencia no encontrada"; en la app, "La incidencia ya no existe" | | | |
| CP-44 | RF-10 | Navegación: Inicio → Incidencias → Detalle → Chat → atrás tres veces | Regresa paso a paso hasta el inicio sin pantallas en blanco | | | |
| CP-45 | RF-10 | Tocar "Cerrar sesión" en el inicio y luego el botón atrás de Android | Queda en el login; atrás no regresa a pantallas de la sesión anterior | | | |

## 4. Chat de incidencias (RF-03, RF-07, RF-11, RF-14)

| ID | Requisito | Datos de entrada | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| CP-46 | RF-03 | `user1` en I1: texto "Hola, sigue fallando" | "Mensaje enviado"; burbuja a la derecha con "Tú" y la hora HH:mm | | | |
| CP-47 | RF-03 | `agente1` abre el chat de I1 | El mensaje de `user1` aparece a la izquierda con "user1 · Usuario" | | | |
| CP-48 | RF-03 | Enviar con una foto de la galería (< 2 MB) | Vista previa antes de enviar; en el chat se ve la miniatura y al tocarla se amplía | | | |
| CP-49 | RF-03 | Enviar con un PDF válido (< 2 MB) | Ícono de PDF con el nombre y el tamaño en KB | | | |
| CP-50 | RF-07 | Texto vacío y tocar enviar | "Escribe un mensaje antes de enviar"; no se envía | | | |
| CP-51 | RF-07 | Texto de solo espacios | "Escribe un mensaje antes de enviar" | | | |
| CP-52 | RF-07 | Pegar 1200 caracteres | El campo se detiene en 1000 (contador 1000/1000) | | | |
| CP-53 | RF-07 | Adjuntar un PDF de 3 MB | "El archivo no debe superar 2 MB"; no se adjunta | | | |
| CP-54 | RF-07 | Adjuntar un archivo que no es PDF renombrado a `.pdf` | "Formato no permitido (usa JPG, PNG o PDF)"; no se adjunta | | | |
| CP-55 | RF-07 | API: `POST .../mensajes` con `tipo:"image/png"` y contenido de un PDF | 400 "El contenido del adjunto no coincide con su tipo" | | | |
| CP-56 | RF-07 | API: `POST .../mensajes` con `tipo:"application/zip"` | 400 "Tipo de archivo no permitido (usa JPG, PNG o PDF)" | | | |
| CP-57 | RF-11 | `user1` abre el chat de I1 | Solo existe la conversación "Con el usuario"; no hay pestaña "Interno" | | | |
| CP-58 | RF-11 | `agente1` y `admin1` abren el chat de I1 | Ven las pestañas "Con el usuario" e "Interno" | | | |
| CP-59 | RF-11 | API como `user1`: `GET /api/incidencias/{I1}/mensajes?canal=INTERNO` | 403 | | | |
| CP-60 | RF-11 | Mensaje escrito en "Interno" por `agente1` | `user1` no lo ve en su chat | | | |
| CP-61 | RF-03 | "Limpiar historial" → Cancelar, y luego "Limpiar historial" → confirmar | Cancelar no cambia nada; confirmar oculta los mensajes solo en ese teléfono (el otro los sigue viendo) | | | |
| CP-62 | RF-14 | `agente1` con el chat abierto; `user1` envía un mensaje | En ≤ 3 s aparece la burbuja y el SnackBar "Nuevo mensaje de user1" | | | |
| CP-63 | RF-14 | `user1` con el chat abierto; `agente1` envía un mensaje | No aparece solo; al deslizar hacia abajo se carga | | | |

## 5. Partidas y perfil (RF-04, RF-13)

| ID | Requisito | Datos de entrada | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| CP-64 | RF-04 | Completar un Sudoku con 2 errores en 120 s | "¡Sudoku completado!", puntuación 780 (1000 − 120 − 100) y "Partida guardada" | | | |
| CP-65 | RF-04 | Completar un Crucigrama con 2 errores en 120 s | "¡Crucigrama completado!", puntuación 830 (1000 − 120 − 50) y "Partida guardada" | | | |
| CP-66 | RF-04 | Abrir "Mi perfil" después de CP-64 | La partida de Sudoku aparece primero con su tiempo y puntuación | | | |
| CP-67 | RF-04 | Sudoku: tocar "Reiniciar" a medio juego | El tablero vuelve al inicio y el tiempo y los errores regresan a 0 | | | |
| CP-68 | RF-04 | API: `POST /api/partidas` con `puntuacion: -5` | 400 "Tiempo y puntuación deben ser mayores o iguales a 0" | | | |
| CP-69 | RF-04 | API: `POST /api/partidas` con `juego: "AJEDREZ"` | 400 "Juego no válido" | | | |
| CP-70 | RF-13 | "Mi perfil": elegir una foto de la galería | "Actualizando foto..." y luego el avatar nuevo | | | |
| CP-71 | RF-13 | Negar el permiso de cámara y tocar "Tomar foto" | "Sin permiso de cámara no podemos tomar tu foto. Puedes activarlo en Ajustes." | | | |
| CP-72 | RF-13 | Cuenta nueva sin partidas abre "Mi perfil" | "Aún no tienes partidas. ¡Juega un Sudoku o un Crucigrama!" | | | |

## 6. Persistencia y concurrencia (RF-08, RF-09)

| ID | Requisito | Datos de entrada | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| CP-73 | RF-08 | Iniciar sesión, cerrar la app desde recientes y volver a abrirla | Entra directo al inicio sin pedir datos | | | |
| CP-74 | RF-08 | "Cerrar sesión" y volver a abrir la app | Abre en el login | | | |
| CP-75 | RF-09 | API: `PUT /api/incidencias/{I1}` sin el campo `version` | 400 "Falta la versión del registro" | | | |
| CP-76 | RF-09 | API: `PUT` con una `version` menor a la actual | 409 "El registro fue modificado desde otro dispositivo" | | | |
| CP-77 | RF-09 | API: `POST /api/incidencias` con `creadoPor` = correo de otro usuario | 403; no se crea la incidencia | | | |

## 7. Condiciones de error (RF-12)

| ID | Requisito | Datos de entrada | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| CP-78 | RF-12 | Backend apagado; intentar iniciar sesión | "No se pudo conectar, intenta de nuevo"; la app no se cierra | | | |
| CP-79 | RF-12 | Modo avión con la lista de incidencias abierta; deslizar para recargar | "No se pudieron cargar las incidencias"; al volver la red y recargar, carga normal | | | |
| CP-80 | RF-12 | Modo avión en el chat; intentar enviar | "No se pudo completar la acción, intenta de nuevo"; el texto escrito no se pierde | | | |
| CP-81 | RF-12 | Modo avión al terminar un Sudoku | El diálogo de fin se muestra y aparece "No se pudo guardar la partida. Revisa tu conexión." | | | |
| CP-82 | RF-12 | Detener el backend con el chat abierto como ADMIN (sincronización cada 3 s) | Aparece el error, la app sigue usable y se recupera sola al volver a levantar el backend | | | |
| CP-83 | RF-12 | Token alterado o vencido en la sesión guardada; abrir Incidencias | Regresa al login con "Tu sesión expiró" | | | |
| CP-84 | RF-12 | API: `GET /api/incidencias` sin el encabezado `Authorization` | 403; no devuelve datos | | | |
| CP-85 | RF-12 | API: `GET /api/incidencias/abc` (id no numérico) | 400 "Datos no válidos", sin traza de error | | | |
| CP-86 | RF-12 | Revisar Logcat (`flutter logs`) durante CP-01 a CP-85 | No aparecen contraseñas, tokens ni respuestas completas del servidor | | | |
