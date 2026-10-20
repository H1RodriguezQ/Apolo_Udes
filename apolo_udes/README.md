# Apolo UDES — Sistema de Gestión de Ceremonia de Grado

App Flutter para **Android (tablet)**, páginas web públicas y reglas de Cloud
Firestore para administrar las ceremonias de grado de la **Universidad de
Santander (UDES)**.

**Versión:** `2.4.1+1`

---

## 🧭 Arquitectura en una mirada

| Pieza | Papel |
|---|---|
| **Cloud Firestore** | Fuente de verdad. Escucha en vivo (`listener`) y persistencia local activada. |
| **SQLite (sqflite)** | Copia local de trabajo para seguir operando sin conexión; se regenera desde Firestore. |
| **`firestore.rules`** | Segunda capa de validación: aunque la app falle, el servidor rechaza lo inválido. |
| **Páginas `web/*.html`** | HTML plano (sin framework) que se sirve desde Firebase Hosting. |
| **Apps Script (`Codigo.gs`)** | Único que envía correos. La app solo deja solicitudes en cola. |
| **`usuarios/{uid}`** | Perfil y rol de cada usuario; las reglas lo leen para decidir permisos. |

**La app no manda correos ni usa servicios externos de QR.** Escribe documentos
en `solicitudes_correo` (y `correoRegistro: 'pendiente'`), Apps Script los
procesa cada 5 minutos y devuelve `enviado` o `error` en el mismo campo.

---

## 🚀 Módulos

Accesibles desde el menú lateral (`lib/presentation/widgets/sidebar/app_sidebar.dart`):

| Módulo | Funcionalidad | Quién lo ve |
|---|---|---|
| 🔐 **Login** | Autenticación con Firebase Auth (correo + contraseña) | Todos |
| 📊 **Dashboard** | Métricas, gráficas, actividad reciente y acceso a la **Bitácora** | Todos (bitácora: admin) |
| 🎓 **Graduandos** | CRUD + **importar Excel** + **borrar lista** | Admin |
| 📨 **Invitaciones** | Cupos por graduando (máx. 3), invitados y sus códigos | Todos |
| ✅ **Confirmación** | Confirmación de asistencia de los invitados (una sola vez) | Todos |
| 📷 **Control de Acceso** | Escáner QR con cámara + linterna + búsqueda manual | Todos |
| 🔔 **Notificaciones** | Campañas y recordatorios (quedan en cola de correos) | Todos |
| 👥 **Directivos** | Autoridades de la ceremonia | Todos |
| 👥 **Usuarios** | Alta/baja y roles del personal | Admin |
| ⚙️ **Configuración** | Datos de la ceremonia (lugar, dirección, capacidad) | Admin |

Pie del menú lateral:

- **Limpiar datos** — borra los datos locales de la ceremonia (pide confirmación).
- **Cerrar jornada** — fin de turno: deja constancia en la bitácora con los
  accesos del día **y cierra sesión**. No borra ningún dato.
- **Cerrar sesión** — sale sin registrar nada más.

---

## 👤 Roles

El rol vive en `usuarios/{uid}.rol` y solo un administrador lo escribe:

| Rol | Puede |
|---|---|
| `admin` | Todo: graduandos, usuarios, configuración, bitácora, ajustes de reglas. |
| `operador` | Operar su **punto de validación** (registra accesos; no puede editar graduandos). |
| `consulta` | Solo lectura de los datos del evento. |

Además `estado` (`activo` / `inactivo`) anula el acceso sin borrar el perfil.

> No hay credenciales de prueba en el código: cada usuario entra con su cuenta
> institucional de Firebase Auth.

---

## 🗄️ Colecciones de Firestore

| Colección | Contenido | Quién escribe |
|---|---|---|
| `graduandos` | Un graduando por documento (dedupe) | Admin (app o import Excel) |
| `graduandos_publico` | Vista pública mínima para las páginas web | Admin |
| `configuracion` | Datos de la ceremonia | Admin |
| `cupos` | `cupo = graduandoId_número` (ocupado / libre) | App, en transacción |
| `invitados` | Invitados por graduando, con su cupo | Página pública o app |
| `invitados_documentos` | Índice único `graduandoId_documento` | App, en el mismo lote |
| `directivos` | Autoridades de la ceremonia | Admin |
| `validaciones` | Registro de accesos por punto | Operador (inserción única) |
| `usuarios` | Perfiles y roles | Admin |
| `auditoria` | Bitácora de acciones sensibles | App (solo inserción) |
| `solicitudes_correo` | Cola de correos para Apps Script | Admin |

**Los invitados anulados no se borran**: se marcan como `anulada` y sus cupos
se renumeran para que no queden huecos.

---

## 🌐 Páginas web (`web/`)

| Archivo | Uso |
|---|---|
| `index.html` | Arranque de la app Flutter en web |
| `mi-qr.html` | QR del graduando (se dibuja con la librería local `qrcodejs`, sin servicios externos) |
| `confirmar.html` | Confirmación de asistencia del invitado (una sola vez) |
| `invitados.html` | Registro público del invitado: valida **capa 1** antes de escribir |
| `directivos.html` | Panel para directivos con gráficas propias |

`flutter build web --release` copia estas páginas a `build/web`. Para
desplegarlas, ese contenido se lleva a `hosting/` (el `public` de
`firebase.json`) y se ejecuta `firebase deploy --only firestore:rules,hosting`.

---

## 🛡️ Seguridad: validación en dos capas

Un mismo criterio se aplica en **tres sitios** y las pruebas comprueban que
coinciden:

1. `lib/core/validators/validadores_graduando.dart` → formularios e importación.
2. `firestore.rules` → funciones `esCorreo`, `esNombrePersona`, `esDocumento`.
3. `web/invitados.html` → `RE_CORREO`, `RE_DOCUMENTO`, `RE_NOMBRE`.

Otras medidas vigentes:

- **Todo denegado por defecto** en `firestore.rules` (447 líneas), con matriz de
  roles y `exists()`/`get()` sobre el perfil.
- **IDs no predecibles**: se generan en Firestore (nada de `INV001`, cédulas ni
  secuencias adivinables). Ningún código de acceso se repite.
- **Sin credenciales en el código**; `AppConstants.urlEnvioCorreos` está vacía a
  propósito (no hay llamadas a ImgBB ni a servicios de QR de terceros).
- **Sin datos personales** en textos de ayuda: los `hintText` usan ejemplos
  genéricos.
- **Dos escrituras en un mismo commit** cuando hace falta la hora del servidor
  (transacción `cupos` + `invitados` + índice + contador).
- **Acciones sensibles auditadas** con
  `UsuariosService.auditar(autor, accion, tipo:, detalle:)`; la bitácora nunca
  interrumpe la operación principal.

---

## ⚙️ Requisitos

- **Flutter SDK** con Dart `>=3.2.0 <4.0.0`
- **Android SDK** (compilación de APK)
- **JDK 17 o superior** para `flutter build apk` (Gradle) y para el emulador de
  Firestore
- **Firebase CLI** (`npm install -g firebase-tools`) para las pruebas de reglas
- Tablet o dispositivo físico Android para el escáner QR

---

## 📦 Instalación

```bash
flutter pub get
flutter run
```

Compilar:

```bash
flutter build apk --release      # APK para tablet Android
flutter build web --release      # web -> build/web
```

---

## ✅ Verificación (tres capas)

```bash
# 1. Analizador estático (sin errores ni advertencias)
flutter analyze

# 2. Unidad: validadores de la capa 1 (33 pruebas)
flutter test test/validadores_graduando_test.dart

# 3. Reglas de Firestore contra el emulador (53 comprobaciones)
powershell -NoProfile -ExecutionPolicy Bypass -File rules-tests\ejecutar.ps1
```

La suite de reglas usa el proyecto ficticio `demo-apolo`: **no toca producción**
ni requiere iniciar sesión. Detalle en [`rules-tests/README.md`](rules-tests/README.md).

Estado actual: `flutter analyze` → **0 errores, 0 advertencias**, 24 mensajes
informativos preexistentes.

---

## 📥 Importar graduandos desde Excel

### Cómo funciona

1. Ve al módulo **Graduandos**
2. **"Plantilla"** → genera un Excel de muestra y lo comparte
3. Llena el archivo (puedes tener cientos de filas)
4. **"Subir Excel"** → selecciona el archivo y la app importa
5. Verás el resumen: agregados, duplicados y errores fila por fila

### Formato (solo `.xlsx`, máximo 2000 filas por archivo)

| A | B | C | D | E | F | G | H |
|---|---|---|---|---|---|---|---|
| Código | Documento | Nombres | Apellidos | Programa | Facultad | Teléfono | Correo |

**Reglas:**

- La primera fila es encabezado y se ignora.
- `Documento`, `Nombres`, `Apellidos` son **obligatorios**.
- Cada fila pasa por **las mismas validaciones del formulario**; las que no
  cumplen se rechazan con su motivo.
- Los duplicados (mismo documento o mismo código) se ignoran automáticamente.

**"Borrar"** elimina toda la lista de graduandos tras pedir confirmación.

---

## 📷 Control de acceso

1. Abre **Control de Acceso**
2. **"Activar cámara"** (la primera vez Android pide permiso) o escribe el
   documento / código en el campo manual
3. Activa la **linterna** si hay poca luz
4. El sistema verifica, registra el acceso y muestra el resultado

No existen códigos de prueba fijos: cada invitado recibe su propio código,
generado con ID no predecible.

---

## 📚 Estructura del proyecto

```
apolo_udes/
├── lib/
│   ├── core/            # constants, theme, validators (capa 1)
│   ├── data/
│   │   ├── models/      # graduando, invitado, usuario, ...
│   │   └── services/    # auth, firestore, database(SQLite), excel, usuarios
│   ├── providers/       # AppProvider (estado global), ThemeProvider
│   └── presentation/
│       ├── screens/     # un directorio por módulo
│       └── widgets/     # sidebar y componentes comunes
├── web/                 # páginas públicas (HTML)
├── test/                # pruebas de unidad
├── rules-tests/         # pruebas de firestore.rules (emulador)
├── firestore.rules      # capa 2 de validación
├── firebase.json        # hosting + emuladores
└── pubspec.yaml
```

Los archivos `*.dart.bak` son copias de seguridad de versiones anteriores: no
compilan ni se incluyen en el build.

---

## 📬 Dependencias principales

| Paquete | Uso |
|---|---|
| `firebase_core` / `cloud_firestore` | Conexión con Firestore |
| `firebase_auth` | Autenticación |
| `sqflite` | Copia local offline |
| `mobile_scanner` | Lector de QR con cámara |
| `excel` / `file_picker` | Importación de graduandos |
| `share_plus` / `path_provider` | Compartir plantillas y archivos |
| `provider` | Estado global |
| `fl_chart` | Gráficas del dashboard |
| `http` | Aviso al servidor de correos de Apps Script |
| `intl` | Fechas y textos en español |

---

## 🚧 Estado

| Fase | Estado |
|---|---|
| TAREA 1–11 (Firestore offline, códigos, dedupe, anulación, badges, reglas, HTML, cierre de jornada, pruebas) | ✅ Hechas |
| TAREA 12 — empaquetado y despliegue | ⏳ Pendiente: `hosting/`, APK (requiere JDK 17) y `firebase deploy` |

**v2.4.1 — 2026** | Universidad de Santander UDES
