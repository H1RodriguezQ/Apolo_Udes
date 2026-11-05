// Borra los documentos de prueba con ID adivinable (hora en milisegundos o
// 'XLSX...') y lo que depende de ellos: espejo publico, invitados y cupos.
// Los registros de entrada (usos, validaciones) y la bitacora NO se tocan.
// Antes de borrar guarda un respaldo en C:\Apolo-Udes\claves (nunca se sube).
//
//   node borrar-pruebas.js            -> solo muestra lo que borraria
//   node borrar-pruebas.js --aplicar  -> guarda el respaldo y borra

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
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

// Mismo criterio que regenerar-codigos.js.
function idAdivinable(id) {
  return /^\d{10,}$/.test(id) || id.startsWith("XLSX");
}

async function main() {
  const aplicar = process.argv.includes("--aplicar");
  console.log(aplicar ? "\n  Modo: APLICAR (borra)\n" : "\n  Modo: SIMULACION (usa --aplicar para borrar)\n");

  const aBorrar = [];
  const respaldo = {};
  function agregar(doc) {
    if (respaldo[doc.ref.path]) return;
    aBorrar.push(doc.ref);
    respaldo[doc.ref.path] = doc.data();
  }

  // 1) Graduandos de prueba y lo que cuelga de ellos.
  const graduandos = await db.collection("graduandos").get();
  for (const g of graduandos.docs.filter((d) => idAdivinable(d.id))) {
    agregar(g);
    const publico = await db.collection("graduandos_publico").doc(g.id).get();
    if (publico.exists) agregar(publico);
    const invitados = await db.collection("invitados").where("graduandoId", "==", g.id).get();
    invitados.docs.forEach(agregar);
    const cupos = await db.collection("cupos").where("graduandoId", "==", g.id).get();
    cupos.docs.forEach(agregar);
    console.log("  graduandos/" + g.id.padEnd(22) + (g.data().nombreCompleto || "") +
      "  (+" + invitados.size + " invitados, " + cupos.size + " cupos)");
  }

  // 2) Directivos e invitados sueltos con ID adivinable.
  for (const coleccion of ["directivos", "invitados"]) {
    const snap = await db.collection(coleccion).get();
    for (const d of snap.docs.filter((x) => idAdivinable(x.id))) {
      agregar(d);
      console.log("  " + (coleccion + "/" + d.id).padEnd(33) + (d.data().nombre || d.data().nombreCompleto || ""));
    }
  }

  console.log("\n  Total de documentos a borrar: " + aBorrar.length);
  if (aBorrar.length === 0 || !aplicar) { console.log(""); process.exit(0); }

  // 3) Respaldo antes de borrar.
  const fecha = new Date().toISOString().slice(0, 19).replace(/[:T]/g, "-");
  const archivo = path.join(CARPETA_CLAVES, "respaldo-pruebas-" + fecha + ".json");
  fs.writeFileSync(archivo, JSON.stringify(respaldo, null, 2));
  console.log("  Respaldo guardado en " + archivo);

  // 4) Borrado en lotes (maximo 500 operaciones por lote).
  for (let n = 0; n < aBorrar.length; n += 450) {
    const lote = db.batch();
    aBorrar.slice(n, n + 450).forEach((ref) => lote.delete(ref));
    await lote.commit();
  }

  // 5) Constancia en la bitacora.
  await db.collection("auditoria").add({
    autorId: "script-admin", autorCorreo: "borrar-pruebas.js", autorRol: "Administrador",
    accion: "Limpieza de datos de prueba",
    detalle: "Se borraron " + aBorrar.length + " documentos con ID adivinable",
    tipo: "mantenimiento", fecha: new Date()
  });

  console.log("  [OK] " + aBorrar.length + " documentos borrados.\n");
  process.exit(0);
}

main().catch(function (e) {
  console.error("\n[X] Error: " + e.message + "\n");
  process.exit(1);
});
