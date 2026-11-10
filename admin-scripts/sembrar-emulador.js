// Llena los EMULADORES locales con datos inventados para revisar el diseño y
// tomar capturas. Nunca toca la base real: si no está FIRESTORE_EMULATOR_HOST,
// se niega a correr.
//
// Uso (con `firebase emulators:start --only auth,firestore` abierto):
//   set FIRESTORE_EMULATOR_HOST=localhost:8080
//   set FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
//   node sembrar-emulador.js
//
// Usuarios de prueba (solo existen en el emulador):
//   admin@prueba.test    / Prueba-Apolo-2026  (administrador)
//   operador@prueba.test / Prueba-Apolo-2026  (operador, entrada "Puerta 1")
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  console.error("[X] Falta FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST: este script es solo para el emulador.");
  process.exit(1);
}

initializeApp({ projectId: "apolo-udes" });
const auth = getAuth();
const db = getFirestore();
const CLAVE = "Prueba-Apolo-2026";

// Mezcla de datos normales y del peor caso real (nombres largos, una letra...).
const GRADUANDOS = [
  ["María Fernanda de los Ángeles", "Rodríguez-Kowalczyk Wiśniewska", "Ingeniería de Sistemas", "Ingenierías"],
  ["Jo", "Ruiz", "Derecho", "Ciencias Sociales"],
  ["Carlos Andrés", "Pérez Gómez", "Medicina", "Ciencias de la Salud"],
  ["Laura", "Martínez", "Administración de Empresas", "Ciencias Económicas"],
  ["José", "Ñúñez O'Connor", "Ingeniería Industrial", "Ingenierías"],
  ["Ana Sofía", "Castro", "Psicología", "Ciencias de la Salud"],
  ["Bartholomew", "Fitzgerald Montgomery", "Contaduría Pública", "Ciencias Económicas"],
  ["Valentina", "López Hernández", "Enfermería", "Ciencias de la Salud"],
];

async function usuario(correo, nombre, rol, punto) {
  let u;
  try { u = await auth.getUserByEmail(correo); }
  catch { u = await auth.createUser({ email: correo, password: CLAVE, emailVerified: true, displayName: nombre }); }
  await db.doc(`usuarios/${u.uid}`).set({
    nombre, correo, rol, estado: "activo",
    puntoValidacion: punto ?? null,
  });
  return u.uid;
}

async function main() {
  const admin = await usuario("admin@prueba.test", "Administradora de Prueba", "admin");
  await usuario("operador@prueba.test", "Operador Puerta Uno", "operador", "Puerta 1");

  const hoy = new Date();
  await db.doc("configuracion/evento").set({
    aforoDisponible: 600,
    lugar: "Auditorio Mayor",
    lugarCeremonia: "Auditorio Mayor Jorge Eliécer Gaitán, Campus Universitario Lagos del Cacique",
    direccion: "Calle 70 # 55-210",
    ciudad: "Bucaramanga",
    numeroCeremonia: "Ceremonia 2 de 3",
    fechaCeremonia: Timestamp.fromDate(new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate(), 15, 0)),
    horasPorFacultad: { "Ingenierías": "3:00 p. m.", "Ciencias de la Salud": "5:00 p. m." },
  });

  const lote = db.batch();
  let n = 0;
  for (const [nombres, apellidos, programa, facultad] of GRADUANDOS) {
    n++;
    const id = `grad${n}`;
    const nombreCompleto = `${nombres} ${apellidos}`;
    const estado = n % 4 === 0 ? "pendiente" : "activo";
    lote.set(db.doc(`graduandos/${id}`), {
      id, nombres, apellidos, nombreCompleto,
      documento: String(1098000000 + n * 7351),
      codigoEstudiantil: `U00${150000 + n}`,
      programa, facultad,
      correo: n === 7 ? "bartholomew.fitzgerald@northwind-industries-holdings.example.com" : `graduando${n}@udes.edu.co`,
      telefono: `31${n}5550${100 + n}`,
      horaCeremonia: n % 2 ? "3:00 p. m." : "5:00 p. m.",
      estado, invitadosRegistrados: n % 3 !== 0, invitadosPermitidos: n === 3 ? 3 : 2,
      correoRegistro: ["enviado", "pendiente", "error"][n % 3],
      fechaRegistro: Timestamp.now(),
    });
    lote.set(db.doc(`graduandos_publico/${id}`), {
      nombreCompleto, programa, facultad, invitadosPermitidos: n === 3 ? 3 : 2, cuposUsados: n % 3 !== 0 ? 2 : 0,
    });
    if (n % 3 === 0) continue;
    const invitados = [
      [`Madre de ${nombres.split(" ")[0]}`, "principal", n % 2 ? "confirmado" : null],
      [n === 1 ? "Aleksandra Wiśniewska-Kowalczyk de Montenegro" : `Acompañante ${n}`, "secundaria", n === 5 ? "rechazado" : null],
    ];
    invitados.forEach(([nombreInvitado, tipo, confirmacion], k) => {
      const iid = `inv${n}_${k + 1}`;
      lote.set(db.doc(`invitados/${iid}`), {
        id: iid, graduandoId: id, graduandoNombre: nombreCompleto, nombreInvitado,
        correoInvitado: `invitado${n}${k}@correo.com`, documento: String(63000000 + n * 100 + k),
        tipo, estado: "pendiente", cupo: k + 1, fechaRegistro: Timestamp.now(),
        codigoQr: `QR${n}${k}ABCDEF`, ...(confirmacion ? { confirmacion } : {}),
      });
    });
  }

  const directivos = [
    ["Dra. Patricia Elena Quintero de la Torre", "Rectora", "confirmado"],
    ["Ing. Luis Fernando Gómez", "Decano de Ingenierías", "pendiente"],
    ["Dr. Andrés Mejía", "Secretario General", "rechazado"],
  ];
  directivos.forEach(([nombre, cargo, conf], k) => {
    lote.set(db.doc(`directivos/dir${k + 1}`), {
      nombre, cargo, correo: `directivo${k + 1}@udes.edu.co`, facultad: "Rectoría",
      confirmacion: conf, correoInvitacion: "enviado", codigoQr: `DIR${k + 1}QRCODE`,
    });
  });

  // Lecturas de hoy: entradas cada pocos minutos desde hace una hora.
  for (let k = 0; k < 40; k++) {
    const hora = new Date(Date.now() - (60 - k * 1.5) * 60000);
    const resultado = k % 9 === 0 ? "invalido" : k % 7 === 0 ? "usado" : "valido";
    lote.set(db.doc(`validaciones/val${k}`), {
      codigo: `QR${k}XYZ`, nombre: resultado === "invalido" ? "" : `Invitado número ${k}`,
      tipo: "invitado", resultado, puntoValidacion: k % 2 ? "Puerta 1" : "Puerta 2",
      operadorId: admin, operadorCorreo: "operador@prueba.test", timestamp: Timestamp.fromDate(hora),
    });
  }
  await lote.commit();
  console.log("Listo: emulador sembrado.");
}

main().catch((e) => { console.error(e); process.exit(1); });
