# Fortalecimiento de seguridad (noviembre de 2026)

Medidas agregadas después del análisis STRIDE. Todas funcionan en el plan
gratuito de Firebase. Las que necesitan una clave quedan **apagadas** hasta
que se configure, así la app nunca deja de funcionar a mitad de camino.

| ID | Medida | Qué evita | Estado |
|---|---|---|---|
| S-13 | App Check (reCAPTCHA v3 en la web, token por tablet) | Que un script con la configuración copiada lea o escriba en Firestore | Listo en el código; falta la clave y activar el control |
| S-14 | Encabezados de seguridad en la web | Que otra página meta Apolo en un marco para engañar al usuario (clickjacking), que el navegador adivine tipos de archivo, y que se filtre la dirección con el ID del invitado | Activo al publicar |
| S-15 | APK firmada con llave propia | Que alguien instale una APK falsa encima de la real | Listo; falta crear la llave (una vez) |
| S-16 | Código ofuscado en la APK | Que se lea fácil el código si sacan la APK de una tablet | Activo con `scripts\compilar.ps1 apk` |
| S-17 | Cierre de sesión del administrador tras 15 min sin uso | Que alguien use la cuenta del admin en un equipo que quedó abierto | Activo, con 3 pruebas automáticas |
| S-18 | Respaldo manual de la base (`respaldo.js`) | Perder datos si algo se borra por error (el plan gratis no tiene copias) | Activo; correrlo antes de cada ceremonia |
| S-19 | El nombre del graduando guardado en el invitado tiene que ser el real | Que alguien registre invitados con un nombre de graduando inventado, que luego sale en las listas | Activo en las reglas, con prueba |
| S-20 | Fecha de cierre del registro de invitados (Ajustes) | Que se sigan registrando invitados hasta el día del grado con un enlace reenviado | Activo en las reglas, con 2 pruebas; la fecha la pone el admin |

## Pasos que hace el administrador (una sola vez)

### 1. Llave propia para la APK (S-15)
```powershell
cd C:\Apolo-Udes\apolo_udes
powershell -ExecutionPolicy Bypass -File scripts\crear-llave-apk.ps1
```
Guarda una copia de `C:\Apolo-Udes\claves\apolo-tablets.jks` y de la
contraseña fuera del computador. La primera vez hay que desinstalar la app
vieja de cada tablet, porque cambia la firma.

### 2. App Check (S-13)
1. Firebase Console → **App Check** → **Apps**.
2. App web: registrar con **reCAPTCHA v3**. Google da una clave del sitio
   (empieza por `6L`). Guardarla en `C:\Apolo-Udes\claves\recaptcha-key.txt`
   y pegarla en la constante `CLAVE_RECAPTCHA` de `web/invitados.html`,
   `confirmar.html`, `directivos.html` y `mi-qr.html`.
3. App Android: registrar con **Play Integrity** (lo pide la consola), luego
   en el menú de la app → **Administrar tokens de depuración** → crear uno.
   Guardarlo en `C:\Apolo-Udes\claves\appcheck-token.txt`.
   *Por qué depuración:* las tablets no instalan la app desde Play Store, y
   Play Integrity solo reconoce apps de la tienda. El token va dentro de la
   APK, así que la protección en Android es menor que en la web; se acepta
   porque las tablets son de la universidad y la APK no se publica.
4. Compilar con `scripts\compilar.ps1 apk` y `scripts\compilar.ps1 web`, y publicar.
5. Esperar unos días mirando **App Check → Métricas**. Cuando casi todas las
   peticiones salgan como *verificadas*, pulsar **Aplicar** en Cloud Firestore.
   Antes no: si se aplica sin las claves, la app y las páginas dejan de funcionar.

### 3. Cierre del registro (S-20)
En **Ajustes → Cierre del registro de invitados** se elige el último día. Desde
el día siguiente la página muestra *"El registro de invitados está cerrado"* y
las reglas rechazan cualquier registro, aunque alguien intente saltarse la página.
El administrador puede seguir agregando invitados desde la app.

### 4. Respaldo antes de cada ceremonia (S-18)
```powershell
cd C:\Apolo-Udes\admin-scripts
node respaldo.js
```

## Lo que no se hizo y por qué
- **Política de seguridad de contenido (CSP):** Flutter web necesita permisos
  amplios para su motor gráfico; una CSP mal puesta deja la web en blanco. Se
  deja para cuando se pueda probar con calma.
- **Verificación en dos pasos y copias automáticas:** exigen el plan de pago.
- **Verificar el correo de cada invitado o poner captcha en el registro:** se
  consideró exagerado. Cada graduando tiene máximo 2 o 3 cupos, así que el
  abuso posible ya está limitado, y App Check frena a los scripts.
