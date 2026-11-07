// ============================================================================
// Respaldo de la base de datos de Apolo en un archivo JSON.
//
// El plan gratuito de Firebase no hace copias automáticas, así que este
// script las hace a mano. Correrlo antes de cada ceremonia, antes de
// importar un Excel grande y antes de limpiar datos.
//
// El archivo queda en C:\Apolo-Udes\claves\respaldos (tiene datos
// personales: esa carpeta NUNCA se sube a GitHub ni se comparte).
//
// Uso (desde la carpeta admin-scripts):
//   node respaldo.js
//   node respaldo.js --credencial C:\ruta\serviceAccount.json
// ============================================================================

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const fs = require("fs");
const path = require("path");

const CARPETA_CLAVES = path.join("C:", "Apolo-Udes", "claves");
const i = process.argv.indexOf("--credencial");
const RUTA_CREDENCIAL = i > -1 ? process.argv[i + 1] : path.join(CARPETA_CLAVES, "serviceAccount.json");

let serviceAccount;
try {
  serviceAccount = require(RUTA_CREDENCIAL);
} catch (e) {
  console.error("\n[X] No se encontro la credencial en:\n    " + RUTA_CREDENCIAL + "\n");
  process.exit(1);
}

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

// Todas las colecciones que usa Apolo.
const COLECCIONES = [
  "graduandos", "graduandos_publico", "invitados", "cupos", "directivos",
  "usuarios", "configuracion", "validaciones", "usos", "auditoria", "solicitudes_correo"
];

// Las fechas de Firestore se guardan como texto ISO para que el JSON se lea.
function limpiar(valor) {
  if (valor instanceof Timestamp) return { _fecha: valor.toDate().toISOString() };
  if (Array.isArray(valor)) return valor.map(limpiar);
  if (valor && typeof valor === "object") {
    const r = {};
    for (const [k, v] of Object.entries(valor)) r[k] = limpiar(v);
    return r;
  }
  return valor;
}

async function main() {
  const respaldo = { creado: new Date().toISOString(), proyecto: serviceAccount.project_id, colecciones: {} };
  let total = 0;
  for (const c of COLECCIONES) {
    const snap = await db.collection(c).get();
    respaldo.colecciones[c] = {};
    snap.docs.forEach((d) => (respaldo.colecciones[c][d.id] = limpiar(d.data())));
    total += snap.size;
    console.log("  " + c.padEnd(20) + snap.size + " documentos");
  }

  const carpeta = path.join(CARPETA_CLAVES, "respaldos");
  fs.mkdirSync(carpeta, { recursive: true });
  const archivo = path.join(carpeta, "respaldo-" + respaldo.creado.slice(0, 19).replace(/[:T]/g, "-") + ".json");
  fs.writeFileSync(archivo, JSON.stringify(respaldo, null, 2));
  console.log("\n  [OK] " + total + " documentos guardados en\n       " + archivo + "\n");
  process.exit(0);
}

main().catch((e) => {
  console.error("\n[X] Error: " + e.message + "\n");
  process.exit(1);
});
