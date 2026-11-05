# Análisis de amenazas de Apolo UDES (STRIDE)

Revisión hecha en noviembre de 2026 sobre la versión del repositorio con los
arreglos de seguridad (QR de un solo uso, borrado local al cerrar jornada,
Storage cerrado y regeneración de códigos).

## 1. Qué se protege

| Activo | Dónde está | Por qué importa |
|---|---|---|
| Datos personales de graduandos e invitados (nombre, cédula, correo, teléfono) | Firestore `graduandos`, `invitados`, `directivos` | Ley 1581 de 2012 (protección de datos personales) |
| Códigos QR de acceso | Campo `codigoQr`, correos de Apps Script | Quien tenga un código válido entra a la ceremonia |
| Registro de entradas | `usos`, `validaciones`, `auditoria` | Prueba de quién entró, por dónde y quién lo validó |
| Cuentas del personal | Firebase Auth + `usuarios/{uid}` | El rol decide qué puede ver y hacer cada persona |
| Llave de servicio | `C:\Apolo-Udes\claves\serviceAccount.json` | Salta todas las reglas; nunca se sube al repositorio |

## 2. Límites de confianza

1. **Internet → páginas públicas** (`invitados.html`, `confirmar.html`, `directivos.html`):
   cualquiera puede abrirlas. Solo leen documentos sueltos por ID (`get`), nunca listas.
2. **Tablet o web del personal → Firestore**: cada petición pasa por `firestore.rules`,
   que lee el rol en `usuarios/{uid}`. Todo lo que no está permitido se niega.
3. **Scripts de administración → Firestore**: usan la llave de servicio y no pasan por
   las reglas. Solo se corren desde el computador del administrador.
4. **Apps Script → correo**: envía los códigos a los graduandos, invitados y directivos.

## 3. Amenazas y controles

| ID | STRIDE | Amenaza | Control | Evidencia | Estado |
|---|---|---|---|---|---|
| S-01 | Elevación de privilegios, Repudio | Un mismo QR entra dos veces si dos tablets lo leen casi al mismo tiempo | `usos/{codigo}` solo se puede **crear** (reglas) y la app lo crea antes de aceptar (`_reservarUso`) | Pruebas de reglas sección I (8/8) y prueba de carga B (200 códigos a la vez, 0 entradas dobles) | Corregido |
| S-02 | Divulgación de información | Al cerrar la jornada, los datos personales quedaban guardados en la tablet | `cerrarJornada()` borra SQLite y la caché de Firestore (`clearPersistence`) | Captura de la tablet sin internet antes y después | Corregido |
| S-03 | Manipulación, Divulgación | `storage.rules` permitía leer y escribir a cualquiera | Reglas en `if false` y se quitó `firebase_storage` de la app | Archivo de reglas desplegado | Corregido |
| S-04 | Suplantación | Códigos viejos adivinables (`DIR-{id}-{hora}`) e imagen del QR en un servicio externo | Códigos nuevos de 26 caracteres con `Random.secure`; `regenerar-codigos.js` cambió los viejos y borró `qrUrl` | Salida del script antes (9 códigos viejos) y después (0) | Corregido |
| S-05 | Suplantación | Cualquiera puede crearse una cuenta en Firebase Auth | Una cuenta sin perfil en `usuarios/{uid}` no lee ni escribe nada (prueba "usuario autenticado sin perfil no lee nada"). El registro no se apaga porque el panel de administración crea las cuentas desde la app y el plan gratuito no tiene Cloud Functions | Pruebas de reglas sección B | Riesgo aceptado |
| S-06 | Suplantación | Llaves de API web y Android sin restricciones | Restringir por dominio (`apolo-udes.web.app`) y por paquete y huella SHA-1 de la app Android en Google Cloud | Captura de las restricciones | Pendiente |
| S-07 | Manipulación | Volver a correr `crear-espejo-publico.js` reiniciaba `cuposUsados` y borraba `invitadosPermitidos`, lo que dejaba registrar más invitados de la cuenta o bloqueaba el tercer cupo | El script escribe con `merge` y copia `invitadosPermitidos` | Revisión del código | Corregido |
| S-08 | Denegación de servicio | `asignar-rol.js` asignaba el rol `visualizador`, que las reglas no reconocen: la cuenta quedaba sin acceso | Roles iguales a las reglas: `admin`, `operador`, `consulta` | Revisión del código | Corregido |
| S-09 | Divulgación de información | Diez documentos de prueba tienen IDs que se pueden adivinar (hora en milisegundos o `XLSX...`) | Borrarlos antes de la ceremonia de enero | Lista que imprime `regenerar-codigos.js` | Pendiente |
| S-10 | Repudio | Un operador niega haber validado una entrada | `validaciones` y `auditoria` son de solo inserción, con `operadorId == uid` y hora del servidor | Pruebas de reglas secciones E y F | Controlado desde el diseño |
| S-11 | Divulgación de información | Alguien descarga la lista completa de graduandos o invitados | `list` negado a anónimos; solo el personal con perfil activo lista | Pruebas de reglas sección A | Controlado desde el diseño |
| S-12 | Denegación de servicio | Se cae internet durante la ceremonia | La tablet sigue validando con su caché y envía los usos al volver la conexión | Prueba en la tablet en modo avión | Por probar |

## 4. Riesgos que quedan

- **S-12 y el uso único sin internet.** Si una tablet está sin conexión, no puede
  preguntarle al servidor si el código ya se usó en la otra entrada. Acepta el código
  según su lista local y lo reporta al volver la conexión. El riesgo es bajo porque las
  dos entradas tienen buena señal y la ventana es de segundos, pero hay que decirlo en
  el libro.
- **S-05.** Se puede cerrar del todo si en el futuro se pasa al plan Blaze y la
  creación de cuentas se hace con una Cloud Function.
- **Llave de servicio.** Hay una copia vieja en `C:\apolo_udes_fix\claves`, que se debe
  borrar. La buena queda solo en `C:\Apolo-Udes\claves`.

## 5. Cómo se verificó

- `rules-tests\ejecutar.ps1`: 61 comprobaciones contra el emulador con las reglas reales, 0 fallos.
- `pruebas-carga\ejecutar.ps1`: flujo normal con 110, 500 y 1000 asistentes, doble escaneo
  simultáneo y estrés con 50 lecturas a la vez.
- Revisión del historial de git: no hay llaves ni contraseñas subidas.
- Pruebas manuales en la tablet (capturas en `docs/evidencias/`).
