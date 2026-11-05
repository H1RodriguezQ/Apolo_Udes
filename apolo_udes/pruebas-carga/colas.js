// ============================================================================
// Modelo de colas de la entrada a la ceremonia (objetivo 4).
//
// Compara el ingreso manual (buscar el nombre en la lista impresa) con el
// ingreso por QR de Apolo. Usa el modelo M/M/c:
//   M = las personas llegan al azar (proceso de Poisson)
//   M = el tiempo de atención de cada persona varía al azar (exponencial)
//   c = número de puntos de atención (entradas o tablets)
//
// Ojo: en la apertura de la ceremonia llega mucha más gente de la que se
// alcanza a atender (rho > 1). En ese caso las fórmulas de "estado estable"
// del M/M/c no aplican, porque la fila nunca se estabiliza: solo crece hasta
// que deja de llegar gente. Por eso, además de las fórmulas (Erlang C), se
// simula la llegada en ráfaga muchas veces y se promedia.
//
// Datos de entrada (de la entrevista con el Director de Graduados):
//   - 320 a 340 asistentes por ceremonia -> se usa 330
//   - 2 entradas
//   - la mayoría llega en los 10 a 15 minutos de la apertura -> 15 min
//   - hoy la fila dura entre 20 y 30 minutos -> se usa 25 min para calibrar
//
// Uso:
//   node colas.js
//   node colas.js --qr-seg 6 --asistentes 340 --ventana-min 10
// ============================================================================

const fs = require('fs');
const path = require('path');

// --- parámetros (se pueden cambiar por consola) -----------------------------
function parametro(nombre, porDefecto) {
  const i = process.argv.indexOf('--' + nombre);
  return i > -1 ? Number(process.argv[i + 1]) : porDefecto;
}
const ASISTENTES = parametro('asistentes', 330);
const ENTRADAS = parametro('entradas', 2);
const VENTANA_MIN = parametro('ventana-min', 15);
const ESPERA_OBSERVADA_MIN = parametro('espera-observada-min', 25);
// Tiempo de atención con QR. Es un SUPUESTO hasta medirlo en el simulacro:
// leer el código, ver "Acceso permitido" en pantalla y dejar pasar.
const QR_SEG = parametro('qr-seg', 8);
const REPETICIONES = parametro('repeticiones', 2000);
const META_MIN = 5; // objetivo del proyecto: menos de 5 minutos de espera

// --- números al azar con semilla (para que el resultado se pueda repetir) ----
let semilla = 20261105;
function azar() {
  // Generador lineal congruencial sencillo: siempre da la misma secuencia.
  semilla = (semilla * 1664525 + 1013904223) % 4294967296;
  return (semilla + 0.5) / 4294967296;
}
function exponencial(media) {
  return -media * Math.log(azar());
}

// --- fórmulas del M/M/c (Erlang C) ----------------------------------------------
// lambda: llegadas por minuto, mu: atenciones por minuto de UN punto, c: puntos
function mmc(lambda, mu, c) {
  const rho = lambda / (c * mu); // ocupación de los puntos
  if (rho >= 1) return { rho, estable: false };

  const a = lambda / mu;
  let suma = 0, termino = 1;
  for (let k = 0; k < c; k++) {
    if (k > 0) termino *= a / k;
    suma += termino;
  }
  const ultimo = termino * (a / c) * (1 / (1 - rho)); // a^c / c! / (1 - rho)
  const p0 = 1 / (suma + ultimo);
  const probEsperar = ultimo * p0; // Erlang C
  const wq = probEsperar / (c * mu - lambda); // espera promedio en fila (min)
  return { rho, estable: true, probEsperar, wqMin: wq, lq: lambda * wq };
}

// --- simulación de la llegada en ráfaga -------------------------------------------
// Las personas llegan al azar dentro de la ventana; hay una sola fila y el
// primero libre de los c puntos atiende al siguiente (así funciona el M/M/c).
function simularUnaVez(atencionSeg, puntos) {
  const llegadas = [];
  for (let i = 0; i < ASISTENTES; i++) llegadas.push(azar() * VENTANA_MIN * 60);
  llegadas.sort((a, b) => a - b);

  const libreEn = new Array(puntos).fill(0); // segundo en que cada punto queda libre
  const esperas = [];
  for (const llega of llegadas) {
    // punto que se libera primero
    let p = 0;
    for (let k = 1; k < puntos; k++) if (libreEn[k] < libreEn[p]) p = k;
    const empieza = Math.max(llega, libreEn[p]);
    esperas.push(empieza - llega);
    libreEn[p] = empieza + exponencial(atencionSeg);
  }
  const fin = Math.max(...libreEn);
  return { esperas, finSeg: fin };
}

function simular(atencionSeg, puntos) {
  let sumaPromedio = 0, sumaFin = 0;
  const todas = [];
  let dentroDeMeta = 0, total = 0;
  for (let r = 0; r < REPETICIONES; r++) {
    const { esperas, finSeg } = simularUnaVez(atencionSeg, puntos);
    sumaPromedio += esperas.reduce((a, b) => a + b, 0) / esperas.length;
    sumaFin += finSeg;
    for (const e of esperas) {
      todas.push(e);
      if (e <= META_MIN * 60) dentroDeMeta++;
      total++;
    }
  }
  todas.sort((a, b) => a - b);
  return {
    esperaPromedioMin: sumaPromedio / REPETICIONES / 60,
    esperaP95Min: todas[Math.floor(0.95 * todas.length)] / 60,
    esperaMaxMin: todas[todas.length - 1] / 60,
    duracionIngresoMin: sumaFin / REPETICIONES / 60,
    porcentajeEnMeta: (100 * dentroDeMeta) / total
  };
}

// Busca el tiempo de atención que hace que la simulación dé la espera que se
// observa hoy en la ceremonia (búsqueda binaria). Así el tiempo manual sale
// de los datos reales y no de una suposición.
function calibrarManual() {
  let bajo = 1, alto = 300;
  for (let i = 0; i < 25; i++) {
    const medio = (bajo + alto) / 2;
    const r = simularRapido(medio);
    if (r < ESPERA_OBSERVADA_MIN) bajo = medio; else alto = medio;
  }
  return (bajo + alto) / 2;
}
function simularRapido(atencionSeg) {
  let suma = 0;
  const veces = 300;
  for (let r = 0; r < veces; r++) {
    const { esperas } = simularUnaVez(atencionSeg, ENTRADAS);
    suma += esperas.reduce((a, b) => a + b, 0) / esperas.length;
  }
  return suma / veces / 60;
}

// Tiempo de atención MÁXIMO por persona para cumplir la meta de 5 minutos.
function atencionMaximaParaMeta(puntos) {
  let bajo = 1, alto = 300;
  for (let i = 0; i < 25; i++) {
    const medio = (bajo + alto) / 2;
    let suma = 0;
    for (let r = 0; r < 300; r++) {
      const { esperas } = simularUnaVez(medio, puntos);
      suma += esperas.reduce((a, b) => a + b, 0) / esperas.length;
    }
    if (suma / 300 / 60 < META_MIN) bajo = medio; else alto = medio;
  }
  return (bajo + alto) / 2;
}

// --- programa principal -------------------------------------------------------------
const f1 = (x) => x.toFixed(1);
const lambda = ASISTENTES / VENTANA_MIN; // personas por minuto en la apertura

console.log('\n  Modelo de colas de la entrada (M/M/c)\n');
console.log(`  Asistentes: ${ASISTENTES}   Entradas: ${ENTRADAS}   Ventana de llegada: ${VENTANA_MIN} min`);
console.log(`  Llegadas en la apertura: lambda = ${f1(lambda)} personas/min\n`);

const manualSeg = calibrarManual();
console.log(`  Calibración: con ${ESPERA_OBSERVADA_MIN} min de espera observada, el ingreso manual`);
console.log(`  equivale a ${f1(manualSeg)} s de atención por persona en cada entrada.\n`);

const escenarios = [
  { nombre: 'Manual (lista impresa)', seg: manualSeg, puntos: ENTRADAS },
  { nombre: 'Apolo QR', seg: QR_SEG, puntos: ENTRADAS },
  { nombre: 'Apolo QR, 2 tablets por entrada', seg: QR_SEG, puntos: ENTRADAS * 2 }
];

const filas = [];
for (const e of escenarios) {
  const mu = 60 / e.seg; // atenciones por minuto de un punto
  const formula = mmc(lambda, mu, e.puntos);
  const sim = simular(e.seg, e.puntos);
  filas.push({ ...e, formula, sim });
}

const lineas = [];
lineas.push('| Escenario | Atención por persona (s) | Puntos | rho | Espera promedio (min) | Espera p95 (min) | Espera máx (min) | Ingreso completo (min) | % en menos de 5 min |');
lineas.push('|---|---|---|---|---|---|---|---|---|');
for (const r of filas) {
  lineas.push(`| ${r.nombre} | ${f1(r.seg)} | ${r.puntos} | ${r.formula.rho.toFixed(2)} | ` +
    `${f1(r.sim.esperaPromedioMin)} | ${f1(r.sim.esperaP95Min)} | ${f1(r.sim.esperaMaxMin)} | ` +
    `${f1(r.sim.duracionIngresoMin)} | ${f1(r.sim.porcentajeEnMeta)} % |`);
}
console.log(lineas.join('\n'));

const limite = atencionMaximaParaMeta(ENTRADAS);
console.log(`\n  Para cumplir la meta (espera promedio < ${META_MIN} min) con ${ENTRADAS} puntos,`);
console.log(`  cada lectura debe tardar como máximo ${f1(limite)} s por persona.`);

console.log('\n  Fórmulas de estado estable (Erlang C):');
for (const r of filas) {
  if (r.formula.estable) {
    console.log(`  - ${r.nombre}: rho ${r.formula.rho.toFixed(2)}, P(esperar) ${(100 * r.formula.probEsperar).toFixed(1)} %, ` +
      `Wq ${(r.formula.wqMin * 60).toFixed(1)} s`);
  } else {
    console.log(`  - ${r.nombre}: rho ${r.formula.rho.toFixed(2)} >= 1, la fila crece mientras llega gente; ` +
      'se usa la simulación.');
  }
}

// Informe para el libro.
const md = [
  '# Modelo de colas de la entrada (M/M/c)',
  '',
  `Parámetros: ${ASISTENTES} asistentes, ${ENTRADAS} entradas, llegada en ${VENTANA_MIN} min ` +
    `(lambda = ${f1(lambda)} personas/min), ${REPETICIONES} simulaciones por escenario.`,
  '',
  `- El tiempo manual (${f1(manualSeg)} s) se calibró para reproducir la espera de ` +
    `${ESPERA_OBSERVADA_MIN} min que reporta la Dirección de Graduados.`,
  `- El tiempo con QR (${QR_SEG} s) es un **supuesto** hasta medirlo en el simulacro.`,
  '',
  ...lineas,
  '',
  `Para que la espera promedio sea menor a ${META_MIN} min con ${ENTRADAS} puntos, cada ` +
    `lectura debe tardar como máximo **${f1(limite)} s** por persona.`,
  ''
].join('\n');
const carpeta = path.join(__dirname, 'resultados');
fs.mkdirSync(carpeta, { recursive: true });
fs.writeFileSync(path.join(carpeta, 'colas.md'), md);
fs.writeFileSync(path.join(carpeta, 'colas.json'), JSON.stringify({ manualSeg, limite, filas }, null, 2));
console.log('\n  Informe en pruebas-carga\\resultados\\colas.md\n');
