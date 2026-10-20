const { initializeApp, cert } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore } = require("firebase-admin/firestore");
const path = require("path");
const crypto = require("crypto");

const RUTA_CREDENCIAL = path.join("C:", "apolo_udes_fix", "claves", "serviceAccount.json");

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
  const args = process.argv.slice(2);

  if (args.includes("--listar")) {
    const snap = await db.collection("usuarios").get();
    console.log("\n  Usuarios registrados:\n");
    for (const doc of snap.docs) {
      const d = doc.data();
      console.log("  " + d.correo.padEnd(35) + d.rol.padEnd(12) + (d.puntoValidacion || ""));
    }
    console.log("");
    process.exit(0);
  }

  if (args.length < 2) {
    console.log("\n  Uso:");
    console.log("    node asignar-rol.js --listar");
    console.log("    node asignar-rol.js <correo> <rol> [punto]\n");
    console.log("  Roles: admin, operador, visualizador\n");
    process.exit(1);
  }

  const correo = args[0];
  const rol = args[1];
  const punto = args[2] || null;

  if (!["admin", "operador", "visualizador"].includes(rol)) {
    console.log("\n[X] Rol invalido. Use: admin, operador, visualizador\n");
    process.exit(1);
  }

  if (rol === "operador" && !punto) {
    console.log("\n[X] Un operador requiere punto de validacion.\n");
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