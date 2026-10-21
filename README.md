<p align="center">
  <img src="apolo_udes/docs/capturas/banner.png" alt="Apolo UDES · Control de acceso con código QR para las ceremonias de grado de la Universidad de Santander">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-Android%20%7C%20Web-02569B?logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Firebase-Firestore%20%C2%B7%20Auth%20%C2%B7%20Hosting-FFCA28?logo=firebase&logoColor=black" alt="Firebase">
  <img src="https://img.shields.io/badge/Google%20Apps%20Script-correos-4285F4?logo=google&logoColor=white" alt="Google Apps Script">
  <a href="https://apolo-udes.web.app"><img src="https://img.shields.io/badge/sitio-apolo--udes.web.app-B8975A" alt="Sitio publicado"></a>
</p>

Sistema de control de acceso con código QR para las ceremonias de grado de la **Universidad de Santander (UDES)**, Bucaramanga.

Proyecto de grado de Ingeniería de Software · Henry Rodríguez Quintero.

---

## ¿Qué hace?

Cada graduando recibe un correo con un enlace personal para registrar a sus invitados. Cada invitado recibe su propia invitación con un código QR de un solo uso. El día de la ceremonia, los operadores escanean ese código en la entrada con una tablet y el sistema indica si la persona puede entrar.

- **App Flutter** (tablet Android y web) para administradores y operadores: graduandos, invitados, directivos, usuarios, bitácora y control de acceso.
- **Páginas web públicas** en Firebase Hosting: registro de invitados, “Mi invitación” y confirmación de directivos.
- **Cloud Firestore** con reglas que niegan todo salvo lo permitido explícitamente.
- **Google Apps Script** como servidor de correos: enlaces de registro e invitaciones con QR.

## 📸 Cómo se ve

Capturas con datos de ejemplo (no son personas reales).

![Páginas públicas en el celular](apolo_udes/docs/capturas/vista-general.png)

| Registro de invitados | Mi invitación | Directivos |
|:---:|:---:|:---:|
| <img src="apolo_udes/docs/capturas/registro-invitados.png" width="240" alt="Registro de invitados"> | <img src="apolo_udes/docs/capturas/mi-invitacion.png" width="240" alt="Mi invitación"> | <img src="apolo_udes/docs/capturas/directivo-confirmar.png" width="240" alt="Confirmación de directivos"> |

| Correo de registro (graduando) | Invitación con QR (invitado) |
|:---:|:---:|
| <img src="apolo_udes/docs/capturas/correo-registro.png" width="320" alt="Correo de registro"> | <img src="apolo_udes/docs/capturas/correo-invitacion.png" width="320" alt="Correo de invitación"> |

## 📁 Contenido del repositorio

| Carpeta | Qué tiene |
|---|---|
| [`apolo_udes/`](apolo_udes/) | App Flutter, páginas web públicas (`web/`) y `firestore.rules`. **Su [README](apolo_udes/README.md) es la documentación principal.** |
| `apolo_udes/test/` | Pruebas de unidad de los validadores |
| `apolo_udes/rules-tests/` | Pruebas de las reglas de Firestore contra el emulador |
| `apolo_udes/deploy/` | Guía de despliegue y limpieza de Firestore |
| [`apps-script/`](apps-script/) | Servidor de correos (Google Apps Script): plantillas, QR e imágenes de los correos |
| `admin-scripts/` | Scripts de Node para tareas de administración |

Las credenciales de servicio van en `claves/`, que **nunca** se sube al repositorio.

## Inicio rápido

```powershell
cd apolo_udes
flutter pub get
flutter run -d chrome
```

Publicar la app web y las páginas públicas:

```powershell
cd apolo_udes
flutter build web
firebase deploy --only hosting
```

Sitio publicado: <https://apolo-udes.web.app>

---

Universidad de Santander · Ingeniería de Software · 2026
