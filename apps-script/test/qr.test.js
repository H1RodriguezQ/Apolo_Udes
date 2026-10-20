/**
 * qr.test.js
 * ---------------------------------------------------------------------------
 * Pruebas del generador del QR (qr.gs).
 *
 * La prueba fuerte es la del medio: el código generado se rasteriza en una
 * imagen y se le de vuelta con jsQR (una implementación ajena, usada en
 * muchos escáneres). Si jsQR devuelve exactamente el texto que se codificó,
 * el QR sirve para un celular de verdad.
 *
 * Se ejecutan con:  npm test
 */
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const zlib = require('node:zlib');

// qr.gs es JavaScript puro: no usa servicios de Apps Script hasta que se pide
// el Blob final, por eso se puede cargar aquí sin más.
const codigo = fs.readFileSync(path.join(__dirname, '..', 'qr.gs'), 'utf8');
const contexto = vm.createContext({});
vm.runInContext(codigo, contexto);
const { codificarQr, pngQr, crc32 } = contexto;

/** Código de acceso con el formato que genera la app (4 grupos de 6). */
const CODIGO_NORMAL = 'INV-AB12CD-EF34GH-IJ56KL-MN7890';

/** Dibuja la matriz como imagen RGBA, con 4 módulos de zona de silencio. */
function rasterizar(qr, escala) {
  const n = qr.tamano;
  const ancho = (n + 8) * escala;
  const datos = new Uint8ClampedArray(ancho * ancho * 4);
  for (let py = 0; py < ancho; py++) {
    for (let px = 0; px < ancho; px++) {
      const mx = Math.floor(px / escala) - 4;
      const my = Math.floor(py / escala) - 4;
      const oscuro = mx >= 0 && my >= 0 && mx < n && my < n && qr.modulos[my][mx];
      const valor = oscuro ? 0 : 255;
      const i = (py * ancho + px) * 4;
      datos[i] = valor;
      datos[i + 1] = valor;
      datos[i + 2] = valor;
      datos[i + 3] = 255;
    }
  }
  return { datos, ancho };
}

test('tiene la estructura que exige el estándar', () => {
  const qr = codificarQr(CODIGO_NORMAL);
  assert.strictEqual(qr.version, 3);          // 44 códigos de datos: alcanza
  assert.strictEqual(qr.tamano, 17 + 4 * 3);  // 29 × 29 módulos
  assert.strictEqual(qr.modulos.length, qr.tamano);

  // Localizador superior izquierdo: esquina oscura y separador claro.
  assert.strictEqual(qr.modulos[0][0], true);
  assert.strictEqual(qr.modulos[0][7], false);
  assert.strictEqual(qr.modulos[7][0], false);
  // Línea de tiempo: módulos alternos en la fila 6.
  assert.strictEqual(qr.modulos[6][8], true);
  assert.strictEqual(qr.modulos[6][9], false);
  // El módulo siempre oscuro (referencia de lectura).
  assert.strictEqual(qr.modulos[qr.tamano - 8][8], true);
});

test('jsQR lee el código y devuelve exactamente el mismo texto', () => {
  // jsQR es una librería ajena: leer el código con ella demuestra que un
  // escáner de verdad lo va a poder leer.
  const jsQR = require('jsqr');
  const textos = [
    'A',                                             // versión 1
    CODIGO_NORMAL,                                   // versión 3
    'Código con acentos: ÑÁÉÍÓÚ ü',                  // UTF-8
    'X'.repeat(100),                                 // versión 6
    'Y'.repeat(130)                                  // versión 8 (trae info de versión)
  ];

  for (const texto of textos) {
    const qr = codificarQr(texto);
    const imagen = rasterizar(qr, 2);
    const leido = jsQR(imagen.datos, imagen.ancho, imagen.ancho);
    assert.ok(leido, 'jsQR no logró leer el texto de ' + texto.length + ' caracteres');
    assert.strictEqual(leido.data, texto, 'el texto leído no coincide');
  }
});

test('el texto demasiado largo se rechaza con un error claro', () => {
  assert.throws(() => codificarQr('Z'.repeat(300)), /máxima 10/i);
});

test('el PNG tiene firma, dimensiones y CRC correctos', () => {
  const qr = codificarQr(CODIGO_NORMAL);
  const png = Buffer.from(pngQr(qr.modulos, 10));

  // Firma del formato PNG.
  assert.deepStrictEqual([...png.subarray(0, 8)],
    [137, 80, 78, 71, 13, 10, 26, 10]);

  // Recorrer los fragmentos y validar su CRC (lo pide el formato).
  const fragmentos = {};
  let pos = 8;
  while (pos < png.length) {
    const largo = png.readUInt32BE(pos);
    const tipo = png.toString('ascii', pos + 4, pos + 8);
    const contenido = png.subarray(pos + 4, pos + 8 + largo);
    assert.strictEqual(png.readUInt32BE(pos + 8 + largo), crc32([...contenido]),
      'CRC incorrecto en el fragmento ' + tipo);
    fragmentos[tipo] = png.subarray(pos + 8, pos + 8 + largo);
    pos += 12 + largo;
  }
  assert.strictEqual(pos, png.length, 'sobraron o faltaron bytes en el PNG');

  // IHDR: ancho y alto con la zona de silencio incluida, 1 bit, paleta
  // (índice 0 = azul marino de la marca, 1 = blanco): el QR del mockup es
  // marino, no negro.
  const lado = (qr.tamano + 8) * 10;
  assert.strictEqual(fragmentos.IHDR.readUInt32BE(0), lado);
  assert.strictEqual(fragmentos.IHDR.readUInt32BE(4), lado);
  assert.strictEqual(fragmentos.IHDR[8], 1, 'profundidad esperada: 1 bit');
  assert.strictEqual(fragmentos.IHDR[9], 3, 'tipo de color esperado: paleta');
  assert.deepStrictEqual([...fragmentos.PLTE],
    [0x1B, 0x34, 0x63, 0xFF, 0xFF, 0xFF],
    'la paleta debe ser azul marino #1b3463 y blanco');
});

test('la imagen comprimida se puede abrir y sus píxeles son la matriz', () => {
  const qr = codificarQr(CODIGO_NORMAL);
  const png = Buffer.from(pngQr(qr.modulos, 10));

  // Localizar el IDAT y descomprimirlo con el zlib real de Node: si el flujo
  // guardado o el Adler-32 estuviera mal, esto falla.
  let pos = 8;
  let idat = null;
  let ihdr = null;
  while (pos < png.length) {
    const largo = png.readUInt32BE(pos);
    const tipo = png.toString('ascii', pos + 4, pos + 8);
    if (tipo === 'IDAT') idat = png.subarray(pos + 8, pos + 8 + largo);
    if (tipo === 'IHDR') ihdr = png.subarray(pos + 8, pos + 8 + largo);
    pos += 12 + largo;
  }

  const crudo = zlib.inflateSync(idat);
  const lado = ihdr.readUInt32BE(0);
  const bytesPorFila = Math.ceil(lado / 8);
  assert.strictEqual(crudo.length, lado * (1 + bytesPorFila),
    'las filas del PNG no tienen el largo esperado');

  // Revisar el pixel central de varios módulos contra la matriz.
  for (let my = 0; my < qr.tamano; my += 5) {
    for (let mx = 0; mx < qr.tamano; mx += 5) {
      const px = (mx + 4) * 10 + 5;      // centro del módulo
      const py = (my + 4) * 10 + 5;
      const byte = crudo[py * (1 + bytesPorFila) + 1 + Math.floor(px / 8)];
      const esBlanco = ((byte >>> (7 - (px % 8))) & 1) === 1;
      assert.strictEqual(esBlanco, !qr.modulos[my][mx],
        'el pixel del módulo ' + mx + ',' + my + ' no coincide');
    }
  }
});
