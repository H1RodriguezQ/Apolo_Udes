/**
 * plantilla.test.js
 * ---------------------------------------------------------------------------
 * Pruebas del renderizador de la plantilla de invitación (Codigo.gs).
 *
 * Son la versión local de la prueba que el servidor lleva dentro (menú →
 * "Probar renderizador"): sirven para revisar el correo en el computador
 * antes de pegar el código en Apps Script.
 *
 * Se ejecutan con:  npm test
 */
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Codigo.gs está escrito para Apps Script, pero no usa ningún servicio de
// Google al cargarse, así que se puede leer directamente en Node.
const codigo = fs.readFileSync(path.join(__dirname, '..', 'Codigo.gs'), 'utf8');
const contexto = vm.createContext({});
vm.runInContext(codigo, contexto);

const { renderPlantilla, prepararPlantilla, escaparHtml } = contexto;
// PLANTILLA es una constante: no aparece en el objeto global, pero se puede
// evaluar dentro del mismo contexto.
const PLANTILLA = vm.runInContext('PLANTILLA', contexto);

/** Datos completos, como los arma el servidor para un invitado normal. */
function datosDePrueba() {
  return {
    invitado: 'Invitado de Prueba',
    graduando: 'Graduando de Prueba',
    programa: 'Ingeniería de Software',
    ceremonia: 'N.º 3',
    fecha: '20 de nov.',
    dia_semana: 'viernes',
    hora: '7:00 p. m.',
    lugar: 'Auditorio Mayor · Campus Lagos del Cacique',
    qr_src: 'cid:qr',
    logos_src: '',
    birrete_src: '',
    esq_si_src: '',
    esq_sd_src: '',
    esq_ii_src: '',
    esq_id_src: '',
    politica_url: '',
    titulo_beneficiario: 'Invitación personal para',
    en_nombre_de: 'en nombre de Graduando de Prueba',
    cargo: '',
    nota_extra: ''
  };
}

/** Renderiza igual que lo hace el servidor antes de mandar. */
function render(datos) {
  return renderPlantilla(prepararPlantilla(datos), datos);
}

test('la plantilla trae todos los marcadores que necesita el correo', () => {
  const marcas = [
    'invitado', 'graduando', 'programa', 'ceremonia', 'fecha', 'dia_semana',
    'hora', 'lugar', 'qr_src', 'logos_src', 'birrete_src',
    'esq_si_src', 'esq_sd_src', 'esq_ii_src', 'esq_id_src', 'politica_url',
    'titulo_beneficiario', 'en_nombre_de', 'cargo', 'nota_extra'
  ];
  for (const marca of marcas) {
    assert.ok(PLANTILLA.includes('{{' + marca + '}}'),
      'falta la marca {{' + marca + '}}');
  }
});

test('reemplaza las marcas y no deja ninguna {{ en el resultado', () => {
  const html = render(datosDePrueba());
  assert.ok(!html.includes('{{'), 'quedó una marca sin reemplazar');
  assert.ok(html.includes('Invitado de Prueba'));
  assert.ok(html.includes('N.º 3'));
  assert.ok(html.includes('Auditorio Mayor · Campus Lagos del Cacique'));
});

test('escapa el HTML que el público pueda escribir en un nombre', () => {
  const datos = datosDePrueba();
  datos.invitado = '<script>alert(1)</script>María & Juan\'s';
  const html = render(datos);

  assert.ok(!html.includes('<script>'), 'pasó una etiqueta <script> sin escapar');
  assert.ok(html.includes('&lt;script&gt;'), 'no escapó el símbolo <');
  assert.ok(html.includes('&amp;'), 'no escapó el ampersand');
  assert.ok(html.includes('&#39;'), 'no escapó la comilla simple');
});

test('si faltan datos obligatorios escribe el texto de relleno', () => {
  const datos = datosDePrueba();
  datos.lugar = '';
  const html = render(datos);
  assert.ok(html.includes('Por confirmar'), 'no puso el texto de relleno');
  assert.ok(!html.includes('{{'), 'dejó una marca visible');
});

test('las marcas opcionales vacías no escriben texto de relleno', () => {
  const datos = datosDePrueba(); // cargo, en_nombre_de y nota_extra vacíos
  const html = render(datos);
  assert.ok(!html.includes('Por confirmar'),
    'un campo opcional vacío no debe verse como "Por confirmar"');
});

test('sin URL de logos quita la imagen y el pie queda sin enlace', () => {
  const datos = datosDePrueba();
  const html = render(datos);
  assert.ok(!/<img[^>]*logos_src/.test(html),
    'quedó una <img> con la fuente vacía');
  assert.ok(!html.includes('<a '), 'quedó un enlace sin destino');
  assert.ok(html.includes('Política de tratamiento de datos'));
});

test('con URL de logos y de política, se quedan la imagen y el enlace', () => {
  const datos = datosDePrueba();
  datos.logos_src = 'https://apolo-udes.web.app/assets/logos-udes-azul.png';
  datos.birrete_src = 'https://apolo-udes.web.app/assets/birrete.png';
  datos.esq_si_src = 'https://apolo-udes.web.app/assets/esquina-sup-izq.png';
  datos.esq_id_src = 'https://apolo-udes.web.app/assets/esquina-inf-der.png';
  datos.politica_url = 'https://apolo-udes.web.app/politica-de-datos';
  const html = render(datos);
  assert.ok(html.includes('src="https://apolo-udes.web.app/assets/logos-udes-azul.png"'));
  assert.ok(html.includes('src="https://apolo-udes.web.app/assets/birrete.png"'),
    'faltó el birrete PNG');
  assert.ok(html.includes('src="https://apolo-udes.web.app/assets/esquina-sup-izq.png"'),
    'faltó la esquina superior izquierda');
  assert.ok(html.includes('src="https://apolo-udes.web.app/assets/esquina-inf-der.png"'),
    'faltó la esquina inferior derecha');
  assert.ok(html.includes('href="https://apolo-udes.web.app/politica-de-datos"'));
  assert.ok(html.includes('alt="Universidad de Santander'), 'faltó el texto alternativo');
});

test('el QR va como imagen en línea (cid:qr), nunca como data:base64', () => {
  const html = render(datosDePrueba());
  assert.ok(html.includes('<img src="cid:qr"'), 'faltó la imagen con cid:qr');
  assert.ok(!html.includes('data:image'), 'un data:base64 lo bloquea Gmail');
});

test('el preheader oculto y el asunto usan la fecha del evento', () => {
  const html = render(datosDePrueba());
  assert.ok(html.includes('Su código de acceso para la ceremonia del 20 de nov.'));
  assert.ok(html.includes('mso-hide:all'), 'el preheader debe ocultarse');
});

test('el bloque <style> solo contiene reglas @media', () => {
  const bloque = (PLANTILLA.match(/<style>[\s\S]*?<\/style>/) || [''])[0];
  assert.ok(bloque.includes('@media'), 'faltan las reglas responsive');

  // Quita cada bloque @media balanceando llaves: lo que quede debe ser vacío.
  let sinMedia = '';
  for (let i = 0; i < bloque.length;) {
    if (bloque.startsWith('@media', i)) {
      let nivel = 0;
      let k = bloque.indexOf('{', i);
      for (; k < bloque.length; k++) {
        if (bloque[k] === '{') nivel++;
        else if (bloque[k] === '}') { nivel--; if (nivel === 0) break; }
      }
      i = k + 1;
    } else {
      sinMedia += bloque[i];
      i++;
    }
  }
  sinMedia = sinMedia.replace(/<\/?style>/g, '').replace(/\s+/g, '');
  assert.strictEqual(sinMedia, '',
    'el bloque <style> debe servir solo para los @media responsive');
});

test('el pie menciona la Ley 1581 y el graduando que registró al invitado', () => {
  const html = render(datosDePrueba());
  assert.ok(html.includes('Ley 1581 de 2012'));
  assert.ok(html.includes('Graduando de Prueba lo registró como invitado'));
});

test('escaparHtml cubre los cinco caracteres peligrosos', () => {
  assert.strictEqual(escaparHtml('&<>"\''), '&amp;&lt;&gt;&quot;&#39;');
  assert.strictEqual(escaparHtml(null), '');
});
