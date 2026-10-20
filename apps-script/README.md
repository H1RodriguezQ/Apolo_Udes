# Servidor de correos (Google Apps Script)

Los correos de Apolo UDES no los manda la tablet: los manda **Google Apps
Script**, que corre en los servidores de Google. La app solo deja una petición
en la colección `solicitudes_correo` de Firestore y este proyecto la procesa.

¿Por qué así? Porque si el correo saliera desde la app, la contraseña del
correo quedaría **dentro del APK**: cualquiera que descomprimiera el archivo
podría leerla. Además, el envío dependería de que la tablet siga encendida y
con datos durante la ceremonia.

## Archivos

| Archivo | Qué hace |
|---|---|
| `Codigo.gs` | Lógica del servidor: lee Firestore, arma el correo con la plantilla y lo manda con GmailApp. |
| `qr.gs` | Genera el PNG del código de acceso (codificador QR propio, sin servicios externos). |
| `plantilla-invitacion.html` | La tarjeta de invitación tal como se ve en el navegador. Fuente única del diseño. |
| `sincronizar-plantilla.js` | Copia el HTML dentro de la constante `PLANTILLA` de `Codigo.gs`. |
| `appsscript.json` | Ajustes del proyecto: zona horaria y permisos que se piden. |
| `test/` | Pruebas locales con Node (renderizador y QR). |

## Instalación

1. Abrir <https://script.google.com> → **Nuevo proyecto**.
2. Pegar el contenido de `Codigo.gs` en un archivo y el de `qr.gs` en otro
   (el editor los llama "Archivos"): **Archivo → Importar** o crearlos desde
   el menú **+**.
3. Subir `appsscript.json`: en **Ajustes del proyecto** activar
   *"Mostrar el archivo de manifiesto"* y reemplazarlo por el de esta carpeta.
4. Guardar. Al abrir el proyecto pide permiso: aceptar (pide acceso a Gmail,
   a Firestore vía `datastore` y a las peticiones de red).
5. En **Editor → Despachadores automáticos**: agregar despachador, función
   `enviarCorreos`, intervalo **cada 5 minutos**.
6. Probar con el botón **Ejecutar → enviarPruebaInvitacion** (ver abajo).

## Configuración

Al inicio de `Codigo.gs` hay cuatro constantes:

| Constante | Qué es |
|---|---|
| `POLITICA_URL` | URL de la política de tratamiento de datos (Ley 1581). Si queda vacía, el pie sale sin enlace. **No se inventa**: se pega la página oficial. |
| `LOGOS_URL` | URL absoluta del PNG de los logos oficiales ya publicado en Firebase Hosting. Si queda vacía, el correo muestra el texto alternativo de la imagen. |
| `CORREO_PRUEBA` | Correo que recibe la invitación de prueba en un proyecto sin hoja de cálculo. |
| `INSCRIPCION_URL` | Página pública donde el graduando se registra y ve su QR. |

## Cómo probar el correo antes de la ceremonia

1. Poner el propio correo en `CORREO_PRUEBA` y ejecutar
   `enviarPruebaInvitacion` (o usar el menú **Apolo UDES** si el proyecto está
   enlazado a una hoja de cálculo).
2. Revisar el resultado en **tres** sitios, porque cada uno pinta el HTML a su
   manera:
   - Gmail en la web,
   - Gmail en el celular,
   - Outlook (el más exigente con las tablas y las fuentes).
3. Comprobar que: el QR se ve y se lee con la cámara, el nombre aparece bien
   escapado, la fecha y la hora coinciden con la de `configuracion/evento`, y
   el asunto trae el número de ceremonia.

## Cambiar el diseño del correo

1. Editar `plantilla-invitacion.html` (se puede abrir en el navegador para
   ver cómo queda).
2. Ejecutar `node sincronizar-plantilla.js`.
3. Volver a pegar `Codigo.gs` en el proyecto de Apps Script.

Las reglas del diseño de correo, por si se toca la plantilla:

- todo con **tablas** y **estilos en línea**; el bloque `<style>` solo puede
  contener las reglas `@media` de 520px y 360px (Outlook ignora las clases),
- el QR va con `<img src="cid:qr">`: **nunca** con `data:base64` (Gmail lo
  bloquea) ni apuntando a un servicio externo,
- siempre debe existir una versión en texto plano (la arma `textoPlano`).

## Pruebas locales

```bash
cd test
npm install
npm test
```

`plantilla.test.js` comprueba el renderizador: que reemplace las marcas, que
escape un `<script>` escrito en un nombre, que no deje ninguna `{{` y que el
bloque de estilos solo tenga `@media`.

`qr.test.js` comprueba el QR de verdad: genera el código, lo dibuja como imagen
y lo **lee de vuelta con jsQR** (una librería ajena, la misma idea que usan
los escáneres). Si jsQR devuelve el texto exacto, un celular lo va a poder
leer. También valida el PNG byte a byte (firma, CRC y compresión).

## Seguridad y datos personales

- El correo **no** lleva cédula ni teléfono: solo nombre del invitado,
  graduando, programa, datos de la ceremonia y el código de acceso.
- El contenido del correo y el código QR **nunca** se escriben en los
  registros de ejecución (`Logger`): solo se registra si algo falló.
- Las reglas de Firestore le prohíben a la app avanzar el estado de una
  solicitud de correo: mentir sobre el estado taparía un fallo de envío. Solo
  este servidor (con la cuenta de servicio) puede marcar `estado` y `enviados`.
