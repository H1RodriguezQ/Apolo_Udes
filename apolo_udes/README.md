# Apolo UDES — Sistema de Gestión de Ceremonia de Grado

App Flutter completa para gestionar ceremonias de grado de la **Universidad de Santander (UDES)**.

---

## 🚀 Módulos

| Módulo | Funcionalidad |
|---|---|
| 🔐 **Login** | Autenticación institucional |
| 📊 **Dashboard** | Métricas, gráficas, actividad reciente |
| 🎓 **Graduandos** | CRUD + **importar Excel** + **borrar lista** |
| 📨 **Invitaciones** | Gestión de invitaciones por graduando |
| ✅ **Confirmación** | Estado de confirmaciones de asistencia |
| 📷 **Control de Acceso** | **Escáner QR real con cámara** + linterna |
| 🔔 **Notificaciones** | Campañas de mensajes |
| 👥 **Usuarios** | Administración del personal |

---

## ⚙️ Requisitos

- **Flutter SDK** 3.2.0+
- **Android SDK** API 21+ (Android 5.0+)
- Dispositivo físico Android (para QR)

---

## 📦 Instalación

```bash
flutter pub get
flutter run
```

Para compilar APK:
```bash
flutter build apk --release
```

---

## 📥 Importar Graduandos desde Excel

### Cómo funciona

1. Ve al módulo **Graduandos**
2. Presiona **"Plantilla"** → la app genera un Excel de muestra y lo comparte (guárdalo donde prefieras)
3. Llena el Excel con tus datos siguiendo el formato (puedes tener cientos o miles de filas)
4. Vuelve a la app y presiona **"Subir Excel"**
5. Selecciona el archivo → la app importa todos los graduandos automáticamente
6. Verás un resumen: agregados, duplicados, errores

### Formato del Excel

| A | B | C | D | E | F | G | H | I |
|---|---|---|---|---|---|---|---|---|
| Código | Documento | Nombres | Apellidos | Programa | Facultad | Teléfono | Correo | Hora |
| 2019115023 | 1098765432 | Valentina | Ramírez | Medicina | C. de la Salud | 3001234567 | v.r@udes.edu.co | 08:00 AM |

**Reglas:**
- La primera fila debe ser de encabezados (se ignora)
- `Documento`, `Nombres`, `Apellidos` son **obligatorios**
- Los duplicados (mismo documento o código) se ignoran automáticamente
- Acepta `.xlsx` y `.xls`

### Borrar lista completa

Presiona **"Borrar lista"** → pide confirmación → elimina todos los graduandos.

---

## 📷 Escáner QR Real

1. Ve al módulo **Control de Acceso**
2. Presiona **"Activar cámara"** (la primera vez Android pedirá permiso)
3. Apunta al código QR del invitado
4. El sistema verifica, registra el acceso y muestra resultado verde/rojo
5. Activa la **linterna** si hay poca luz

### Códigos QR de prueba

| Código | Resultado |
|---|---|
| `QR-INV001` | ✅ Acceso permitido - José Ramírez |
| `QR-INV002` | ✅ Acceso permitido - María Ortiz |
| `QR-INV006` | ✅ Acceso permitido - Gloria Méndez |
| `QR-INV007` | ✅ Acceso permitido - Raúl Hernández |
| (cualquier otro) | ❌ Acceso denegado |

---

## 📦 Dependencias principales

| Paquete | Uso |
|---|---|
| `mobile_scanner` | Escáner QR real |
| `excel` | Lectura/escritura .xlsx |
| `file_picker` | Selector de archivos |
| `share_plus` | Compartir plantilla |
| `path_provider` | Directorios del sistema |
| `permission_handler` | Permisos cámara |
| `provider` | Estado global |
| `fl_chart` | Gráficas |
| `intl` | Fechas en español |

---

## 🔑 Credenciales

| Campo | Valor |
|---|---|
| Correo | `admin@udes.edu.co` |
| Contraseña | cualquiera (demo) |

---

**v2.4.1 - 2026** | Universidad de Santander UDES
