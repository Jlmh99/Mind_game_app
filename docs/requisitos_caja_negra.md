# Requisitos verificables para pruebas de caja negra — Mind Games

> **Nota:** la app móvil (Flutter) consume un backend en **Spring Boot** con base de datos
> **PostgreSQL**. Después de iniciar sesión, cada petición lleva un token **JWT** en el
> encabezado `Authorization: Bearer <token>`. **Las reglas de seguridad se aplican en el
> backend:** quién puede ver, editar, asignar o borrar se decide con el usuario y el rol que
> están en la base de datos. Lo que la app oculta o deshabilita es solo ayuda visual; las
> pruebas de permisos deben confirmar que el servidor también lo rechaza.

Cada requisito describe una función que **existe hoy** en la app o en el backend. Los textos
entre comillas son los que muestra la app o devuelve el servidor.

**Roles:** `USER` (usuario normal), `AGENTE` (atiende incidencias asignadas) y `ADMIN`.

## Resumen

| Tipo | Requisitos |
|---|---|
| Operaciones principales | RF-01, RF-02, RF-03, RF-04 |
| Validaciones | RF-05, RF-06, RF-07 |
| Persistencia o consistencia | RF-08, RF-09 |
| Navegación, roles o permisos | RF-10, RF-11 |
| Manejo de errores | RF-12 |
| Adicionales | RF-13, RF-14 |

---

## Operaciones principales

### RF-01 — Iniciar sesión (con verificación en dos pasos si la cuenta la tiene)
- **Entradas:** correo y contraseña (pantalla de inicio de sesión); código de 6 dígitos si la cuenta tiene 2FA.
- **Restricciones:** cuenta existente y habilitada; código vigente 5 minutos y de un solo uso.
- **Salida esperada:**
  - Sin 2FA: entra a la pantalla de inicio "Mind Games".
  - Con 2FA: muestra "Verificación — Enviamos un código a <correo>" y, con el código correcto, entra al inicio.
- **Errores a manejar:** credenciales incorrectas o cuenta inexistente → "Credenciales inválidas" (mensaje genérico, no dice cuál falló); código incorrecto → "Código inválido"; servidor apagado → "No se pudo conectar, intenta de nuevo".
- **Criterio de aceptación:** con credenciales válidas se llega al inicio en un solo envío; con 3 combinaciones inválidas distintas siempre aparece el mismo mensaje genérico y no se entra.

### RF-02 — Crear una incidencia
- **Entradas:** título, descripción y prioridad (Baja, Media, Alta o Crítica; Media por defecto) en "Nueva incidencia".
- **Restricciones:** usuario autenticado; el creador **siempre** es el usuario del token; nace en estado "Pendiente".
- **Salida esperada:** SnackBar "Incidencia creada"; la incidencia aparece en la lista con estado Pendiente y "De: <tu usuario>".
- **Errores a manejar:** sin conexión → "No se pudo completar la acción, intenta de nuevo"; sesión vencida → regreso al login con "Tu sesión expiró".
- **Criterio de aceptación:** tras crearla, aparece 1 incidencia más en la lista y su detalle muestra "Creada por: <tu usuario>", estado Pendiente y "Versión: 0".

### RF-03 — Enviar un mensaje en el chat de una incidencia (con adjunto opcional)
- **Entradas:** texto; opcionalmente una foto (cámara o galería) o un PDF.
- **Restricciones:** texto obligatorio de máximo 1000 caracteres; adjunto JPG, PNG o PDF de máximo 2 MB; canal "Con el usuario" (PUBLICO) o "Interno" (INTERNO).
- **Salida esperada:** SnackBar "Mensaje enviado"; la burbuja aparece a la derecha con "Tú", la hora HH:mm y, si hay adjunto, la miniatura de la imagen o el ícono del PDF con su nombre.
- **Errores a manejar:** sin permiso en el canal → "No tienes permiso para esta acción"; fallo de red → "No se pudo completar la acción, intenta de nuevo", sin perder lo escrito.
- **Criterio de aceptación:** el mensaje enviado se ve en el otro dispositivo al recargar (o en ≤ 3 s si el otro es ADMIN o AGENTE) con el mismo texto, emisor y adjunto.

### RF-04 — Guardar el resultado de una partida (Sudoku o Crucigrama)
- **Entradas:** completar el tablero.
- **Restricciones:** puntuación de Sudoku = máx(0, 1000 − segundos − 50 × errores); de Crucigrama = máx(0, 1000 − segundos − 25 × errores); el servidor rechaza un tiempo o una puntuación negativos.
- **Salida esperada:** diálogo "¡Sudoku completado!" o "¡Crucigrama completado!" con tiempo, errores y puntuación, y SnackBar "Partida guardada". La partida aparece en "Mi perfil".
- **Errores a manejar:** sin conexión → "No se pudo guardar la partida. Revisa tu conexión."
- **Criterio de aceptación:** la puntuación mostrada coincide con la fórmula para el tiempo y los errores mostrados, y la partida queda como la primera de la lista en "Mi perfil".

## Validaciones

### RF-05 — Validación de los formularios de inicio de sesión y registro
- **Entradas:** nombre de usuario (solo registro), correo y contraseña.
- **Restricciones:** usuario obligatorio y de máximo 30 caracteres; correo obligatorio, de máximo 100 caracteres y con formato `algo@algo.algo`; contraseña obligatoria y de máximo 64 caracteres, con mínimo 8 **solo en el registro**. Un campo con solo espacios cuenta como vacío.
- **Salida esperada:** el formulario no se envía y se muestra el error junto al campo: "Ingresa tu nombre de usuario", "Ingresa tu correo", "Ingresa un correo válido", "Ingresa tu contraseña", "Mínimo 8 caracteres", "Máximo N caracteres".
- **Errores a manejar:** entradas vacías, con solo espacios, demasiado largas o con formato incorrecto.
- **Criterio de aceptación:** ningún dato inválido de la matriz llega al servidor (no aparece el indicador de carga) y cada caso muestra su mensaje exacto.

### RF-06 — Validación del formulario de incidencias
- **Entradas:** título y descripción al crear o editar.
- **Restricciones:** en la app, título obligatorio de máximo 80 caracteres y descripción obligatoria de máximo 500 (sin contar los espacios de los extremos). El backend acepta hasta 150 y 2000 y responde 400 si se rebasan.
- **Salida esperada:** "Escribe un título", "Describe el problema" o "Máximo N caracteres", y la incidencia no se crea.
- **Errores a manejar:** campos vacíos, con solo espacios o demasiado largos; por API, valores de estado o prioridad desconocidos → 400 "Datos no válidos".
- **Criterio de aceptación:** con título o descripción inválidos no se crea ninguna incidencia nueva (el contador de la lista no cambia).

### RF-07 — Validación de mensajes y adjuntos del chat
- **Entradas:** texto del mensaje y archivo adjunto.
- **Restricciones:** texto no vacío, no solo espacios, de máximo 1000 caracteres; adjunto de máximo 2 MB y tipo JPG, PNG o PDF **según los primeros bytes del archivo** (no según la extensión).
- **Salida esperada:** "Escribe un mensaje antes de enviar"; el campo no deja escribir más de 1000 caracteres (contador 1000/1000); un adjunto inválido se rechaza antes de enviarse con "El archivo no debe superar 2 MB" o "Formato no permitido (usa JPG, PNG o PDF)".
- **Errores a manejar:** texto vacío, archivo grande, archivo renombrado (por ejemplo, un `.exe` renombrado a `.png`). En el backend: "El adjunto no debe superar 2 MB", "El contenido del adjunto no coincide con su tipo", "Tipo de archivo no permitido (usa JPG, PNG o PDF)".
- **Criterio de aceptación:** ninguno de los casos inválidos crea un mensaje en el servidor (el otro dispositivo no lo recibe).

## Persistencia y consistencia

### RF-08 — La sesión se conserva al cerrar y abrir la app
- **Entradas:** iniciar sesión, cerrar la app por completo y volver a abrirla; o tocar "Cerrar sesión".
- **Restricciones:** la sesión se guarda en una base local (Floor/SQLite); si el JWT guardado ya venció, no se usa.
- **Salida esperada:** con un token vigente, la app abre directo en el inicio sin pedir datos. Con un token vencido, abre en el login con "Tu sesión expiró". Tras "Cerrar sesión", abre en el login.
- **Errores a manejar:** token vencido o inválido guardado en el teléfono.
- **Criterio de aceptación:** en 3 reaperturas seguidas con token vigente no se pide iniciar sesión; después de "Cerrar sesión" se pide siempre.

### RF-09 — Concurrencia optimista de incidencias (versión)
- **Entradas:** dos dispositivos editan la misma incidencia partiendo de la misma versión.
- **Restricciones:** cada actualización envía la `version` leída; el backend usa `@Version` (JPA) y suma 1 en cada cambio guardado.
- **Salida esperada:** el primero que guarda tiene éxito ("Cambios guardados", "Estado actualizado"…). El segundo recibe 409 y ve "El registro fue modificado desde otro dispositivo" con un botón **Recargar**.
- **Errores a manejar:** 409 por versión vieja; la petición sin versión → 400 "Falta la versión del registro".
- **Criterio de aceptación:** el segundo cambio **no** sobrescribe al primero (en la BD queda el valor del primero) y, tras Recargar, el detalle muestra la versión nueva.

## Navegación, roles y permisos

### RF-10 — Cada rol ve solo sus incidencias
- **Entradas:** abrir "Incidencias" con usuarios de cada rol.
- **Restricciones:** USER ve solo las que creó; AGENTE, solo las asignadas a él; ADMIN, todas. El rol se toma de la base de datos.
- **Salida esperada:** el encabezado dice "Vista de Usuario: tus incidencias", "Vista de Agente: incidencias asignadas a ti" o "Vista de Administrador: todas las incidencias", y la lista coincide.
- **Errores a manejar:** abrir por API una incidencia ajena (`GET /api/incidencias/{id}`) → 403; un id que no existe → 404 "Incidencia no encontrada".
- **Criterio de aceptación:** para cada rol, el número de incidencias de la lista es igual al de la consulta equivalente en PostgreSQL.

### RF-11 — Acciones permitidas según el rol en el detalle y el chat
- **Entradas:** abrir el detalle y el chat de una incidencia con cada rol.
- **Restricciones:**
  - Creador: editar título y descripción, y eliminar.
  - Agente asignado: cambiar el estado.
  - ADMIN: todo, incluida la prioridad y "Asignar a agente".
  - La pestaña "Interno" del chat solo existe para ADMIN y el AGENTE asignado.
- **Salida esperada:** solo aparecen los controles permitidos; si no hay ninguno, "Solo puedes consultar esta incidencia.". Una acción prohibida forzada por API → 403 "No tienes permiso para realizar esta acción", y la app muestra "No tienes permiso para esta acción".
- **Errores a manejar:** 403 del servidor aunque la app haya mostrado el botón (por ejemplo, si cambió el rol).
- **Criterio de aceptación:** para cada rol, las acciones prohibidas no aparecen en la app **y** el backend las rechaza con 403 cuando se intentan por API.

## Manejo de errores

### RF-12 — Sesión vencida y pérdida de conexión
- **Entradas:** usar la app con el backend apagado, sin red o con el token vencido o borrado.
- **Restricciones:** los mensajes deben ser genéricos (sin trazas, URLs ni detalles técnicos) y no deben aparecer tokens ni contraseñas en los logs.
- **Salida esperada:**
  - Sin conexión: "No se pudo conectar, intenta de nuevo" (login), "No se pudieron cargar las incidencias", "No se pudieron cargar los mensajes" o "No se pudo guardar la partida. Revisa tu conexión.", y la app sigue usable.
  - Token vencido (401): se cierra la sesión y se vuelve al login con "Tu sesión expiró".
- **Errores a manejar:** timeout, servidor caído, 401, 403, 500 ("Ocurrió un error, intenta de nuevo" en el backend).
- **Criterio de aceptación:** en ninguno de los casos la app se cierra ni muestra una pantalla roja o gris, y al recuperar la conexión basta con reintentar (o deslizar para recargar) para continuar.

## Requisitos adicionales

### RF-13 — Foto de perfil
- **Entradas:** en "Mi perfil", tomar una foto o elegirla de la galería.
- **Restricciones:** la imagen se comprime en el teléfono; el backend acepta JPG, PNG o WEBP de máximo 2 MB.
- **Salida esperada:** "Actualizando foto..." y luego la foto nueva en el avatar; al volver a abrir el perfil se conserva.
- **Errores a manejar:** permiso de cámara negado → "Sin permiso de cámara no podemos tomar tu foto. Puedes activarlo en Ajustes."; fallo de red → "No se pudo actualizar tu foto" y se queda la foto anterior.
- **Criterio de aceptación:** la foto se ve igual después de cerrar sesión y volver a entrar, y desde otro dispositivo con la misma cuenta.

### RF-14 — Sincronización según el rol
- **Entradas:** tener abierta la lista, el detalle o el chat mientras otro dispositivo hace cambios.
- **Restricciones:** ADMIN y AGENTE se actualizan solos (cada 5 s en la lista y el detalle, cada 3 s en el chat); USER actualiza deslizando hacia abajo. El temporizador se cancela al salir de la pantalla.
- **Salida esperada:** la barra muestra la hora de la última actualización; en el chat aparece "Nuevo mensaje de X" cuando llega un mensaje de otra persona.
- **Errores a manejar:** fallo de red durante una actualización automática (se muestra el error y se reintenta en el siguiente ciclo).
- **Criterio de aceptación:** un cambio hecho en el dispositivo B se ve en el dispositivo A (ADMIN o AGENTE) en ≤ 5 s en la lista y ≤ 3 s en el chat, sin tocar nada.

---

## Requisitos que todavía no se pueden verificar por falta de información

| Tema | Qué falta |
|---|---|
| Duración del JWT | No está documentado cuánto dura el token emitido por el backend, así que no se puede fijar un tiempo exacto para "sesión vencida". Se puede simular borrando o alterando el token. |
| Envío real del código 2FA | Depende de la configuración del servicio de correo (Brevo) y de que la cuenta tenga 2FA activado en la BD; no se sabe qué cuentas de prueba lo tienen. |
| Tiempos de respuesta | No hay un requisito de rendimiento definido (por ejemplo, "responder en menos de 2 s"), así que no hay un umbral medible. |
| Presencia en línea ("conectados") | El backend no informa quién está conectado; el chat solo muestra participantes y el número de mensajes enviados. |
| Abrir o descargar PDFs del chat | La app solo muestra el ícono, el nombre y el tamaño; no los abre. |
| Historial borrado en el servidor | "Limpiar historial" solo oculta los mensajes en este teléfono mientras la app está abierta; no existe borrado de mensajes en el backend. |
| Cambio de rol en caliente | El rol de la app viene del token; si un ADMIN cambia el rol de alguien, la app lo detecta en "Mi perfil" ("Tu rol cambió…") pero el menú no cambia hasta volver a iniciar sesión. Falta definir el comportamiento esperado. |
| Pruebas en dispositivo físico | La cámara, la galería y el selector de PDF solo se han probado con selectores simulados; falta la prueba en un teléfono real con permisos. |
