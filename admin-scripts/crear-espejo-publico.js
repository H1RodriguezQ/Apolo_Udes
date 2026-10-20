const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const path = require("path");

const RUTA_CREDENCIAL = path.join("C:", "apolo_udes_fix", "claves", "serviceAccount.json");

let serviceAccount;
try {
  serviceAccount = require(RUTA_CREDENCIAL);
} catch (e) {
  console.error("\n[X] No se encontro la credencial en:\n    " + RUTA_CREDENCIAL + "\n");
  process.exit(1);
}

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

async function main() {
  const aplicar = process.argv.includes("--aplicar");
  const snap = await db.collection("graduandos").get();

  if (snap.empty) {
    console.log("\n  No hay graduandos registrados. Nada que migrar.\n");
    process.exit(0);
  }

  console.log("\n  " + snap.size + " graduando(s) encontrado(s).");
  console.log(aplicar ? "  Modo: APLICAR\n" : "  Modo: SIMULACION (usa --aplicar para escribir)\n");

  let lote = db.batch();
  let enLote = 0;
  let total = 0;
  let sinNombre = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    const nombreCompleto = d.nombreCompleto ||
      [d.nombres, d.apellidos].filter(Boolean).join(" ").trim();

    if (!nombreCompleto) {
      sinNombre++;
      console.log("  [!] " + doc.id + " sin nombre; se omite");
      continue;
    }

    const publico = {
      nombreCompleto: nombreCompleto,
      programa: d.programa || "",
      facultad: d.facultad || ""
    };

    if (aplicar) {
      lote.set(db.collection("graduandos_publico").doc(doc.id), publico);
      enLote++;
      if (enLote === 450) {
        await lote.commit();
        lote = db.batch();
        enLote = 0;
      }
    } else {
      console.log("  " + doc.id.padEnd(22) + nombreCompleto);
    }
    total++;
  }

  if (aplicar && enLote > 0) await lote.commit();

  console.log("\n  " + total + " espejo(s) " + (aplicar ? "creados" : "por crear"));
  if (sinNombre > 0) console.log("  " + sinNombre + " omitido(s) por falta de nombre");
  console.log("");

  if (aplicar) {
    const verif = await db.collection("graduandos_publico").get();
    console.log("  Verificacion: " + verif.size + " documento(s) en graduandos_publico\n");
  }

  process.exit(0);
}

main().catch(function (e) {
  console.error("\n[X] Error: " + e.message + "\n");
  process.exit(1);
});