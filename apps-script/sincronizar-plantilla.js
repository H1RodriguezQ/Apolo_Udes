/**
 * sincronizar-plantilla.js
 * ---------------------------------------------------------------------------
 * Copia el contenido de plantilla-invitacion.html dentro de la constante
 * PLANTILLA de Codigo.gs.
 *
 * ¿Por qué existe? Porque el proyecto de Apps Script no puede leer archivos
 * de este repositorio en tiempo de ejecución: la plantilla tiene que vivir
 * dentro del .gs. Pero tampoco queremos dos copias que se puedan desincronizar.
 *
 * Flujo de trabajo para cambiar el diseño del correo:
 *   1. Editar plantilla-invitacion.html (se puede abrir en el navegador).
 *   2. Ejecutar:  node sincronizar-plantilla.js
 *   3. Copiar Codigo.gs y qr.gs al proyecto de Apps Script.
 *
 * No usa dependencias externas: solo el módulo fs de Node.
 */
const fs = require('fs');
const path = require('path');

const carpeta = __dirname;
const rutaHtml = path.join(carpeta, 'plantilla-invitacion.html');
const rutaCodigo = path.join(carpeta, 'Codigo.gs');

const html = fs.readFileSync(rutaHtml, 'utf8').replace(/\r\n/g, '\n');

// Codigo.gs incrusta el HTML en una cadena entre comillas invertidas. Si el
// HTML trajera una comilla invertida o la secuencia ${ rompería el archivo,
// así que se corta por seguridad y se explica qué hacer.
if (html.indexOf('`') !== -1 || html.indexOf('${') !== -1) {
  console.error('ERROR: plantilla-invitacion.html contiene ` o ${.');
  console.error('Quita esas secuencias del HTML y vuelve a ejecutar.');
  process.exit(1);
}

const inicio = 'const PLANTILLA = `';
const fin = '`;';

let codigo = fs.readFileSync(rutaCodigo, 'utf8');
const i = codigo.indexOf(inicio);
if (i === -1) {
  console.error('ERROR: no se encontró "const PLANTILLA = `" en Codigo.gs');
  process.exit(1);
}
const j = codigo.indexOf(fin, i + inicio.length);
if (j === -1) {
  console.error('ERROR: la constante PLANTILLA de Codigo.gs no está cerrada.');
  process.exit(1);
}

const nuevo = codigo.slice(0, i + inicio.length) + html + codigo.slice(j);
fs.writeFileSync(rutaCodigo, nuevo, 'utf8');

console.log('PLANTILLA sincronizada: ' + html.length + ' caracteres.');
console.log('Siguiente paso: copia Codigo.gs y qr.gs al proyecto de Apps Script.');
