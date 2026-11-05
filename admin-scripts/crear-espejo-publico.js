const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const path = require("path");

// Por defecto la llave está en C:\Apolo-Udes\claves (carpeta que nunca se sube).
const i = process.argv.indexOf("--credencial");
const RUTA_CREDENCIAL = i > -1
  ? process.argv[i + 1]
  : path.join("C:", "Apolo-Udes", "claves", "serviceAccount.json");

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

    // invitadosPermitidos tiene que ir en el espejo: las reglas lo leen para
    // dejar ocupar el tercer cupo cuando hay un invitado adicional autorizado.
    const publico = {
      nombreCompleto: nombreCompleto,
      programa: d.programa || "",
      facultad: d.facultad || "",
      invitadosPermitidos: Number.isInteger(d.invitadosPermitidos) ? d.invitadosPermitidos : 2
    };

    if (aplicar) {
      // merge: no se borra cuposUsados, que lo lleva la página pública.
      // Sin merge, volver a correr el script dejaba los cupos en cero y
      // permitía registrar más invitados de la cuenta.
      lote.set(db.collection("graduandos_publico").doc(doc.id), publico, { merge: true });
      enLote++;
      if (enLote === 450) {
        await lote.commit();
        lote = db.batch();
        enLote = 0;
      }
    } else {
      console.log("  " + doc.id.padEnd(22) + nombreCompleto + "  (cupos: " + publico.invitadosPermitidos + ")");
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