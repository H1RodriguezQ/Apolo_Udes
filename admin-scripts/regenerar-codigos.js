// ============================================================================
// Regenera los códigos de acceso viejos que se pueden adivinar.
//
// Antes los directivos recibían un código 'DIR-{id}-{milisegundos}', que se
// arma con solo saber la hora del registro, y su imagen QR se subía a un
// servicio público externo (i.ibb.co, campo qrUrl). Este script:
//   1. busca invitados y directivos cuyo código NO tiene el formato nuevo
//      (prefijo + 26 caracteres al azar) y les pone uno nuevo y seguro;
//   2. borra el campo qrUrl (el QR ya no se guarda afuera);
//   3. a los directivos les marca el correo como 'pendiente' para que Apps
//      Script les mande el código nuevo (el viejo deja de servir);
//   4. lista los documentos cuyo ID se puede adivinar (números de la hora o
//      'XLSX...'), para borrarlos antes de una ceremonia real.
//
// Uso (desde la carpeta admin-scripts):
//   node regenerar-codigos.js                 -> solo muestra lo que haría
//   node regenerar-codigos.js --aplicar       -> escribe los cambios
//   node regenerar-codigos.js --credencial C:\ruta\serviceAccount.json
// ============================================================================

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const crypto = require("crypto");
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

// Mismo alfabeto y formato que FirestoreService.generarCodigoAcceso en la app.
const ALFABETO = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function codigoNuevo(prefijo) {
  let codigo = prefijo + "-";
  for (let n = 0; n < 26; n++) {
    if (n > 0 && n % 6 === 0) codigo += "-";
    codigo += ALFABETO[crypto.randomInt(ALFABETO.length)];
  }
  return codigo;
}

// true si el código ya tiene el formato seguro: prefijo + 26 caracteres del
// alfabeto, separados en grupos de 6.
function esCodigoSeguro(codigo) {
  if (typeof codigo !== "string") return false;
  const partes = codigo.split("-");
  const prefijo = partes.shift();
  if (prefijo !== "INV" && prefijo !== "DIR") return false;
  const cuerpo = partes.join("");
  if (cuerpo.length !== 26) return false;
  return [...cuerpo].every((c) => ALFABETO.includes(c));
}

// Un ID se puede adivinar si son solo números (la hora en milisegundos) o si
// empieza por 'XLSX' (la hora de la importación del Excel).
function idAdivinable(id) {
  return /^\d{10,}$/.test(id) || id.startsWith("XLSX");
}

async function revisar(coleccion, prefijo, campoCorreo, aplicar) {
  const snap = await db.collection(coleccion).get();
  let cambiados = 0;
  const adivinables = [];

  for (const doc of snap.docs) {
    const d = doc.data();
    if (idAdivinable(doc.id)) adivinables.push(doc.id);

    const tieneCodigo = typeof d.codigoQr === "string" && d.codigoQr.length > 0;
    const necesitaCambio = (tieneCodigo && !esCodigoSeguro(d.codigoQr)) || d.qrUrl !== undefined;
    if (!necesitaCambio) continue;

    const cambios = { qrUrl: FieldValue.delete() };
    if (tieneCodigo && !esCodigoSeguro(d.codigoQr)) {
      cambios.codigoQr = codigoNuevo(prefijo);
      // El correo vuelve a salir con el código nuevo (solo directivos: a los
      // invitados se les reenvía desde la app, botón de reenviar).
      if (campoCorreo) cambios[campoCorreo] = "pendiente";
    }

    console.log("  " + coleccion.padEnd(11) + doc.id.padEnd(22) +
      (cambios.codigoQr ? "código viejo -> nuevo" : "solo se borra qrUrl"));
    if (aplicar) await doc.ref.update(cambios);
    cambiados++;
  }

  return { total: snap.size, cambiados, adivinables };
}

async function main() {
  const aplicar = process.argv.includes("--aplicar");
  console.log(aplicar ? "\n  Modo: APLICAR\n" : "\n  Modo: SIMULACION (usa --aplicar para escribir)\n");

  const dir = await revisar("directivos", "DIR", "correoInvitacion", aplicar);
  const inv = await revisar("invitados", "INV", null, aplicar);
  const grad = await db.collection("graduandos").get();
  const gradAdivinables = grad.docs.map((d) => d.id).filter(idAdivinable);

  console.log("\n  Directivos: " + dir.cambiados + " de " + dir.total + " con código viejo o qrUrl");
  console.log("  Invitados:  " + inv.cambiados + " de " + inv.total + " con código viejo o qrUrl");

  const todos = [
    ...gradAdivinables.map((id) => "graduandos/" + id),
    ...dir.adivinables.map((id) => "directivos/" + id),
    ...inv.adivinables.map((id) => "invitados/" + id)
  ];
  if (todos.length > 0) {
    console.log("\n  [!] Documentos con ID adivinable (bórralos antes de una ceremonia real):");
    for (const ruta of todos) console.log("      " + ruta);
  } else {
    console.log("\n  Ningún documento tiene ID adivinable.");
  }
  console.log("");
  process.exit(0);
}

main().catch(function (e) {
  console.error("\n[X] Error: " + e.message + "\n");
  process.exit(1);
});
