// ============================================================================
// Datos falsos para las pruebas de carga.
// Todo es inventado: nombres, cédulas y correos no corresponden a nadie real.
// Los formatos cumplen las mismas validaciones que firestore.rules, para que
// las pruebas no fallen por un dato mal armado sino por lo que se quiere medir.
// ============================================================================

const crypto = require('crypto');

const NOMBRES = ['Laura', 'Andrés', 'Camila', 'Julián', 'Valentina', 'Santiago',
  'María José', 'Daniel', 'Sofía', 'Felipe', 'Natalia', 'Sergio', 'Paula',
  'Óscar', 'Daniela', 'Juan Pablo', 'Gloria', 'Ricardo', 'Elena', 'Jorge'];

const APELLIDOS = ['Méndez', 'Rojas', 'Duarte', 'Pinzón', 'Suárez', 'Cárdenas',
  'Prada', 'Ruiz', 'Gómez', 'Parra', 'Villamizar', 'Becerra', 'Rueda',
  'Ortiz', 'Castro', 'Morales', 'Ardila', 'Torres', 'Navarro', 'Rincón'];

const PROGRAMAS = [
  ['Ingeniería de Software', 'Ingenierías y Tecnologías'],
  ['Ingeniería de Sistemas', 'Ingenierías y Tecnologías'],
  ['Ingeniería Industrial', 'Ingenierías y Tecnologías'],
  ['Administración de Empresas', 'Ciencias Económicas, Administrativas y Contables'],
  ['Enfermería', 'Ciencias Médicas y de la Salud'],
  ['Derecho', 'Ciencias Jurídicas y Sociales']
];

// Mismo alfabeto que usa la app para los códigos (sin I, O, 0, 1).
const ALFABETO_CODIGO = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
// Alfabeto de los ID automáticos de Firestore (20 caracteres).
const ALFABETO_ID = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

function elegir(lista) {
  return lista[crypto.randomInt(lista.length)];
}

function textoAleatorio(alfabeto, largo) {
  let texto = '';
  for (let i = 0; i < largo; i++) texto += alfabeto[crypto.randomInt(alfabeto.length)];
  return texto;
}

// ID imposible de adivinar, como doc().id en la app.
function idAleatorio() {
  return textoAleatorio(ALFABETO_ID, 20);
}

// Código de acceso igual al de la app: INV-XXXXXX-XXXXXX-XXXXXX-XXXXXX-XX
function codigoAcceso(prefijo = 'INV') {
  const cuerpo = textoAleatorio(ALFABETO_CODIGO, 26);
  return prefijo + '-' + cuerpo.match(/.{1,6}/g).join('-');
}

// Cédulas de 8 a 10 dígitos que no empiezan en 0 y que no se repiten.
const cedulasUsadas = new Set();
function cedula() {
  let valor;
  do {
    const largo = 8 + crypto.randomInt(3);
    valor = String(1 + crypto.randomInt(9));
    for (let i = 1; i < largo; i++) valor += String(crypto.randomInt(10));
  } while (cedulasUsadas.has(valor));
  cedulasUsadas.add(valor);
  return valor;
}

// Quita tildes y espacios para armar un correo válido.
function sinTildes(texto) {
  return texto.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/\s+/g, '').toLowerCase();
}

function persona(numero) {
  const nombre = elegir(NOMBRES);
  const apellido1 = elegir(APELLIDOS);
  const apellido2 = elegir(APELLIDOS);
  return {
    nombres: nombre,
    apellidos: apellido1 + ' ' + apellido2,
    nombreCompleto: nombre + ' ' + apellido1 + ' ' + apellido2,
    documento: cedula(),
    correo: sinTildes(nombre) + '.' + sinTildes(apellido1) + numero + '@prueba.com'
  };
}

// Lista de graduandos falsos, cada uno con 2 cupos para invitados.
function graduandos(cantidad) {
  const lista = [];
  for (let i = 0; i < cantidad; i++) {
    const p = persona(i);
    const [programa, facultad] = elegir(PROGRAMAS);
    lista.push({
      id: idAleatorio(),
      nombres: p.nombres,
      apellidos: p.apellidos,
      nombreCompleto: p.nombreCompleto,
      documento: p.documento,
      correo: p.correo,
      programa: programa,
      facultad: facultad,
      invitadosPermitidos: 2
    });
  }
  return lista;
}

// Datos de un invitado como los llenaría alguien en invitados.html.
function invitado(numero) {
  const p = persona(10000 + numero);
  return { nombre: p.nombreCompleto, correo: p.correo, documento: p.documento };
}

module.exports = { graduandos, invitado, codigoAcceso, idAleatorio };
