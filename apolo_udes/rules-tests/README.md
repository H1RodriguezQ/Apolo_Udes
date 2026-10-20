# Pruebas de `firestore.rules` (capa 2)

`firestore.rules` es la **segunda capa de validación**: la primera vive en la
app (`lib/core/validators/validadores_graduando.dart`) y en la página pública
(`web/invitados.html`). Este directorio comprueba que las reglas hacen lo que
la app asume y que no se cuela nada por el lado del servidor.

Todo corre contra el **emulador de Firestore con las reglas reales del
proyecto**: no hay peticiones a producción ni datos personales reales.

## Cómo se ejecuta

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File rules-tests\ejecutar.ps1
```

Sale con código distinto de 0 si alguna comprobación falla, y por eso sirve
también como paso de verificación antes de desplegar (`firebase deploy
--only firestore:rules`).

**Requisitos:** Java 17 o superior (lo necesita el emulador; se busca en el
`PATH`, en `JAVA_HOME`, en `APPOLO_JAVA_HOME` y, como último recurso, en un
JRE portátil) y el CLI de Firebase (`npm install -g firebase-tools`). No
requiere iniciar sesión en Firebase: el proyecto se llama `demo-apolo`, que es
un identificador de demostración y por eso nunca toca la nube.

## Qué comprueba (53 casos)

| Bloque | Cubre |
| --- | --- |
| A | Denegación por defecto y documentos realmente públicos (`graduandos_publico`, `configuracion`, `invitados` de la página de confirmación) |
| B | Matriz de roles sobre `graduandos`: consulta, operador, admin, perfil inactivo y usuario sin perfil |
| C | `configuracion` solo la escribe el administrador |
| D | `usuarios`: lectura propia vs ajena, creación válida, correo inválido, operador sin punto de validación, no autoeliminarse |
| E | `validaciones`: solo inserción, solo el propio `puntoValidacion`, `operadorId` propio y sin borrado ni edición (sin repudio) |
| F | `auditoria`: claves exactas, autor propio, lectura solo de admin, no admite ediciones |
| G | `solicitudes_correo`: solo admin, sin saltos de línea en el asunto, solo petición nueva (nunca marcar como enviada) |
| H | Registro público: lote completo (cupo + índice único + invitado + contador), validadores de nombre/correo/documento, y confirmación de asistencia **una sola vez** |

## Notas técnicas (por qué está escrito así)

- **Autenticación:** el emulador acepta JWT con `alg: "none"` y toma `sub` como
  `uid`, así se emula a cada rol sin necesitar el emulador de Auth. `Bearer
  owner` es la llave de administrador del emulador y se usa solo para sembrar
  los datos de partida (los perfiles `usuarios/{uid}`: las reglas leen el rol
  desde ahí).
- **Hora del servidor:** en REST no existe `serverTimestamp`. Van **dos
  escrituras sobre el mismo documento en el mismo commit**: primero los campos
  y luego el `transform` con `setToServerValue: REQUEST_TIME`, porque en el
  proto `Write.update` y `Write.transform` pertenecen al mismo `oneof` y no
  pueden ir en la misma escritura.
- **Máscaras:** `updateMask` va como hermano de `update` dentro del `Write`,
  nunca dentro del `Document`.
- **Repetibilidad:** los IDs llevan la marca de tiempo del arranque (`$run`),
  así la suite se puede ejecutar tantas veces como se quiera aunque el
  emulador conserve los datos entre arranques.

## Relación con la capa 1

Si se cambia un patrón de validación hay que cambiarlo en **los tres sitios**
y volver a correr ambas pruebas:

1. `lib/core/validators/validadores_graduando.dart` → `flutter test test/validadores_graduando_test.dart`
2. `firestore.rules` (funciones `esCorreo`, `esNombrePersona`, `esDocumento`) → `rules-tests\ejecutar.ps1`
3. `web/invitados.html` (`RE_CORREO`, `RE_DOCUMENTO`, `RE_NOMBRE`, `esDocumentoFicticio`)
