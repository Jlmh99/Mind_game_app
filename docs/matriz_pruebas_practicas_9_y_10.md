# Matrices de prueba — Prácticas 9 y 10 — Mind Games

> **Nota:** la app móvil (Flutter) consume un backend en **Spring Boot** con base de datos
> **PostgreSQL** y autenticación con **JWT** (`Authorization: Bearer <token>`). **Las reglas
> de seguridad se aplican en el backend:** el usuario se obtiene siempre del token (nunca del
> cuerpo de la petición) y los permisos se deciden con el rol guardado en la base de datos.
> Por eso las pruebas de la práctica 10 se hacen también por API (Postman o curl), sin pasar
> por la app.

**Cómo llenar las columnas:**
- **Resultado obtenido:** lo que realmente pasó.
- **Estado:** Pasa, Falla o Bloqueada.
- **Evidencia:** captura, video o respuesta HTTP guardada.

## Preparación

| Elemento | Configuración |
|---|---|
| Backend | Un solo backend en la laptop (puerto 8080) conectado a **una sola** base PostgreSQL. |
| Dispositivo A | Teléfono físico por USB con `adb -s <serie_A> reverse tcp:8080 tcp:8080`. |
| Dispositivo B | Emulador (o segundo teléfono) con `adb -s <serie_B> reverse tcp:8080 tcp:8080`. |
| Cuentas | `user1` y `user2` (USER), `agente1` (AGENTE) y `admin1` (ADMIN), cargadas con `sql/roles_prueba.sql`. |
| Incidencia base | **I1**, creada por `user1` y asignada a `agente1` por `admin1`. |
| Tokens para API | Se obtienen con `POST /api/auth/login`. **No se pegan en capturas ni en el reporte.** |

---

# Práctica 9 — Dos dispositivos con la misma base de datos

## 9.1 Escritura y lectura cruzada

| ID | Escenario | Pasos y datos | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| P9-01 | Misma BD en ambos dispositivos | A entra como `admin1`, B entra como `user1`; ambos abren "Incidencias" | B ve solo las incidencias de `user1`; A ve todas, incluidas las de `user1` con los mismos datos | | | |
| P9-02 | Crear en B, leer en A | B (`user1`) crea "Prueba cruzada 1" | A (`admin1`) la ve en ≤ 5 s sin tocar nada, con estado Pendiente y "De: user1" | | | |
| P9-03 | Crear en A, leer en B | A entra como `user1` y crea "Prueba cruzada 2"; B, también como `user1`, desliza para recargar | B la ve después de recargar (USER no se actualiza solo) | | | |
| P9-04 | La misma cuenta en dos dispositivos | `user1` inicia sesión en A y en B | Ambos funcionan a la vez y ven la misma lista | | | |
| P9-05 | Mensaje del chat de B a A | B (`user1`) envía "Hola desde B" en el chat de I1; A (`agente1`) tiene el chat abierto | A lo ve en ≤ 3 s, a la izquierda, con "user1 · Usuario", y aparece "Nuevo mensaje de user1" | | | |
| P9-06 | Mensaje del chat de A a B | A (`agente1`) responde en "Con el usuario"; B (`user1`) desliza para recargar | B lo ve después de recargar, con "agente1 · Agente" y la hora HH:mm | | | |
| P9-07 | Adjunto cruzado | B envía una foto y A envía un PDF en el chat de I1 | Cada dispositivo ve la miniatura de la foto y el ícono del PDF con su nombre | | | |
| P9-08 | Canal interno cruzado | A (`agente1`) escribe en "Interno"; B (`admin1`) abre "Interno" | `admin1` lo ve; si B entra como `user1`, no lo ve en ninguna parte | | | |
| P9-09 | Partida cruzada | B (`user1`) termina un Sudoku; A, como `user1`, abre "Mi perfil" | La partida aparece en A con el mismo tiempo y puntuación | | | |
| P9-10 | Foto de perfil cruzada | B (`user1`) cambia su foto; A, como `user1`, abre "Mi perfil" | A muestra la foto nueva | | | |

## 9.2 Actualización y sincronización

| ID | Escenario | Pasos y datos | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| P9-11 | Cambio de estado | B (`agente1`) cambia I1 a "En proceso"; A (`admin1`) tiene el detalle de I1 abierto | En A el estado cambia a "En proceso" en ≤ 5 s y la "Versión" sube en 1 | | | |
| P9-12 | Cambio de prioridad | A (`admin1`) cambia I1 a "Crítica"; B (`user1`) tiene la lista abierta | B ve "Crítica" después de deslizar para recargar | | | |
| P9-13 | Asignación | A (`admin1`) asigna I1 a `agente1`; B (`agente1`) tiene la lista abierta | I1 aparece en la lista de B en ≤ 5 s | | | |
| P9-14 | Eliminación | B (`user1`) elimina I1; A (`admin1`) tiene el detalle de I1 abierto | En A aparece "La incidencia ya no existe" | | | |
| P9-15 | Hora de la última actualización | A (`admin1`) en la lista durante 20 s | La barra cambia su hora cada 5 s aproximadamente | | | |
| P9-16 | El temporizador se detiene al salir | A (`admin1`) abre el chat y regresa al detalle | Se dejan de hacer peticiones del chat (se puede revisar en el log del backend o con un proxy) | | | |
| P9-17 | Sin red y regreso | A (`admin1`) en la lista; activar modo avión 15 s y luego quitarlo | Se muestra el error mientras no hay red y la lista se recupera sola al volver | | | |

## 9.3 Conflicto: dos dispositivos modifican la misma incidencia

| ID | Escenario | Pasos y datos | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| P9-18 | Edición simultánea del texto | A y B entran como `user1` y abren el detalle de I1 (misma versión). A edita el título y guarda; después B edita la descripción y guarda **sin recargar** | A: "Cambios guardados". B: "El registro fue modificado desde otro dispositivo" con el botón **Recargar**; el cambio de B no se guarda | | | |
| P9-19 | Recargar después del conflicto | En B, tocar **Recargar** tras P9-18 | B muestra el título nuevo de A y la versión nueva; ahora B puede guardar su cambio | | | |
| P9-20 | Estado contra prioridad | A (`admin1`) y B (`agente1`) abren I1. A cambia la prioridad y, sin recargar, B cambia el estado | El primero se guarda; el segundo recibe el aviso de conflicto 409 | | | |
| P9-21 | Conflicto por API | Leer I1 (versión N). Enviar `PUT` con `version: N` (éxito) y repetir el mismo `PUT` con `version: N` | 1.º: 200 con `version: N+1`. 2.º: 409 `{"mensaje":"El registro fue modificado desde otro dispositivo"}` | | | |
| P9-22 | Verificación en la BD | Después de P9-18, consultar I1 en PostgreSQL | El título es el de A y la descripción es la anterior (no la de B); `version` subió solo una vez | | | |

---

# Práctica 10 — Seguridad y autorización

## 10.1 Usuario A contra incidencias del usuario B

`user1` es el usuario A e intenta usar la incidencia **I2**, creada por `user2` (usuario B) y sin asignar a `agente1`.

| ID | Escenario | Petición (con el token de `user1`) | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| P10-01 | Listar | `GET /api/incidencias` | 200; la lista **no** incluye I2 | | | |
| P10-02 | Ver detalle ajeno | `GET /api/incidencias/{I2}` | 403 `{"mensaje":"No tienes permiso para realizar esta acción"}` | | | |
| P10-03 | Editar ajena | `PUT /api/incidencias/{I2}` con un título nuevo y la versión correcta | 403; el título de I2 no cambia en la BD | | | |
| P10-04 | Eliminar ajena | `DELETE /api/incidencias/{I2}` | 403; I2 sigue existiendo | | | |
| P10-05 | Leer el chat ajeno | `GET /api/incidencias/{I2}/mensajes` | 403 | | | |
| P10-06 | Escribir en el chat ajeno | `POST /api/incidencias/{I2}/mensajes` con `{"texto":"hola"}` | 403; no se crea el mensaje | | | |
| P10-07 | Canal interno de su propia incidencia | `GET /api/incidencias/{I1}/mensajes?canal=INTERNO` | 403 (el creador solo usa PUBLICO) | | | |
| P10-08 | Cambiar el creador | `PUT /api/incidencias/{I1}` con `"creadoPor":"<correo de user2>"` | 403; el creador de I1 sigue siendo `user1` | | | |
| P10-09 | Agente no asignado | Con el token de `agente1`: `GET /api/incidencias/{I2}` | 403 (solo ve las asignadas a él) | | | |
| P10-10 | Agente intenta asignar | Con el token de `agente1`: `PUT /api/incidencias/{I1}/asignar` con `{"agenteId": <id>}` | 403 (solo ADMIN asigna) | | | |
| P10-11 | Agente degradado | `admin1` cambia el rol de `agente1` a USER en la BD; `agente1` usa su token anterior para `GET /api/incidencias/{I1}` | 403 (se usa el rol de la BD, no el del token) | | | |
| P10-12 | En la app | `user1` en el teléfono: buscar I2 en la lista | I2 no aparece; no hay forma de abrirla desde la app | | | |

## 10.2 Crear con un creadoPor ajeno

| ID | Escenario | Petición (con el token de `user1`) | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| P10-13 | creadoPor como correo ajeno | `POST /api/incidencias` con `"creadoPor":"<correo de user2>"` | 403; no se crea ninguna incidencia | | | |
| P10-14 | creadoPor como id ajeno | `POST` con `"creadoPor": <id de user2>` | 403 | | | |
| P10-15 | creadoPor como objeto ajeno | `POST` con `"creadoPor":{"id": <id de user2>}` | 403 | | | |
| P10-16 | creadoPor propio | `POST` con `"creadoPor":"<correo de user1>"` | 201; la incidencia queda a nombre de `user1` | | | |
| P10-17 | Sin creadoPor | `POST` con solo título y descripción | 201; el creador se toma del token (`user1`) | | | |
| P10-18 | Emisor falso en el chat | `POST /api/incidencias/{I1}/mensajes` con `"emisor":"<correo de user2>"` | 201, pero el emisor guardado es `user1` (el campo extra se ignora) | | | |
| P10-19 | Verificación en la BD | Contar las incidencias de `user2` antes y después de P10-13 a P10-15 | El número no cambia | | | |

## 10.3 Acceso sin token o con token inválido

| ID | Escenario | Petición | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| P10-20 | Listar sin token | `GET /api/incidencias` sin el encabezado `Authorization` | 403; no devuelve datos | | | |
| P10-21 | Crear sin token | `POST /api/incidencias` sin token | 403; no se crea nada | | | |
| P10-22 | Chat sin token | `GET /api/incidencias/{I1}/mensajes` sin token | 403 | | | |
| P10-23 | Partidas sin token | `GET /api/partidas/me` sin token | 403 | | | |
| P10-24 | Perfil sin token | `GET /api/users/me` sin token | 403 | | | |
| P10-25 | Token alterado | `GET /api/incidencias` con el token cambiando un carácter de la firma | 403; no devuelve datos | | | |
| P10-26 | Token con texto basura | `Authorization: Bearer abc123` | 403 | | | |
| P10-27 | Usuario normal en rutas de ADMIN | Con el token de `user1`: `GET /api/users` | 403 | | | |
| P10-28 | Rutas públicas | `POST /api/auth/login` sin token | Responde normalmente (no requiere token) | | | |
| P10-29 | En la app | Borrar los datos de la app (o alterar la sesión guardada) y abrirla | Abre en el login; si el servidor responde 401 o 403 sin mensaje, regresa al login con "Tu sesión expiró" | | | |
| P10-30 | Mensajes genéricos | Revisar las respuestas de P10-01 a P10-29 | Ninguna incluye trazas, nombres de clases, consultas SQL ni datos de otro usuario | | | |
| P10-31 | Logs sin datos sensibles | Revisar Logcat de la app durante todas las pruebas | No aparecen contraseñas, tokens ni respuestas completas del servidor | | | |
