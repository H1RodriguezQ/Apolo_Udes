/**
 * ===========================================================================
 *  qr.gs — genera el PNG del código de acceso que va dentro de la invitación
 * ===========================================================================
 *  ¿Por qué este archivo y no un servicio de internet?
 *    · Pedir el QR a una web externa (goqr.me, quickchart…) deja el código de
 *      cada invitado en manos de un tercero y el correo depende de que esa
 *      web esté arriba.
 *    · Adjuntar el QR como data:base64 dentro del HTML no sirve: Gmail bloquea
 *      esas imágenes.
 *  Así el QR se dibuja aquí, se adjunta como imagen en línea (cid:qr) y solo
 *  viaja dentro del propio correo.
 *
 *  Qué hace, en orden:
 *    1. codificarQr(texto)  → convierte el código de acceso en una matriz de
 *       módulos negros y blancos (estándar QR, versión 1 a 10, nivel M).
 *    2. pngQr(matriz)       → dibuja esa matriz en un PNG de 1 bit, con su
 *       zona de silencio blanca de 4 módulos alrededor (sin ella muchos
 *       celulares no logran leer el código).
 *    3. generarQrPng(texto) → devuelve el Blob listo para GmailApp.
 *
 *  Este archivo es de JavaScript puro: no usa servicios de Apps Script, por lo
 *  que también se puede probar en Node (ver test/qr.test.js).
 * ===========================================================================
 */

// ─────────────────── Capacidades por versión (nivel M) ─────────────────────
// "datos": códigos de datos disponibles; "ecc": códigos de corrección de
// errores por bloque; "bloques": tamaño de cada bloque de datos.
// El nivel de corrección M es el equilibrio del estándar: corrige alrededor
// del 15 % de los módulos dañados, suficiente si alguien arruga la tarjeta.
var VERSIONES_M = [
  null,
  { datos: 16,  ecc: 10, bloques: [16] },
  { datos: 28,  ecc: 16, bloques: [28] },
  { datos: 44,  ecc: 26, bloques: [44] },
  { datos: 64,  ecc: 18, bloques: [32, 32] },
  { datos: 86,  ecc: 24, bloques: [43, 43] },
  { datos: 108, ecc: 16, bloques: [27, 27, 27, 27] },
  { datos: 124, ecc: 18, bloques: [31, 31, 31, 31] },
  { datos: 154, ecc: 22, bloques: [38, 38, 39, 39] },
  { datos: 182, ecc: 22, bloques: [36, 36, 36, 37, 37] },
  { datos: 216, ecc: 26, bloques: [43, 43, 43, 43, 44] }
];

// Posiciones de los cuadros de alineación por versión (fila/columna 6 siempre
// es la línea de tiempo, por eso el primer valor es 6).
var POSICIONES_ALINEACION = [
  null,
  [6],
  [6, 18],
  [6, 22],
  [6, 26],
  [6, 30],
  [6, 34],
  [6, 22, 38],
  [6, 24, 42],
  [6, 26, 46],
  [6, 28, 50]
];

// ─────────────────────────── Texto a bytes (UTF-8) ─────────────────────────

/** Convierte un texto en sus bytes UTF-8 (funciona igual en Apps Script y Node). */
function aUtf8(texto) {
  var binario = unescape(encodeURIComponent(String(texto)));
  var bytes = [];
  for (var i = 0; i < binario.length; i++) {
    bytes.push(binario.charCodeAt(i));
  }
  return bytes;
}

// ─────────────────── Corrección de errores (Reed-Solomon) ──────────────────
// Todo el cálculo ocurre en el cuerpo GF(256) con el polinomio 0x11D, el
// mismo que exige el estándar QR.

var GF_LOG = [];
var GF_EXP = [];

(function inicializarCuerpo() {
  var x = 1;
  for (var i = 0; i < 255; i++) {
    GF_EXP[i] = x;
    GF_LOG[x] = i;
    x = (x << 1) ^ ((x & 0x80) ? 0x11D : 0);
    x &= 0xFF;
  }
  // Duplicar la tabla permite sumar logaritmos sin pasar de 510.
  for (var j = 255; j < 512; j++) {
    GF_EXP[j] = GF_EXP[j - 255];
  }
})();

/** Multiplicación en GF(256). */
function multiplicarGf(a, b) {
  if (a === 0 || b === 0) return 0;
  return GF_EXP[GF_LOG[a] + GF_LOG[b]];
}

/** Polinomio generador (x - a^0)(x - a^1)…(x - a^(n-1)). */
function polinomioGenerador(n) {
  var polinomio = [1];
  for (var i = 0; i < n; i++) {
    var siguiente = [];
    for (var j = 0; j <= polinomio.length; j++) siguiente.push(0);
    for (var k = 0; k < polinomio.length; k++) {
      siguiente[k] ^= multiplicarGf(polinomio[k], 1);
      siguiente[k + 1] ^= multiplicarGf(polinomio[k], GF_EXP[i]);
    }
    polinomio = siguiente;
  }
  return polinomio;
}

/**
 * Devuelve los "n" códigos de corrección de errores del bloque de datos.
 * Es el residuo de dividir el bloque entre el polinomio generador.
 */
function residuoRs(datos, n) {
  var generador = polinomioGenerador(n);
  var residuo = [];
  var i;
  for (i = 0; i < datos.length + n; i++) residuo.push(0);
  for (i = 0; i < datos.length; i++) residuo[i] = datos[i];

  for (i = 0; i < datos.length; i++) {
    var coeficiente = residuo[i];
    if (coeficiente !== 0) {
      for (var j = 0; j < generador.length; j++) {
        residuo[i + j] ^= multiplicarGf(generador[j], coeficiente);
      }
    }
  }
  return residuo.slice(datos.length);
}

// ─────────────────────────── Codificación QR ───────────────────────────────

/** Empuja "cantidad" bits del valor (en orden de bit más significativo). */
function empujarBits(destino, valor, cantidad) {
  for (var i = cantidad - 1; i >= 0; i--) {
    destino.push((valor >>> i) & 1);
  }
}

/**
 * Convierte un texto en la matriz del código QR.
 *
 * @param {string} texto  por ejemplo "INV-AB12CD-EF34GH"
 * @returns {{tamano:number, modulos:Array.<Array.<boolean>>, version:number,
 *            mascara:number}}
 */
function codificarQr(texto) {
  var bytes = aUtf8(texto);

  // 1) Versión más pequeña que alcanza para el texto.
  var version = 0;
  for (var v = 1; v <= 10; v++) {
    var cabecera = 4 + (v >= 10 ? 16 : 8); // modo byte + longitud
    if (cabecera + 8 * bytes.length <= VERSIONES_M[v].datos * 8) {
      version = v;
      break;
    }
  }
  if (version === 0) {
    throw new Error('El texto no cabe en un QR (versión máxima 10).');
  }

  var info = VERSIONES_M[version];

  // 2) Flujo de bits: modo, longitud, datos, terminador y relleno.
  var flujo = [];
  empujarBits(flujo, 0x4, 4); // modo byte (0100)
  empujarBits(flujo, bytes.length, version >= 10 ? 16 : 8);
  for (var i = 0; i < bytes.length; i++) empujarBits(flujo, bytes[i], 8);

  var capBits = info.datos * 8;
  empujarBits(flujo, 0, Math.min(4, capBits - flujo.length)); // terminador
  while (flujo.length % 8 !== 0) flujo.push(0); // alineación a byte

  var datos = [];
  for (var b = 0; b < flujo.length; b += 8) {
    var byte = 0;
    for (var k = 0; k < 8; k++) byte = (byte << 1) | flujo[b + k];
    datos.push(byte);
  }
  // Relleno alternando 0xEC y 0x11, como pide el estándar.
  var relleno = [0xEC, 0x11];
  var r = 0;
  while (datos.length < info.datos) {
    datos.push(relleno[r % 2]);
    r++;
  }

  // 3) Bloques de datos + corrección de errores de cada bloque.
  var bloquesDatos = [];
  var bloquesEcc = [];
  var desplazamiento = 0;
  for (var n = 0; n < info.bloques.length; n++) {
    var trozo = datos.slice(desplazamiento, desplazamiento + info.bloques[n]);
    desplazamiento += info.bloques[n];
    bloquesDatos.push(trozo);
    bloquesEcc.push(residuoRs(trozo, info.ecc));
  }

  // 4) Intercalado: primero los datos de todos los bloques y luego la
  //    corrección. Así un arañazo en la tarjeta no borra un bloque entero.
  var codewords = [];
  var largoMaximo = 0;
  for (var d = 0; d < bloquesDatos.length; d++) {
    if (bloquesDatos[d].length > largoMaximo) largoMaximo = bloquesDatos[d].length;
  }
  for (var pos = 0; pos < largoMaximo; pos++) {
    for (var bd = 0; bd < bloquesDatos.length; bd++) {
      if (pos < bloquesDatos[bd].length) codewords.push(bloquesDatos[bd][pos]);
    }
  }
  for (var e = 0; e < info.ecc; e++) {
    for (var be = 0; be < bloquesEcc.length; be++) codewords.push(bloquesEcc[be][e]);
  }

  // 5) Matriz con los patrones fijos y los bits colocados en zigzag.
  var tamano = 17 + 4 * version;
  var modulos = crearMatriz(tamano, false);
  var esFuncion = crearMatriz(tamano, false);

  dibujarPatronesFuncion(modulos, esFuncion, version, tamano);
  colocarCodewords(modulos, esFuncion, tamano, codewords);

  // 6) Elegir la máscara que menos "ruido" deja en la imagen. Cualquiera de
  //    las 8 es válida; se calcula la mejor para que el lector tenga más
  //    facilidad.
  var mejorMascara = 0;
  var mejorPenalizacion = Infinity;
  for (var m = 0; m < 8; m++) {
    aplicarMascara(modulos, esFuncion, tamano, m);
    dibujarFormato(modulos, esFuncion, tamano, m);
    var penalizacion = calcularPenalizacion(modulos, tamano);
    if (penalizacion < mejorPenalizacion) {
      mejorPenalizacion = penalizacion;
      mejorMascara = m;
    }
    aplicarMascara(modulos, esFuncion, tamano, m); // deshacer (XOR se niega solo)
  }
  aplicarMascara(modulos, esFuncion, tamano, mejorMascara);
  dibujarFormato(modulos, esFuncion, tamano, mejorMascara);

  return {
    tamano: tamano,
    modulos: modulos,
    version: version,
    mascara: mejorMascara
  };
}

// ───────────────────── Dibujo de los patrones fijos ────────────────────────

function crearMatriz(n, valor) {
  var matriz = [];
  for (var f = 0; f < n; f++) {
    var fila = [];
    for (var c = 0; c < n; c++) fila.push(valor);
    matriz.push(fila);
  }
  return matriz;
}

/** Fija un módulo y lo marca como parte del patrón de función (no se enmascara). */
function fijarModulo(modulos, esFuncion, x, y, oscuro) {
  modulos[y][x] = oscuro;
  esFuncion[y][x] = true;
}

function dibujarPatronesFuncion(modulos, esFuncion, version, n) {
  var i;

  // Líneas de tiempo (fila y columna 6): módulos alternos.
  for (i = 0; i < n; i++) {
    fijarModulo(modulos, esFuncion, 6, i, i % 2 === 0);
    fijarModulo(modulos, esFuncion, i, 6, i % 2 === 0);
  }

  // Tres localizadores de esquina con su separador blanco.
  dibujarLocalizador(modulos, esFuncion, 3, 3, n);
  dibujarLocalizador(modulos, esFuncion, n - 4, 3, n);
  dibujarLocalizador(modulos, esFuncion, 3, n - 4, n);

  // Cuadros de alineación (a partir de la versión 2).
  var posiciones = POSICIONES_ALINEACION[version];
  for (var f = 0; f < posiciones.length; f++) {
    for (var c = 0; c < posiciones.length; c++) {
      // Se omiten los tres que caerían encima de un localizador.
      var enEsquina =
        (f === 0 && c === 0) ||
        (f === 0 && c === posiciones.length - 1) ||
        (f === posiciones.length - 1 && c === 0);
      if (enEsquina) continue;
      dibujarAlineacion(modulos, esFuncion, posiciones[c], posiciones[f]);
    }
  }

  // Información de formato: aquí se reserva el espacio; se vuelve a escribir
  // con la máscara elegida al final de codificarQr().
  dibujarFormato(modulos, esFuncion, n, 0);

  // Información de versión: solo existe desde la versión 7.
  if (version >= 7) dibujarVersion(modulos, esFuncion, version, n);
}

/** Localizador: cuadrado de 7×7 (aro oscuro, aro claro, centro oscuro). */
function dibujarLocalizador(modulos, esFuncion, cx, cy, n) {
  for (var dy = -4; dy <= 4; dy++) {
    for (var dx = -4; dx <= 4; dx++) {
      var distancia = Math.max(Math.abs(dx), Math.abs(dy));
      var x = cx + dx;
      var y = cy + dy;
      if (x >= 0 && x < n && y >= 0 && y < n) {
        fijarModulo(modulos, esFuncion, x, y,
          distancia !== 2 && distancia !== 4);
      }
    }
  }
}

/** Cuadro de alineación de 5×5 alrededor de (cx, cy). */
function dibujarAlineacion(modulos, esFuncion, cx, cy) {
  for (var dy = -2; dy <= 2; dy++) {
    for (var dx = -2; dx <= 2; dx++) {
      var distancia = Math.max(Math.abs(dx), Math.abs(dy));
      fijarModulo(modulos, esFuncion, cx + dx, cy + dy, distancia !== 1);
    }
  }
}

/**
 * Los 15 bits de la información de formato dicen "nivel M" y "qué máscara se
 * aplicó". Se calculan con el mismo código BCH(15,5) del estándar y se
 * escriben en las dos zonas que reserva el QR.
 */
function dibujarFormato(modulos, esFuncion, n, mascara) {
  var datos = (0 << 3) | mascara; // nivel M = 00, más los 3 bits de máscara
  var resto = datos;
  for (var i = 0; i < 10; i++) {
    resto = (resto << 1) ^ ((resto >> 9) * 0x537);
  }
  var bits = ((datos << 10) | resto) ^ 0x5412;

  function bit(indice) {
    return ((bits >>> indice) & 1) !== 0;
  }

  var j;
  // Primera copia (alrededor del localizador superior izquierdo).
  for (j = 0; j <= 5; j++) fijarModulo(modulos, esFuncion, 8, j, bit(j));
  fijarModulo(modulos, esFuncion, 8, 7, bit(6));
  fijarModulo(modulos, esFuncion, 8, 8, bit(7));
  fijarModulo(modulos, esFuncion, 7, 8, bit(8));
  for (j = 9; j < 15; j++) fijarModulo(modulos, esFuncion, 14 - j, 8, bit(j));

  // Segunda copia (esquina inferior derecha y borde derecho).
  for (j = 0; j < 8; j++) fijarModulo(modulos, esFuncion, n - 1 - j, 8, bit(j));
  for (j = 8; j < 15; j++) fijarModulo(modulos, esFuncion, 8, n - 15 + j, bit(j));

  // Módulo siempre oscuro: sirve de referencia de lectura.
  fijarModulo(modulos, esFuncion, 8, n - 8, true);
}

/** Los 18 bits de la versión (solo versiones 7 en adelante). */
function dibujarVersion(modulos, esFuncion, version, n) {
  var resto = version;
  for (var i = 0; i < 12; i++) {
    resto = (resto << 1) ^ ((resto >> 11) * 0x1F25);
  }
  var bits = (version << 12) | resto;
  for (var k = 0; k < 18; k++) {
    var bit = ((bits >>> k) & 1) !== 0;
    var a = n - 11 + (k % 3);
    var b = Math.floor(k / 3);
    fijarModulo(modulos, esFuncion, a, b, bit);
    fijarModulo(modulos, esFuncion, b, a, bit);
  }
}

// ────────────────────── Colocación de los datos ────────────────────────────

/**
 * Escribe los códigos en zigzag: se sube y baja en parejas de columnas desde
 * la derecha, saltando la columna 6 (línea de tiempo) y los módulos de
 * patrón de función, que quedan intactos.
 */
function colocarCodewords(modulos, esFuncion, n, codewords) {
  var indice = 0; // índice de bit
  for (var derecha = n - 1; derecha >= 1; derecha -= 2) {
    if (derecha === 6) derecha = 5;
    for (var v = 0; v < n; v++) {
      for (var j = 0; j < 2; j++) {
        var x = derecha - j;
        var sube = ((derecha + 1) & 2) === 0;
        var y = sube ? n - 1 - v : v;
        if (!esFuncion[y][x]) {
          var oscuro = false;
          if (indice < codewords.length * 8) {
            oscuro = ((codewords[indice >> 3] >>> (7 - (indice & 7))) & 1) !== 0;
            indice++;
          }
          // Si ya no queda información, el módulo se queda claro: son los
          // "bits de relleno" que prevé el estándar.
          modulos[y][x] = oscuro;
        }
      }
    }
  }
}

/** Niega los módulos de datos según la fórmula de la máscara elegida. */
function aplicarMascara(modulos, esFuncion, n, mascara) {
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      if (esFuncion[y][x]) continue;
      var invertir = false;
      switch (mascara) {
        case 0: invertir = (x + y) % 2 === 0; break;
        case 1: invertir = y % 2 === 0; break;
        case 2: invertir = x % 3 === 0; break;
        case 3: invertir = (x + y) % 3 === 0; break;
        case 4: invertir = (Math.floor(x / 3) + Math.floor(y / 2)) % 2 === 0; break;
        case 5: invertir = (x * y) % 2 + (x * y) % 3 === 0; break;
        case 6: invertir = ((x * y) % 2 + (x * y) % 3) % 2 === 0; break;
        default: invertir = ((x + y) % 2 + (x * y) % 3) % 2 === 0; break;
      }
      if (invertir) modulos[y][x] = !modulos[y][x];
    }
  }
}

// ─────────────────────────── Penalización ──────────────────────────────────

/**
 * Puntúa qué tan "difícil de leer" queda la imagen con la máscara actual.
 * Son las 4 reglas del estándar; se queda la máscara con menos puntos.
 */
function calcularPenalizacion(modulos, n) {
  var total = 0;
  var i;
  var j;

  // Regla 1: cinco o más módulos seguidos del mismo color (en fila o columna).
  for (i = 0; i < n; i++) {
    var corridaFila = 1;
    var corridaColumna = 1;
    for (j = 1; j < n; j++) {
      if (modulos[i][j] === modulos[i][j - 1]) corridaFila++;
      else { if (corridaFila >= 5) total += 3 + (corridaFila - 5); corridaFila = 1; }
      if (modulos[j][i] === modulos[j - 1][i]) corridaColumna++;
      else { if (corridaColumna >= 5) total += 3 + (corridaColumna - 5); corridaColumna = 1; }
    }
    if (corridaFila >= 5) total += 3 + (corridaFila - 5);
    if (corridaColumna >= 5) total += 3 + (corridaColumna - 5);
  }

  // Regla 2: bloques de 2×2 del mismo color.
  for (i = 0; i < n - 1; i++) {
    for (j = 0; j < n - 1; j++) {
      var color = modulos[i][j];
      if (color === modulos[i][j + 1] && color === modulos[i + 1][j] &&
          color === modulos[i + 1][j + 1]) {
        total += 3;
      }
    }
  }

  // Regla 3: patrón que parece un localizador (1011101 con 4 claros al lado).
  var patronA = [true, false, true, true, true, false, true,
    false, false, false, false];
  var patronB = [false, false, false, false, true, false, true, true, true,
    false, true];
  for (i = 0; i < n; i++) {
    for (j = 0; j <= n - 11; j++) {
      var enFilaA = true;
      var enFilaB = true;
      var enColumnaA = true;
      var enColumnaB = true;
      for (var k = 0; k < 11; k++) {
        if (modulos[i][j + k] !== patronA[k]) enFilaA = false;
        if (modulos[i][j + k] !== patronB[k]) enFilaB = false;
        if (modulos[j + k][i] !== patronA[k]) enColumnaA = false;
        if (modulos[j + k][i] !== patronB[k]) enColumnaB = false;
      }
      if (enFilaA) total += 40;
      if (enFilaB) total += 40;
      if (enColumnaA) total += 40;
      if (enColumnaB) total += 40;
    }
  }

  // Regla 4: la proporción de módulos oscuros debe acercarse al 50 %.
  var oscuros = 0;
  for (i = 0; i < n; i++) {
    for (j = 0; j < n; j++) if (modulos[i][j]) oscuros++;
  }
  var porcentaje = oscuros * 100 / (n * n);
  total += Math.floor(Math.abs(porcentaje - 50) / 5) * 10;

  return total;
}

// ───────────────────────────── PNG (1 bit) ─────────────────────────────────

/** CRC-32, exigido por cada fragmento del PNG. */
var CRC_TABLA = null;

function crc32(bytes) {
  if (CRC_TABLA === null) {
    CRC_TABLA = [];
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
      }
      CRC_TABLA[n] = c >>> 0;
    }
  }
  var acumulado = 0xFFFFFFFF;
  for (var i = 0; i < bytes.length; i++) {
    acumulado = CRC_TABLA[(acumulado ^ bytes[i]) & 0xFF] ^ (acumulado >>> 8);
  }
  return (acumulado ^ 0xFFFFFFFF) >>> 0;
}

/** Adler-32, el checksum que cierra el flujo zlib. */
function adler32(bytes) {
  var a = 1;
  var b = 0;
  for (var i = 0; i < bytes.length; i++) {
    a = (a + bytes[i]) % 65521;
    b = (b + a) % 65521;
  }
  return ((b << 16) | a) >>> 0;
}

/**
 * "Comprime" con bloques guardados (sin comprimir). Apps Script no trae zlib,
 * y un PNG sin comprimir es válido: los módulos de un QR tienen muchas
 * repeticiones, así que el tamaño queda razonable.
 */
function flujoZlib(datos) {
  var salida = [0x78, 0x01]; // cabecera zlib: deflate, nivel guardado
  var i = 0;
  while (i < datos.length) {
    var trozo = Math.min(65535, datos.length - i);
    var ultimo = (i + trozo >= datos.length) ? 1 : 0;
    salida.push(ultimo); // BFINAL (1 bit) y BTYPE = 00 (bloque guardado)
    salida.push(trozo & 0xFF, (trozo >>> 8) & 0xFF);
    var inverso = ~trozo;
    salida.push(inverso & 0xFF, (inverso >>> 8) & 0xFF);
    for (var k = 0; k < trozo; k++) salida.push(datos[i + k]);
    i += trozo;
  }
  var checksum = adler32(datos);
  salida.push((checksum >>> 24) & 0xFF, (checksum >>> 16) & 0xFF,
    (checksum >>> 8) & 0xFF, checksum & 0xFF);
  return salida;
}

function empujarEntero32(destino, valor) {
  destino.push((valor >>> 24) & 0xFF, (valor >>> 16) & 0xFF,
    (valor >>> 8) & 0xFF, valor & 0xFF);
}

/** Agrega un fragmento del PNG: largo + tipo + datos + CRC. */
function empujarFragmento(png, tipo, datos) {
  empujarEntero32(png, datos.length);
  var inicio = png.length;
  for (var i = 0; i < tipo.length; i++) png.push(tipo.charCodeAt(i));
  for (var j = 0; j < datos.length; j++) png.push(datos[j]);
  empujarEntero32(png, crc32(png.slice(inicio)));
}

/**
 * Dibuja la matriz como PNG en escala de grises de 1 bit, con 4 módulos de
 * zona de silencio blancos alrededor (sin ella los lectores fallan).
 *
 * En escala de grises 1 bit: 0 = negro, 1 = blanco. Cada fila de píxeles va
 * precedida de su byte de filtro (0 = sin filtro).
 *
 * @param {Array.<Array.<boolean>>} modulos
 * @param {number} escala  píxeles por módulo
 * @returns {Array.<number>} bytes del archivo PNG
 */
function pngQr(modulos, escala) {
  var n = modulos.length;
  var ancho = (n + 8) * escala;
  var alto = ancho;
  var bytesPorFila = Math.ceil(ancho / 8);

  var crudo = [];
  for (var py = 0; py < alto; py++) {
    crudo.push(0); // filtro Ninguno
    var acumulado = 0;
    var bits = 0;
    for (var px = 0; px < ancho; px++) {
      var mx = Math.floor(px / escala) - 4;
      var my = Math.floor(py / escala) - 4;
      var oscuro = mx >= 0 && my >= 0 && mx < n && my < n && modulos[my][mx];
      // Se escribe el bit del pixel: 0 = negro (oscuro), 1 = blanco.
      acumulado = (acumulado << 1) | (oscuro ? 0 : 1);
      bits++;
      if (bits === 8) {
        crudo.push(acumulado & 0xFF);
        acumulado = 0;
        bits = 0;
      }
    }
    if (bits > 0) {
      // Los píxeles que sobran en el último byte se dejan en blanco (1).
      crudo.push(((acumulado << (8 - bits)) | ((1 << (8 - bits)) - 1)) & 0xFF);
    }
    // control: la fila debe tener 1 byte de filtro + bytesPorFila
    if (crudo.length % (bytesPorFila + 1) !== 0) {
      throw new Error('Fila del PNG mal calculada.');
    }
  }

  var png = [137, 80, 78, 71, 13, 10, 26, 10]; // firma PNG
  var ihdr = [];
  empujarEntero32(ihdr, ancho);
  empujarEntero32(ihdr, alto);
  ihdr.push(1); // profundidad: 1 bit por píxel
  // Tipo de color 3 = paleta indexada: 0 = azul marino de la marca (el
  // mockup pide el QR marino, no negro), 1 = blanco. 1 bit por píxel, igual
  // que antes, así el tamaño del archivo no cambia.
  ihdr.push(3);
  ihdr.push(0); // compresión: deflate
  ihdr.push(0); // filtro: estándar
  ihdr.push(0); // sin entrelazado
  empujarFragmento(png, 'IHDR', ihdr);
  // Paleta (2 colores): índice 0 #1b3463, índice 1 #ffffff.
  empujarFragmento(png, 'PLTE', [0x1B, 0x34, 0x63, 0xFF, 0xFF, 0xFF]);
  empujarFragmento(png, 'IDAT', flujoZlib(crudo));
  empujarFragmento(png, 'IEND', []);
  return png;
}

// ───────────────────── Punto de entrada para el correo ─────────────────────

/**
 * Genera el PNG del código de acceso, listo para adjuntarse al correo como
 * imagen en línea con Content-ID "qr" (la plantilla lo muestra con
 * <img src="cid:qr">).
 *
 * @param {string} texto  el código de acceso tal como lo guarda la app
 * @returns {GoogleAppsScript.Base.Blob}
 */
function generarQrPng(texto) {
  if (!texto) {
    throw new Error('No hay código de acceso para generar el QR.');
  }
  var qr = codificarQr(texto);
  // escala 10 → unos 370 px para un código normal: se ve nítido al bajarlo a
  // los 170 px de la tarjeta y sigue siendo pequeño para el correo.
  var bytes = pngQr(qr.modulos, 10);
  return Utilities.newBlob(bytes, 'image/png', 'codigo-acceso.png');
}
