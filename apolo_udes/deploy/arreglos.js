// ===========================================================================
// Arreglos de datos previos al despliegue (TAREA 12) — SOLO LECTURA por defecto.
//
//   node arreglos.js <ruta/serviceAccount.json>            # simula y lista
//   node arreglos.js <ruta/serviceAccount.json> --aplicar  # escribe de verdad
//
// Qué corrige (nunca borra nada, solo añade lo que falta):
//   1. `graduandos_publico/{id}.cuposUsados` — el número REAL de cupos
//      ocupados. Sin él, la página pública cree que van 0 cupos y vuelve a
//      intentar ocupar el cupo 1, que ya existe: la regla lo rechaza y el
//      registro público queda bloqueado.
//   2. `invitados_documentos/{graduandoId}_{documento}` — el índice de
//      unicidad que usan las reglas para impedir cédulas duplicadas. Si
//      falta, se puede dar de alta un invitado con el mismo documento que
//      uno antiguo y las reglas no lo detectarían.
//
// Orden de ejecución: PRIMERO limpieza.js, DESPUÉS este archivo.
// ===========================================================================

const fs = require('fs');
const crypto = require('crypto');

const args = process.argv.slice(2);
const APLICAR = args.includes('--aplicar');
const RUTA = args.find((a) => !a.startsWith('--'));
if (!RUTA) { console.error('Uso: node arreglos.js <serviceAccount.json> [--aplicar]'); process.exit(2); }

const sa = JSON.parse(fs.readFileSync(RUTA, 'utf8'));
const PROJECT = sa.project_id;
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
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
  if (!r.ok) throw new Error(`token: ${j.error} ${j.error_description || ''}`);
  return j.access_token;
}

async function get(tok, ruta) {
  const r = await fetch(`${BASE}/${ruta}`, { headers: { Authorization: `Bearer ${tok}` } });
  if (r.status === 404) return null;
  const j = await r.json();
  if (!r.ok) throw new Error(`GET ${ruta}: HTTP ${r.status} ${j.error && j.error.message}`);
  return j;
}

async function listar(tok, coleccion) {
  const out = [];
  let pageToken = '';
  for (;;) {
    const url = `${BASE}/${coleccion}?pageSize=300${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
    const r = await fetch(url, { headers: { Authorization: `Bearer ${tok}` } });
    const j = await r.json();
    if (!r.ok) throw new Error(`LIST ${coleccion}: HTTP ${r.status}`);
    for (const d of (j.documents || [])) {
      out.push({ id: d.name.split('/').pop(), fields: d.fields || {} });
    }
    if (!j.nextPageToken) break;
    pageToken = j.nextPageToken;
  }
  return out;
}

const entero = (v) => (v && v.integerValue !== undefined ? Number(v.integerValue) : null);
const texto = (v) => (v && v.stringValue !== undefined ? v.stringValue : null);
const enteroBody = (n) => ({ integerValue: String(n) });

(async () => {
  const tok = await token();
  const plan = [];

  // ── 1) cuposUsados contra el número real de cupos ──────────────────────
  const graduandos = await listar(tok, 'graduandos');
  const cupos = await listar(tok, 'cupos');
  const publicos = new Map((await listar(tok, 'graduandos_publico')).map((d) => [d.id, d]));

  for (const g of graduandos) {
    const ocupados = cupos.filter((c) => c.id.startsWith(`${g.id}_`)).length;
    const pub = publicos.get(g.id);
    if (!pub) { console.log(`AVISO: ${g.id} no tiene espejo público (no se puede arreglar)`); continue; }
    const actual = entero(pub.fields.cuposUsados);
    if (actual === ocupados) continue;
    plan.push({
      accion: 'PATCH', ruta: `graduandos_publico/${g.id}`,
      detalle: `cuposUsados ${actual === null ? '(ausente)' : actual} -> ${ocupados}`,
      body: { fields: { cuposUsados: enteroBody(ocupados) } },
      mascara: 'cuposUsados',
    });
  }

  // ── 2) índice de unicidad que falte ─────────────────────────────────────
  const invitados = await listar(tok, 'invitados');
  const indices = new Map((await listar(tok, 'invitados_documentos')).map((d) => [d.id, d]));
  // documento -> invitadoId, para avisar si alguien duplica una cédula.
  const porDocumento = new Map();
  for (const i of invitados) {
    const doc = texto(i.fields.documento);
    if (doc) porDocumento.set(doc, i.id);
  }

  for (const i of invitados) {
    const g = texto(i.fields.graduandoId);
    const doc = texto(i.fields.documento);
    if (!g || !doc) { console.log(`AVISO: invitado ${i.id} sin graduandoId o documento`); continue; }
    const idIndice = `${g}_${doc}`;
    const existente = indices.get(idIndice);
    if (existente) {
      const dueno = texto(existente.fields.invitadoId);
      if (dueno !== i.id) console.log(`CONFLICTO: ${idIndice} ya apunta a ${dueno} y no a ${i.id} — revisar a mano`);
      continue;
    }
    const otros = invitados.filter((x) => texto(x.fields.documento) === doc && x.id !== i.id);
    if (otros.length) { console.log(`CONFLICTO: documento repetido entre ${[i.id, ...otros.map((o) => o.id)].join(', ')} — revisar a mano`); continue; }
    plan.push({
      accion: 'PUT', ruta: `invitados_documentos/${idIndice}`,
      detalle: `índice para invitado ${i.id}`,
      body: { fields: {
        graduandoId: { stringValue: g },
        documento: { stringValue: doc },
        invitadoId: { stringValue: i.id },
      } },
    });
  }

  // ── Resultado ───────────────────────────────────────────────────────────
  if (!plan.length) {
    console.log('Nada que arreglar: los contadores y los índices ya están cuadrados.');
    return;
  }
  console.log(`${APLICAR ? 'Aplicando' : 'Plan de arreglos'} (${plan.length}):`);
  for (const p of plan) console.log(`  ${p.accion.padEnd(5)} ${p.ruta}  — ${p.detalle}`);
  if (!APLICAR) { console.log('\nNo se escribió nada. Repite con --aplicar para aplicarlo.'); return; }

  for (const p of plan) {
    const url = `${BASE}/${p.ruta}${p.mascara ? `?updateMask.fieldPaths=${p.mascara}` : ''}`;
    const r = await fetch(url, {
      method: p.accion,
      headers: { Authorization: `Bearer ${tok}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(p.body),
    });
    const txt = await r.text();
    if (!r.ok) { console.error(`FALLO ${p.ruta}: HTTP ${r.status} ${txt.slice(0, 200)}`); process.exitCode = 1; }
    else console.log(`OK ${p.ruta}`);
  }
})().catch((e) => { console.error('FALLO: ' + e.message); process.exit(1); });
