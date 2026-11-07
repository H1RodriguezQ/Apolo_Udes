const { initializeApp, cert } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const path = require("path");
const crypto = require("crypto");

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
const auth = getAuth();
const db = getFirestore();

async function main() {
  // Se quitan --credencial y su ruta para que no se confundan con el correo.
  const args = process.argv.slice(2).filter((a, n, todos) =>
    a !== "--credencial" && todos[n - 1] !== "--credencial");

  if (args.includes("--listar")) {
    const snap = await db.collection("usuarios").get();
    console.log("\n  Usuarios registrados:\n");
    for (const doc of snap.docs) {
      const d = doc.data();
      console.log("  " + String(d.correo || "").padEnd(35) + String(d.rol || "").padEnd(12) +
        String(d.estado || "activo").padEnd(10) + (d.puntoValidacion || ""));
    }
    console.log("");
    process.exit(0);
  }

  if (args.length < 2) {
    console.log("\n  Uso:");
    console.log("    node asignar-rol.js --listar");
    console.log("    node asignar-rol.js <correo> <rol> [punto]\n");
    console.log("  Roles: admin, operador, consulta\n");
    process.exit(1);
  }

  const correo = args[0];
  const rol = args[1];
  const punto = args[2] || null;

  // Deben ser los mismos roles que acepta firestore.rules (perfilValido).
  // Antes decía 'visualizador', que las reglas no reconocen: ese usuario
  // quedaba sin acceso a nada.
  if (!["admin", "operador", "consulta"].includes(rol)) {
    console.log("\n[X] Rol invalido. Use: admin, operador, consulta\n");
    process.exit(1);
  }

  if (rol === "operador" && !punto) {
    console.log("\n[X] Un operador requiere punto de validacion.\n");
    process.exit(1);
  }

  // Las mismas entradas que la lista de la app (AppProvider.puntosDeEntrada).
  // Escrita distinta ("entrada 1"), la app la cuenta como otra entrada.
  const ENTRADAS = ["Entrada 1", "Entrada 2"];
  if (punto && !ENTRADAS.includes(punto)) {
    console.log('\n[X] Punto invalido. Use exactamente: "Entrada 1" o "Entrada 2"\n');
    process.exit(1);
  }

  try {
    let usuario;
    try {
      usuario = await auth.getUserByEmail(correo);
      console.log("\n  [i] Usuario existente: " + correo);
    } catch (e) {
      if (e.code === "auth/user-not-found") {
        const contrasenaTemp = crypto.randomBytes(12).toString("hex");
        usuario = await auth.createUser({
          email: correo,
          password: contrasenaTemp
        });
        console.log("\n  [+] Usuario creado: " + correo);
        console.log("  [i] Contraseña temporal: " + contrasenaTemp);
      } else {
        throw e;
      }
    }

    const uid = usuario.uid;
    await auth.setCustomUserClaims(uid, { rol: rol });
    await auth.revokeRefreshTokens(uid);

    const docUsuario = {
      uid: uid,
      correo: correo,
      rol: rol,
      puntoValidacion: punto || null,
      estado: "activo",
      creadoEn: new Date(),
      ultimaActualizacion: new Date()
    };

    await db.collection("usuarios").doc(uid).set(docUsuario, { merge: true });

    const docAuditoria = {
      uid: uid,
      correo: correo,
      accion: "crear_usuario_rol",
      rol: rol,
      punto: punto,
      timestamp: new Date()
    };

    await db.collection("auditoria").add(docAuditoria);

    console.log("  [✓] Rol asignado: " + rol);
    if (punto) console.log("  [✓] Punto: " + punto);
    console.log("");

  } catch (e) {
    console.error("\n[X] Error: " + e.message + "\n");
    process.exit(1);
  }
}

main();