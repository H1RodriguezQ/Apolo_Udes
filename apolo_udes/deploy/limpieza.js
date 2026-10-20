// ===========================================================================
// Limpieza de datos de PRUEBA en producción (TAREA 12) — SOLO LECTURA por defecto.
//
//   node limpieza.js <ruta/serviceAccount.json>            # lista lo que borraría
//   node limpieza.js <ruta/serviceAccount.json> --aplicar  # borra de verdad
//
// Qué borra: graduandos de prueba (y su espejo público), sus cupos, sus
// invitados, los índices que apunten a ellos y los escaneos `tipo=desconocido`
// del punto de validación. Es decir, TODO salvo el graduando protegido.
//
// Qué NUNCA toca (se comprueba antes de cada borrado, no por confianza):
//   - El documento protegido y todo lo que le pertenece.
//   - `usuarios`, `configuracion`, `directivos`, `auditoria` y
//     `solicitudes_correo`: cuentas, configuración del evento y bitácora.
//
// IMPORTANTE: el borrado es IRREVERSIBLE. Copia de seguridad recomendada antes:
//   gcloud firestore export gs://<bucket>/backup
// ===========================================================================

const fs = require('fs');
const crypto = require('crypto');

const args = process.argv.slice(2);
const APLICAR = args.includes('--aplicar');
const RUTA = args.find((a) => !a.startsWith('--'));
if (!RUTA) { console.error('Uso: node limpieza.js <serviceAccount.json> [--aplicar]'); process.exit(2); }

const sa = JSON.parse(fs.readFileSync(RUTA, 'utf8'));
const PROJECT = sa.project_id;
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

// Graduando protegido por orden del plan de trabajo: NO se borra jamás.
const PROTEGIDO = '8GikxFi3DOqkqUfe7u1m';
// Colecciones que este script no toca bajo ninguna circunstancia.
const RESERVADAS = ['usuarios', 'configuracion', 'directivos', 'auditoria', 'solicitudes_correo'];

const b64u = (b) => Buffer.from(b).toString('base64url');

async function token() {
  const now = Math.floor(Date.now() / 1000);
  const head = b64u(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const body = b64u(JSON.stringify({
    iss: sa.client_email, scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  }));
  const jwt = `${head}.${body}.${b64u(crypto.createSign('RSA-SHA256').update(`${head}.${body}`).sign(sa.private_key))}`;
  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`token: ${j.error}`);
  return j.access_token;
}

async function listar(tok, coleccion) {
  const out = [];
  let pageToken = '';
  for (;;) {
    const url = `${BASE}/${coleccion}?pageSize=300${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
    const r = await fetch(url, { headers: { Authorization: `Bearer ${tok}` } });
    const j = await r.json();
    if (!r.ok) throw new Error(`LIST ${coleccion}: HTTP ${r.status}`);
    for (const d of (j.documents || [])) out.push({ id: d.name.split('/').pop(), fields: d.fields || {} });
    if (!j.nextPageToken) break;
    pageToken = j.nextPageToken;
  }
  return out;
}

const texto = (v) => (v && v.stringValue !== undefined ? v.stringValue : null);

// Regla única: `true` si el documento SE QUEDA. Todo lo no protegido se borra.
function seQueda(coleccion, d) {
  if (d.id === PROTEGIDO || d.id.startsWith(`${PROTEGIDO}_`)) return true; // protegido (y sus cupos/índices)
  switch (coleccion) {
    case 'graduandos':
    case 'graduandos_publico':
    case 'validaciones':
      return false; // datos de prueba
    case 'cupos':
      return texto(d.fields.graduandoId) === PROTEGIDO;
    case 'invitados':
      return texto(d.fields.graduandoId) === PROTEGIDO;
    case 'invitados_documentos':
      return texto(d.fields.graduandoId) === PROTEGIDO;
    default:
      return true; // cualquier otra colección queda intacta
  }
}

(async () => {
  const tok = await token();
  const colecciones = ['graduandos', 'graduandos_publico', 'cupos', 'invitados', 'invitados_documentos', 'validaciones'];
  const borrables = [];

  for (const c of colecciones) {
    if (RESERVADAS.includes(c)) { console.log(`IGNORADA (reservada): ${c}`); continue; }
    const docs = await listar(tok, c);
    const quedan = docs.filter((d) => seQueda(c, d));
    const van = docs.filter((d) => !seQueda(c, d));
    console.log(`${c.padEnd(22)} total ${String(docs.length).padStart(3)} | quedan ${String(quedan.length).padStart(3)} | borran ${van.length}`);
    for (const d of van) borrables.push({ coleccion: c, id: d.id });
  }

  console.log(`\nTotal a borrar: ${borrables.length}`);
  console.log(`Protegido ${PROTEGIDO}: ${borrables.some((b) => b.id.includes(PROTEGIDO)) ? '¡ALGO LO MARCA COMO BORRABLE, REVISAR!' : 'no aparece en la lista (correcto)'}`);

  fs.writeFileSync(
    'lista-borrar.json',
    JSON.stringify({ generado: new Date().toISOString(), total: borrables.length, documentos: borrables }, null, 2),
    'utf8',
  );
  console.log('Lista guardada en lista-borrar.json');

  if (!APLICAR) { console.log('\nNo se borró nada. Repite con --aplicar para ejecutarlo.'); return; }

  let ok = 0, fallos = 0;
  for (const b of borrables) {
    // Segundísima comprobación justo antes de borrar.
    if (RESERVADAS.includes(b.coleccion) || b.id === PROTEGIDO) { console.log(`SALTADO (protegido): ${b.coleccion}/${b.id}`); continue; }
    const r = await fetch(`${BASE}/${b.coleccion}/${b.id}`, {
      method: 'DELETE', headers: { Authorization: `Bearer ${tok}` },
    });
    if (r.ok) ok++; else { fallos++; console.error(`FALLO ${b.coleccion}/${b.id}: HTTP ${r.status}`); }
  }
  console.log(`\nBorrados: ${ok} | fallos: ${fallos}`);
  if (fallos) process.exitCode = 1;
})().catch((e) => { console.error('FALLO: ' + e.message); process.exit(1); });
