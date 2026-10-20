/**
 * generar-birrete.js — exporta a PNG los adornos que el correo no puede
 * dibujar por su cuenta: el birrete del separador y las 4 esquinas art déco.
 * ---------------------------------------------------------------------------
 * ¿Por qué existe este archivo?
 *   · El birrete: en el mockup es SVG, pero Gmail y Outlook descartan el SVG
 *     y varios clientes no dibujan el emoji 🎓 (sale como cajas con
 *     interrogación). Como imagen PNG con URL absoluta se ve en todas partes.
 *   · Las esquinas: el mockup las dibuja con tres líneas + una diagonal; por
 *     CSS solo salen las líneas rectas (la diagonal necesita transformar, y
 *     Outlook la ignora), así que también van como PNG.
 *
 * Dibuja a mano los mismos trazos del SVG del mockup
 * (invitacion-correo-mockup.html):
 *   · birrete 34×26: copa #a6833f, tablero #c2a05a con borde #8f6f33.
 *   · esquinas 64×64: trazos de 1px #b8975a (tres L + diagonal por esquina).
 * Con supersampling 8× (bordes suaves) y fondo crema #fbf8f1 —el mismo de la
 * tarjeta— para que incluso un cliente viejo sin soporte de alfa se vea bien.
 *
 * Solo usa módulos de Node (zlib), sin dependencias externas.
 *
 * Uso:  node generar-birrete.js
 * Escribe en ../apolo_udes/hosting/assets/ y ../apolo_udes/web/assets/:
 *   birrete.png, esquina-sup-izq.png, esquina-sup-der.png,
 *   esquina-inf-izq.png, esquina-inf-der.png
 */
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');

const S = 8; // supersampling: 8 muestras por píxel final

// ───────────────────────── Utilidades de geometría ─────────────────────────

/** Curva de Bézier cúbica aplanada en segmentos de polilínea. */
function bezier(p0, c1, c2, p1, n, salida) {
  for (let i = 1; i <= n; i++) {
    const t = i / n;
    const u = 1 - t;
    salida.push([
      u * u * u * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t * t * t * p1[0],
      u * u * u * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t * t * t * p1[1]
    ]);
  }
}

/** ¿Está el punto dentro del polígono? (ray casting) */
function dentro(poligono, x, y) {
  let adentro = false;
  for (let i = 0, j = poligono.length - 1; i < poligono.length; j = i++) {
    const xi = poligono[i][0], yi = poligono[i][1];
    const xj = poligono[j][0], yj = poligono[j][1];
    if ((yi > y) !== (yj > y) &&
        x < (xj - xi) * (y - yi) / (yj - yi) + xi) adentro = !adentro;
  }
  return adentro;
}

/** Distancia del punto a un segmento. */
function distSegmento(px, py, x1, y1, x2, y2) {
  const dx = x2 - x1, dy = y2 - y1;
  const largo2 = dx * dx + dy * dy;
  let t = largo2 === 0 ? 0 : ((px - x1) * dx + (py - y1) * dy) / largo2;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(px - (x1 + t * dx), py - (y1 + t * dy));
}

/** Distancia del punto a una polilínea completa. */
function distPolilinea(puntos, x, y) {
  let min = Infinity;
  for (let i = 1; i < puntos.length; i++) {
    const d = distSegmento(x, y, puntos[i - 1][0], puntos[i - 1][1],
      puntos[i][0], puntos[i][1]);
    if (d < min) min = d;
  }
  return min;
}

// ───────────────────── Adornos (trazos del mockup) ─────────────────────────

// Birrete 34×26 — copa: "M9 11.5v6.2c0 2.3 3.6 4.1 8 4.1s8-1.8 8-4.1v-6.2L17 15z"
const copa = [[9, 11.5], [9, 17.7]];
bezier([9, 17.7], [9, 20], [12.6, 21.8], [17, 21.8], 24, copa);
bezier([17, 21.8], [21.4, 21.8], [25, 20], [25, 17.7], 24, copa);
copa.push([25, 11.5], [17, 15]);
// tablero, botón, borla y punta (tal como en el SVG del mockup)
const tablero = [[17, 3], [33, 9.5], [17, 16], [1, 9.5]];
const boton = { x: 17, y: 9.5, r: 1.1 };
const borla = [[17, 9.5], [27.5, 13.2], [27.5, 20]];
const punta = [[26.3, 20], [28.7, 20], [28.2, 23.6], [26.8, 23.6]];

// Esquinas 64×64 — cada una: tres L (exterior, media, corta) + la diagonal,
// con el mismo orden de trazos del SVG del mockup (stroke-width 1 → 0.5).
const ESQUINAS = {
  'esquina-sup-izq': [
    [[2, 62], [2, 2], [62, 2]],
    [[8, 62], [8, 8], [62, 8]],
    [[14, 40], [14, 14], [40, 14]],
    [[8, 8], [20, 20]]
  ],
  'esquina-sup-der': [
    [[62, 62], [62, 2], [2, 2]],
    [[56, 62], [56, 8], [2, 8]],
    [[50, 40], [50, 14], [24, 14]],
    [[56, 8], [44, 20]]
  ],
  'esquina-inf-izq': [
    [[2, 2], [2, 62], [62, 62]],
    [[8, 2], [8, 56], [62, 56]],
    [[14, 24], [14, 50], [40, 50]],
    [[8, 56], [20, 44]]
  ],
  'esquina-inf-der': [
    [[62, 2], [62, 62], [2, 62]],
    [[56, 2], [56, 56], [2, 56]],
    [[50, 24], [50, 50], [24, 50]],
    [[56, 56], [44, 44]]
  ]
};

// ───────────────────────── Muestras por adorno ─────────────────────────────

const FONDO = [251, 248, 241]; // crema de la tarjeta

const PALETA_BIRRETE = [
  FONDO,           // 0: tarjeta
  [166, 131, 63],  // 1: copa      #a6833f
  [194, 160, 90],  // 2: tablero    #c2a05a
  [143, 111, 51]   // 3: bordes     #8f6f33
];

const PALETA_ESQUINA = [
  FONDO,           // 0: tarjeta
  [184, 151, 90]   // 1: trazo dorado #b8975a
];

/** Qué color le toca a un punto del birrete. */
function muestraBirrete(x, y) {
  if (dentro(copa, x, y)) return 1;
  if (dentro(tablero, x, y)) return 2;
  if (distPolilinea(tablero.concat([tablero[0]]), x, y) <= 0.3) return 3;
  if (Math.hypot(x - boton.x, y - boton.y) <= boton.r) return 3;
  if (distPolilinea(borla, x, y) <= 0.45) return 3;
  if (dentro(punta, x, y)) return 3;
  return 0;
}

/** Qué color le toca a un punto de una esquina (0 = fondo, 1 = trazo). */
function creadorMuestraEsquina(polilineas) {
  return function (x, y) {
    for (const p of polilineas) {
      if (distPolilinea(p, x, y) <= 0.5) return 1;
    }
    return 0;
  };
}

// ─────────────────── Muestreo, reducción y PNG ─────────────────────────────

/** Supersample 8×, reduce y devuelve los bytes del PNG. */
function generar(W, H, fn, paleta) {
  const w = W * S, h = H * S;
  const muestras = new Uint8Array(w * h);
  for (let py = 0; py < h; py++) {
    for (let px = 0; px < w; px++) {
      muestras[py * w + px] = fn((px + 0.5) / S, (py + 0.5) / S);
    }
  }
  const rgba = Buffer.alloc(W * H * 4);
  const total = S * S;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const cuenta = new Array(paleta.length).fill(0);
      for (let dy = 0; dy < S; dy++) {
        for (let dx = 0; dx < S; dx++) {
          cuenta[muestras[(y * S + dy) * w + (x * S + dx)]]++;
        }
      }
      const suma = [0, 0, 0];
      for (let c = 0; c < paleta.length; c++) {
        if (cuenta[c] === 0) continue;
        suma[0] += paleta[c][0] * cuenta[c];
        suma[1] += paleta[c][1] * cuenta[c];
        suma[2] += paleta[c][2] * cuenta[c];
      }
      const i = (y * W + x) * 4;
      rgba[i] = Math.round(suma[0] / total);
      rgba[i + 1] = Math.round(suma[1] / total);
      rgba[i + 2] = Math.round(suma[2] / total);
      rgba[i + 3] = 255;
    }
  }
  return pngRgba(W, H, rgba);
}

// ───────────────────────── Escritura del PNG ───────────────────────────────

const CRC_TABLA = (() => {
  const t = [];
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    t[n] = c >>> 0;
  }
  return t;
})();

function crc32(bytes) {
  let a = 0xFFFFFFFF;
  for (let i = 0; i < bytes.length; i++) a = CRC_TABLA[(a ^ bytes[i]) & 0xFF] ^ (a >>> 8);
  return (a ^ 0xFFFFFFFF) >>> 0;
}

function fragmento(png, tipo, datos) {
  const largo = Buffer.alloc(4);
  largo.writeUInt32BE(datos.length);
  const cuerpo = Buffer.concat([Buffer.from(tipo, 'latin1'), datos]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(cuerpo));
  png.push(largo, cuerpo, crc);
}

/** Píxeles RGBA → PNG (color tipo 6, 8 bits). */
function pngRgba(ancho, alto, pixeles) {
  const crudo = Buffer.alloc(alto * (1 + ancho * 4));
  for (let y = 0; y < alto; y++) {
    const fila = y * (1 + ancho * 4);
    crudo[fila] = 0; // filtro Ninguno
    pixeles.copy(crudo, fila + 1, y * ancho * 4, (y + 1) * ancho * 4);
  }
  const png = [Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])];
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(ancho, 0);
  ihdr.writeUInt32BE(alto, 4);
  ihdr[8] = 8;  // 8 bits por muestra
  ihdr[9] = 6;  // color RGBA
  fragmento(png, 'IHDR', ihdr);
  fragmento(png, 'IDAT', zlib.deflateSync(crudo, { level: 9 }));
  fragmento(png, 'IEND', Buffer.alloc(0));
  return Buffer.concat(png);
}

// ───────────────────────── Generación ──────────────────────────────────────

const recursos = [
  ['birrete', generar(34, 26, muestraBirrete, PALETA_BIRRETE)]
];
for (const [nombre, trazos] of Object.entries(ESQUINAS)) {
  recursos.push([nombre, generar(64, 64, creadorMuestraEsquina(trazos), PALETA_ESQUINA)]);
}

const destinos = [
  path.join(__dirname, '..', 'apolo_udes', 'hosting', 'assets'),
  path.join(__dirname, '..', 'apolo_udes', 'web', 'assets')
];
for (const dir of destinos) {
  fs.mkdirSync(dir, { recursive: true });
}
for (const [nombre, bytes] of recursos) {
  for (const dir of destinos) {
    fs.writeFileSync(path.join(dir, nombre + '.png'), bytes);
  }
  console.log(nombre + '.png: ' + bytes.length + ' bytes');
}
console.log('Escrito en:\n  ' + destinos.join('\n  '));
