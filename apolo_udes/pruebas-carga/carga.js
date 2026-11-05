// ============================================================================
// Pruebas de carga de Apolo UDES (objetivo 4).
//
// Corre SOLO contra el emulador de Firestore, con las reglas reales del
// proyecto. Nunca toca la base de datos real: si no encuentra el emulador,
// se detiene.
//
// Qué mide:
//   A. Flujo normal: dos tablets (Entrada 1 y Entrada 2) leen los códigos de
//      todos los asistentes, cada una a su ritmo. Se repite con 110, 500 y
//      1000 asistentes.
//   B. Doble escaneo: el mismo QR se lee en las dos tablets al mismo tiempo.
//      Tiene que entrar UNA sola vez.
//   C. Estrés: muchas lecturas a la vez (como si hubiera 50 tablets) para ver
//      si el servidor empieza a fallar.
//
// Cada lectura hace lo mismo que la app en verificarAcceso():
//   1) crear usos/{codigo} (el servidor decide si el código ya se usó)
//   2) guardar el registro en validaciones
//
// Uso (desde la carpeta apolo_udes):
//   powershell -ExecutionPolicy Bypass -File pruebas-carga\ejecutar.ps1
// ============================================================================

const fs = require('fs');
const path = require('path');
const datos = require('./datos');

// --- conexión con el emulador -----------------------------------------------
// `firebase emulators:exec` deja esta variable con la dirección del emulador.
const HOST = process.env.FIRESTORE_EMULATOR_HOST;
if (!HOST) {
  console.error('\n[X] No se encontró el emulador (FIRESTORE_EMULATOR_HOST vacío).');
  console.error('    Este script solo corre dentro de "firebase emulators:exec".\n');
  process.exit(2);
}
const PROYECTO = 'demo-apolo';
const RUTA = `projects/${PROYECTO}/databases/(default)/documents`;
const BASE = `http://${HOST}/v1/${RUTA}`;

// El emulador acepta tokens sin firma ("alg":"none") y toma `sub` como uid.
// "owner" es la llave de administrador del emulador (no pasa por las reglas):
// solo se usa para sembrar los datos falsos.
function token(uid) {
  const b64 = (t) => Buffer.from(t).toString('base64url');
  const ahora = Math.floor(Date.now() / 1000);
  const carga = { sub: uid, aud: PROYECTO, iat: ahora, exp: ahora + 86400 };
  return b64('{"alg":"none","typ":"JWT"}') + '.' + b64(JSON.stringify(carga)) + '.';
}
const OWNER = 'owner';

// Convierte un objeto de JavaScript al formato de campos de la API REST.
function aCampos(obj) {
  const campos = {};
  for (const [clave, valor] of Object.entries(obj)) {
    if (typeof valor === 'number') campos[clave] = { integerValue: String(valor) };
    else if (typeof valor === 'boolean') campos[clave] = { booleanValue: valor };
    else campos[clave] = { stringValue: String(valor) };
  }
  return campos;
}

// Escritura de un documento. Si se pasa `campoFecha`, el servidor pone la
// hora (como serverTimestamp() en la app), que es lo que piden las reglas.
function escritura(coleccion, id, obj, campoFecha) {
  const nombre = `${RUTA}/${coleccion}/${id}`;
  const lista = [{ update: { name: nombre, fields: aCampos(obj) } }];
  if (campoFecha) {
    lista.push({
      transform: {
        document: nombre,
        fieldTransforms: [{ fieldPath: campoFecha, setToServerValue: 'REQUEST_TIME' }]
      }
    });
  }
  return lista;
}

// Envía un commit y devuelve el código HTTP y cuánto se demoró.
async function commit(escrituras, tok) {
  const inicio = process.hrtime.bigint();
  let estado;
  try {
    const r = await fetch(`${BASE}:commit`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${tok}` },
      body: JSON.stringify({ writes: escrituras })
    });
    estado = r.status;
    await r.arrayBuffer(); // se lee la respuesta para liberar la conexión
  } catch (e) {
    estado = -1; // ni siquiera llegó al servidor
  }
  const ms = Number(process.hrtime.bigint() - inicio) / 1e6;
  return { estado, ms };
}

// --- estadísticas -------------------------------------------------------------
function percentil(lista, p) {
  if (lista.length === 0) return 0;
  const orden = [...lista].sort((a, b) => a - b);
  const pos = Math.min(orden.length - 1, Math.ceil((p / 100) * orden.length) - 1);
  return orden[Math.max(0, pos)];
}
function resumen(tiempos) {
  const suma = tiempos.reduce((a, b) => a + b, 0);
  return {
    promedio: +(suma / Math.max(1, tiempos.length)).toFixed(1),
    p50: +percentil(tiempos, 50).toFixed(1),
    p95: +percentil(tiempos, 95).toFixed(1),
    maximo: +Math.max(0, ...tiempos).toFixed(1)
  };
}

// --- usuarios de la prueba ------------------------------------------------------
const corrida = Date.now().toString(36);
const OPERADORES = [
  { uid: `op1-${corrida}`, correo: `op1.${corrida}@prueba.com`, punto: 'Entrada 1' },
  { uid: `op2-${corrida}`, correo: `op2.${corrida}@prueba.com`, punto: 'Entrada 2' }
];

async function sembrarOperadores() {
  const escrituras = OPERADORES.flatMap((op) => escritura('usuarios', op.uid, {
    correo: op.correo, nombre: 'Operador de prueba', rol: 'operador',
    puntoValidacion: op.punto, estado: 'activo'
  }));
  const r = await commit(escrituras, OWNER);
  if (r.estado !== 200) throw new Error('No se pudieron crear los operadores (HTTP ' + r.estado + ')');
}

// Crea los graduandos y sus invitados falsos y devuelve los códigos QR.
// Cada graduando lleva 2 invitados, así que hacen falta asistentes / 2.
async function sembrarAsistentes(asistentes) {
  const lista = datos.graduandos(Math.ceil(asistentes / 2));
  const codigos = [];
  let lote = [];

  const enviar = async () => {
    if (lote.length === 0) return;
    const r = await commit(lote, OWNER);
    if (r.estado !== 200) throw new Error('Falló la siembra (HTTP ' + r.estado + ')');
    lote = [];
  };

  for (const g of lista) {
    lote.push(...escritura('graduandos', g.id, g));
    for (let n = 1; n <= 2 && codigos.length < asistentes; n++) {
      const inv = datos.invitado(codigos.length);
      const codigo = datos.codigoAcceso('INV');
      lote.push(...escritura('invitados', datos.idAleatorio(), {
        graduandoId: g.id, nombre: inv.nombre, documento: inv.documento,
        correo: inv.correo, codigoQr: codigo, estado: 'registrado'
      }));
      codigos.push({ codigo, nombre: inv.nombre });
    }
    if (lote.length >= 400) await enviar(); // un commit admite hasta 500
  }
  await enviar();
  return codigos;
}

// --- una lectura de QR, igual que en la app ------------------------------------
async function leerQr(op, asistente) {
  const tok = token(op.uid);
  // 1) El servidor decide: solo se puede CREAR usos/{codigo} una vez.
  const uso = await commit(escritura('usos', asistente.codigo, {
    codigo: asistente.codigo, puntoValidacion: op.punto, operadorId: op.uid
  }, 'timestamp'), tok);
  const permitido = uso.estado === 200;
  const yaUsado = uso.estado === 403;

  // 2) Registro de la validación (queda en la bitácora de accesos).
  const val = await commit(escritura('validaciones', datos.idAleatorio(), {
    codigo: asistente.codigo, nombre: permitido ? asistente.nombre : '',
    tipo: 'invitado', resultado: permitido ? 'valido' : 'usado',
    puntoValidacion: op.punto, operadorId: op.uid, operadorCorreo: op.correo
  }, 'timestamp'), tok);

  return {
    permitido, yaUsado,
    error: !permitido && !yaUsado ? uso.estado : (val.estado !== 200 ? val.estado : null),
    ms: uso.ms + val.ms
  };
}

// --- escenarios ----------------------------------------------------------------

// A. Dos tablets, cada una con su fila; leen una persona tras otra.
async function flujoNormal(asistentes) {
  const codigos = await sembrarAsistentes(asistentes);
  const filas = [[], []];
  codigos.forEach((c, i) => filas[i % 2].push(c)); // mitad por cada entrada

  const tiempos = [];
  let permitidos = 0, errores = 0;
  const inicio = Date.now();

  await Promise.all(filas.map(async (fila, t) => {
    for (const asistente of fila) {
      const r = await leerQr(OPERADORES[t], asistente);
      tiempos.push(r.ms);
      if (r.permitido) permitidos++;
      if (r.error) errores++;
    }
  }));

  const segundos = (Date.now() - inicio) / 1000;
  return {
    escenario: 'A. Flujo normal (2 tablets)',
    asistentes, permitidos, errores,
    duracionSeg: +segundos.toFixed(2),
    lecturasPorSeg: +(asistentes / segundos).toFixed(1),
    latenciaMs: resumen(tiempos)
  };
}

// B. El mismo código en las dos tablets AL MISMO TIEMPO.
async function dobleEscaneo(cantidad) {
  const codigos = await sembrarAsistentes(cantidad);
  let entradasDobles = 0, entradasUnicas = 0, ninguna = 0;

  for (const asistente of codigos) {
    const [a, b] = await Promise.all([
      leerQr(OPERADORES[0], asistente),
      leerQr(OPERADORES[1], asistente)
    ]);
    const entraron = (a.permitido ? 1 : 0) + (b.permitido ? 1 : 0);
    if (entraron === 1) entradasUnicas++;
    else if (entraron === 2) entradasDobles++;
    else ninguna++;
  }

  return {
    escenario: 'B. Doble escaneo simultáneo',
    codigos: cantidad, entradasUnicas, entradasDobles, ninguna,
    correcto: entradasDobles === 0 && ninguna === 0
  };
}

// C. Muchas lecturas a la vez (como si hubiera `simultaneas` tablets).
async function estres(asistentes, simultaneas) {
  const codigos = await sembrarAsistentes(asistentes);
  const tiempos = [];
  let permitidos = 0, errores = 0, siguiente = 0;
  const inicio = Date.now();

  // Cada "tablet" toma el siguiente código libre de la lista.
  async function tablet(n) {
    while (siguiente < codigos.length) {
      const asistente = codigos[siguiente++];
      const r = await leerQr(OPERADORES[n % 2], asistente);
      tiempos.push(r.ms);
      if (r.permitido) permitidos++;
      if (r.error) errores++;
    }
  }
  await Promise.all(Array.from({ length: simultaneas }, (_, n) => tablet(n)));

  const segundos = (Date.now() - inicio) / 1000;
  return {
    escenario: `C. Estrés (${simultaneas} lecturas a la vez)`,
    asistentes, permitidos, errores,
    duracionSeg: +segundos.toFixed(2),
    lecturasPorSeg: +(asistentes / segundos).toFixed(1),
    latenciaMs: resumen(tiempos)
  };
}

// --- informe ---------------------------------------------------------------------
function tablaMarkdown(resultados, fecha) {
  const l = [];
  l.push('# Resultados de las pruebas de carga');
  l.push('');
  l.push(`Fecha (hora UTC): ${fecha}  `);
  l.push(`Equipo: ${require('os').cpus()[0].model}, Node ${process.version}  `);
  l.push('Entorno: emulador de Firestore con las reglas reales (`firestore.rules`). Datos 100 % falsos.');
  l.push('');
  l.push('| Escenario | Asistentes | Permitidos | Errores | Duración (s) | Lecturas/s | Promedio (ms) | p95 (ms) | Máx (ms) |');
  l.push('|---|---|---|---|---|---|---|---|---|');
  for (const r of resultados.filter((x) => x.latenciaMs)) {
    l.push(`| ${r.escenario} | ${r.asistentes} | ${r.permitidos} | ${r.errores} | ${r.duracionSeg} | ` +
      `${r.lecturasPorSeg} | ${r.latenciaMs.promedio} | ${r.latenciaMs.p95} | ${r.latenciaMs.maximo} |`);
  }
  const b = resultados.find((x) => x.entradasDobles !== undefined);
  if (b) {
    l.push('');
    l.push(`**Doble escaneo:** ${b.codigos} códigos leídos a la vez en dos tablets → ` +
      `${b.entradasUnicas} entraron una sola vez, ${b.entradasDobles} entraron dos veces, ` +
      `${b.ninguna} no entraron. ${b.correcto ? 'Correcto.' : 'FALLÓ.'}`);
  }
  l.push('');
  l.push('> La latencia es la de una lectura completa (crear `usos` + guardar la validación) en el');
  l.push('> emulador local, sin la demora de internet. La demora real con la tablet y la red de la');
  l.push('> universidad se mide aparte, en el simulacro.');
  return l.join('\n') + '\n';
}

async function main() {
  console.log('\n  Pruebas de carga contra el emulador ' + HOST + '\n');
  await sembrarOperadores();

  const resultados = [];
  for (const n of [110, 500, 1000]) {
    process.stdout.write(`  A. Flujo normal con ${n} asistentes... `);
    const r = await flujoNormal(n);
    console.log(`${r.duracionSeg} s, p95 ${r.latenciaMs.p95} ms, errores ${r.errores}`);
    resultados.push(r);
  }

  process.stdout.write('  B. Doble escaneo con 200 códigos... ');
  const b = await dobleEscaneo(200);
  console.log(`${b.entradasDobles} entradas dobles ${b.correcto ? '(correcto)' : '(FALLÓ)'}`);
  resultados.push(b);

  process.stdout.write('  C. Estrés con 1000 asistentes y 50 lecturas a la vez... ');
  const c = await estres(1000, 50);
  console.log(`${c.duracionSeg} s, p95 ${c.latenciaMs.p95} ms, errores ${c.errores}`);
  resultados.push(c);

  // Se guardan los resultados para el libro.
  const fecha = new Date().toISOString().slice(0, 16).replace('T', ' ');
  const carpeta = path.join(__dirname, 'resultados');
  fs.mkdirSync(carpeta, { recursive: true });
  const nombre = 'carga-' + fecha.replace(/[: ]/g, '-');
  fs.writeFileSync(path.join(carpeta, nombre + '.json'), JSON.stringify(resultados, null, 2));
  fs.writeFileSync(path.join(carpeta, nombre + '.md'), tablaMarkdown(resultados, fecha));
  console.log('\n  Resultados en pruebas-carga\\resultados\\' + nombre + '.md\n');

  // Falla si hubo entradas dobles o errores: así se nota de inmediato.
  const malos = resultados.some((r) => r.errores > 0 || r.correcto === false);
  process.exit(malos ? 1 : 0);
}

main().catch((e) => {
  console.error('\n[X] ' + e.message + '\n');
  process.exit(1);
});
