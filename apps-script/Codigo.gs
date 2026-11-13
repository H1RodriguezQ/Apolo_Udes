/**
 * ===========================================================================
 *  APOLO UDES — servidor de correos (Google Apps Script + Gmail)
 * ===========================================================================
 *  Por qué existe este archivo y no un envío desde la app:
 *    · La app Flutter corre en tablets de personas ajenas a la organización.
 *      Si la contraseña del correo estuviera dentro del APK, cualquiera que lo
 *      descomprimiera podría leerla y mandar correos como la universidad.
 *    · El envío depende de que la tablet siga encendida y con datos. Aquí el
 *      correo lo manda Google, no la tablet.
 *  Por eso la app NO envía nada: escribe un documento en `solicitudes_correo`
 *  y este script (disparador cada 5 minutos) lo procesa.
 *
 *  Flujo:
 *    1. La app crea solicitudes_correo/{id} con estado 'pendiente'.
 *    2. procesarCorreos() busca las pendientes, arma el correo con la
 *       plantilla, lo manda con GmailApp y actualiza `enviados` y `estado`.
 *    3. También manda el enlace de registro a los graduandos con
 *       `correoRegistro: 'pendiente'`.
 *
 *  Archivos del proyecto:
 *    · Codigo.gs                  → este archivo (lógica + plantilla)
 *    · qr.gs                      → genera el PNG del código de acceso
 *    · plantilla-invitacion.html  → la plantilla tal como se ve en el navegador
 *    · sincronizar-plantilla.js   → copia el HTML dentro de PLANTILLA
 *
 *  Configuración del proyecto de Apps Script (Ajustes del proyecto):
 *    · Zona horaria: América/Bogotá
 *    · Idioma: español
 *    · Alcance adicional: https://www.googleapis.com/auth/datastore
 * ===========================================================================
 */

// ───────────────────────────── Configuración ─────────────────────────────

// Proyecto de Firebase donde vive todo el dato (no es un secreto: también va
// dentro del APK compilado).
const PROYECTO = 'apolo-udes';
const BASE =
  'https://firestore.googleapis.com/v1/projects/' +
  PROYECTO +
  '/databases/(default)/documents';

// Zona horaria de la ceremonia: las fechas y horas del correo se calculan aquí.
const ZONA = 'America/Bogota';

// Quién aparece como remitente visible del correo.
const REMITENTE = 'Ceremonia de Grado · Universidad de Santander';

// URL de la política de tratamiento de datos (Ley 1581). No se inventa: se
// pega aquí la página oficial cuando exista. Si queda vacía, el pie muestra
// el aviso igual pero sin el enlace.
const POLITICA_URL = '';

// URL absoluta del PNG de los logos oficiales, publicado en Firebase Hosting
// (carpeta web/correo/ del proyecto Flutter). Si
// queda vacía, el correo muestra el texto alternativo de la imagen, que es lo
// que hacen todos los clientes de correo cuando una imagen no carga.
const LOGOS_URL = 'cid:logos'; // imagen en línea, ver imagenes.gs

// URL absoluta del PNG del birrete dorado que va en el separador (Gmail y
// Outlook no muestran SVG). Si queda vacía, se usa un rombo dorado en texto.
const BIRRETE_URL = 'cid:birrete'; // imagen en línea, ver imagenes.gs

// Página pública donde el graduando se registra y ve su QR. Se usa en el
// correo de registro.
const INSCRIPCION_URL = 'https://apolo-udes.web.app/invitados.html';

// Página "Mi invitación" del invitado (su QR y los datos del evento). El
// correo enlaza a ella por si la persona lo borra o el QR no se ve.
const MI_INVITACION_URL = 'https://apolo-udes.web.app/confirmar.html';

// Correo que recibe la invitación de prueba cuando el proyecto de Apps Script
// no está enlazado a una hoja de cálculo (en ese caso el menú pregunta).
const CORREO_PRUEBA = 'quinterohenry1580@gmail.com';

// Texto que se pone cuando falta un dato (nunca se deja la marca {{...}}
// visible en el correo).
const POR_CONFIRMAR = 'Por confirmar';

// ───────────────────── Plantilla (HTML de la invitación) ─────────────────
// Es una COPIA EXACTA de plantilla-invitacion.html. Para cambiar el diseño:
// 1) edita el archivo .html,
// 2) ejecuta `node sincronizar-plantilla.js`,
// 3) vuelve a cargar el proyecto en Apps Script.
// Así no hay dos versiones de la plantilla.
const PLANTILLA = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <title>Invitación · Ceremonia de Graduación · Universidad de Santander</title>
  <!--
    Tipografía del mockup aprobado (Pinyon Script / Cormorant Garamond /
    Montserrat). Solo un <link>: Gmail lo descarta sin romper nada y los
    clientes que sí lo aplican (Apple Mail, móviles) se llevan la tipografía
    oficial. El resto cae en Georgia/Arial, que son las familias de respaldo
    de cada trazo. Las reglas de estilo van ABAJO y solo con @media (así lo
    exige Outlook, que ignora las clases).
  -->
  <link href="https://fonts.googleapis.com/css2?family=Pinyon+Script&family=Cormorant+Garamond:ital,wght@0,400;0,500;0,600;1,400&family=Montserrat:wght@500;600&display=swap" rel="stylesheet">
  <meta name="x-apple-disable-message-reformatting">
</head>
<body style="margin:0;padding:0;background-color:#dfe3ea;">

  <!--
    PREHEADER: la frase que Gmail y Outlook muestran junto al asunto. Se oculta
    dentro del cuerpo (display:none) para que no se vea dentro del correo.
  -->
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:#dfe3ea;">
    Su código de acceso para la ceremonia del {{fecha}}.
  </div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
         style="background-color:#dfe3ea;">
    <tr>
      <td class="exterior" align="center" style="padding:32px 12px;">

        <!-- ================= MARCO AZUL (#1b3463, con filetes dorados
             arriba y abajo, como en el mockup) ================= -->
        <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0"
               style="width:100%;max-width:600px;background-color:#1b3463;border-top:3px solid #b8975a;border-bottom:3px solid #b8975a;">
          <tr>
            <td class="marco" style="padding:12px;">

              <!-- ============ TARJETA CREMA ============ -->
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
                     style="background-color:#fbf8f1;border:1px solid #c2a05a;outline:4px solid #fbf8f1;outline-offset:-6px;">
                <tr>
                  <td style="padding:0;">

                    <!--
                      Esquinas art déco (64px): PNG exportado del SVG del
                      mockup (generar-birrete.js), con sus tres líneas y la
                      diagonal. El SVG no sobrevive a Gmail/Outlook y por CSS
                      no se puede dibujar la diagonal (habría que transformar
                      el elemento, y Outlook lo ignora).
                    -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td align="left" style="padding:4px 0 0 4px;line-height:0;">
                          <img src="{{esq_si_src}}" class="esq" width="64" height="64" alt=""
                               style="display:block;width:64px;height:64px;border:0;">
                        </td>
                        <td style="font-size:0;line-height:0;">&nbsp;</td>
                        <td align="right" style="padding:4px 4px 0 0;line-height:0;">
                          <img src="{{esq_sd_src}}" class="esq" width="64" height="64" alt=""
                               style="display:block;width:64px;height:64px;border:0;">
                        </td>
                      </tr>
                    </table>

                    <!-- CINTA "INVITACIÓN": degradado dorado del mockup; Outlook
                         ignora el degradado y se queda con el color plano. -->
                    <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center"
                           style="margin:2px auto 0 auto;">
                      <tr>
                        <td bgcolor="#c2a05a"
                            style="background-color:#c2a05a;background-image:linear-gradient(100deg,#9c7a3c 0%,#e3c983 35%,#b8954f 60%,#ecd497 80%,#a8853f 100%);padding:6px 18px;text-align:center;">
                          <span style="font-family:'Montserrat',Arial,Helvetica,sans-serif;font-size:10px;letter-spacing:4px;font-weight:600;color:#2c2210;">
                            INVITACIÓN
                          </span>
                        </td>
                      </tr>
                    </table>

                    <!-- TÍTULO CALIGRÁFICO A DOS TONOS: "Ceremonia de" en el
                         azul del marco (#1b3463) y "Graduación" en dorado
                         (#a6833f), igual que el mockup aprobado. -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td align="center" style="padding:10px 24px 0 24px;">
                          <span class="titulo" style="font-family:'Pinyon Script','Brush Script MT','Segoe Script',cursive;font-size:50px;line-height:1.15;color:#1b3463;">
                            Ceremonia de <span style="color:#a6833f;">Graduación</span>
                          </span>
                        </td>
                      </tr>
                    </table>

                    <!-- RECTORÍA -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td class="bloque" align="center" style="padding:22px 28px 0 28px;">
                          <span style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:20px;line-height:1.35;color:#2a2a2a;font-weight:600;">
                            El Rector General y el Consejo&nbsp;Académico de&nbsp;la Universidad de&nbsp;Santander
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td class="bloque" align="center" style="padding:10px 28px 0 28px;">
                          <span style="display:inline-block;max-width:420px;font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:16px;line-height:1.5;color:#4a4a4a;">
                            tienen el gusto de invitarle al acto académico mediante el cual se otorga
                            el título de profesionales, especialistas y&nbsp;magísteres.
                          </span>
                        </td>
                      </tr>
                    </table>

                    <!-- NOMBRE DEL INVITADO -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td class="bloque" align="center" style="padding:28px 40px 0 40px;">
                          <span style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-style:italic;font-size:15px;color:#6b6b6b;">
                            {{titulo_beneficiario}}
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td class="bloque" align="center" style="padding:2px 24px 0 24px;">
                          <span class="nombre" style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:28px;font-weight:500;color:#1b3463;letter-spacing:.5px;">
                            {{invitado}}
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td class="bloque" align="center" style="padding:6px 24px 0 24px;">
                          <span style="font-family:'Montserrat',Arial,Helvetica,sans-serif;font-size:11px;line-height:1.6;letter-spacing:.3px;color:#5f5f5f;">
                            {{en_nombre_de}}
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td class="bloque" align="center" style="padding:0 24px 0 24px;">
                          <span style="font-family:'Montserrat',Arial,Helvetica,sans-serif;font-size:11px;line-height:1.6;letter-spacing:.3px;color:#6b6b6b;">
                            {{cargo}}
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <td class="bloque" align="center" style="padding:0 24px 0 24px;">
                          <span style="font-family:'Montserrat',Arial,Helvetica,sans-serif;font-size:11px;line-height:1.6;letter-spacing:.3px;color:#6b6b6b;">
                            {{programa}}
                          </span>
                        </td>
                      </tr>
                    </table>

                    <!-- SEPARADOR CON BIRRETE: el adorno central del mockup,
                         servido como PNG (generado por generar-birrete.js
                         desde el SVG del mockup). Gmail y Outlook descartan
                         el SVG y varios clientes NO dibujan el emoji 🎓 —
                         salía como cajas con interrogación —, así que la
                         imagen es lo único que se ve en todas partes. -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td class="linea" width="110" style="width:110px;font-size:0;line-height:0;">
                          <div style="height:1px;line-height:1px;font-size:0;background:#d3bf93;">&nbsp;</div>
                        </td>
                        <td align="center" style="padding:0 12px;line-height:0;">
                          <img src="{{birrete_src}}" width="34" height="26" alt="Birrete de graduación"
                               style="display:block;width:34px;height:26px;border:0;margin:0 auto;">
                        </td>
                        <td class="linea" width="110" style="width:110px;font-size:0;line-height:0;">
                          <div style="height:1px;line-height:1px;font-size:0;background:#d3bf93;">&nbsp;</div>
                        </td>
                      </tr>
                    </table>

                    <!-- CEREMONIA / FECHA / HORA. valign="top" mantiene las
                         etiquetas a la misma altura; en pantallas muy angostas
                         las columnas se apilan (ver @media abajo). -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
                           style="margin-top:20px;">
                      <tr>
                        <td width="33%" class="col" valign="top" align="center"
                            style="padding:2px 6px;border-right:1px solid #e2d6b8;">
                          <span style="font-family:'Montserrat',Arial,Helvetica,sans-serif;font-size:11px;letter-spacing:1.5px;font-weight:600;color:#7a5f2f;">CEREMONIA</span><br>
                          <span style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:20px;color:#1b3463;">{{ceremonia}}</span>
                        </td>
                        <td width="34%" class="col" valign="top" align="center"
                            style="padding:2px 6px;border-right:1px solid #e2d6b8;">
                          <span style="font-family:'Montserrat',Arial,Helvetica,sans-serif;font-size:11px;letter-spacing:1.5px;font-weight:600;color:#7a5f2f;">FECHA</span><br>
                          <span style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:20px;color:#1b3463;">{{fecha}}</span><br>
                          <span style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-style:italic;font-size:14px;color:#6b6b6b;">{{dia_semana}}</span>
                        </td>
                        <td width="33%" class="col" valign="top" align="center" style="padding:2px 6px;">
                          <span style="font-family:'Montserrat',Arial,Helvetica,sans-serif;font-size:11px;letter-spacing:1.5px;font-weight:600;color:#7a5f2f;">HORA</span><br>
                          <span style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:20px;color:#1b3463;">{{hora}}</span>
                        </td>
                      </tr>
                      <tr>
                        <td colspan="3" align="center" style="padding:16px 6px 0 6px;">
                          <div style="width:60px;height:1px;background:#e2d6b8;margin:0 auto 14px;font-size:0;line-height:0;">&nbsp;</div>
                          <span style="font-family:'Montserrat',Arial,Helvetica,sans-serif;font-size:11px;letter-spacing:1.5px;font-weight:600;color:#7a5f2f;">LUGAR</span><br>
                          <span style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:19px;line-height:1.3;color:#1b3463;">
                            {{lugar}}
                          </span>
                        </td>
                      </tr>
                    </table>

                    <!-- NOTA EXTRA (recordatorio) -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td align="center" style="padding:10px 30px 0 30px;">
                          <span style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:15px;line-height:1.45;color:#5d5d5d;font-style:italic;">
                            {{nota_extra}}
                          </span>
                        </td>
                      </tr>
                    </table>

                    <!-- QR ENMARCADO EN DORADO (marco de 2px + doble filete
                         claro, como en el mockup; Outlook se queda con el
                         marco simple porque ignora box-shadow) -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td class="bloque" align="center" style="padding:22px 40px 0 40px;">
                          <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center"
                                 style="background-color:#ffffff;border:2px solid #b8975a;box-shadow:0 0 0 4px #fbf8f1,0 0 0 5px #d9c597;">
                            <tr>
                              <td style="padding:12px;line-height:0;">
                                <img src="{{qr_src}}" class="qr" width="148" height="148" alt="Código de acceso a la ceremonia"
                                     style="display:block;width:148px;height:148px;border:0;">
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                      <tr>
                        <td align="center" style="padding:10px 30px 0 30px;">
                          <span style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:14px;line-height:1.45;color:#5d5d5d;font-style:italic;">
                            Presente este código al ingresar, impreso o desde su celular.<br>
                            Es personal y válido para una sola entrada.
                          </span>
                        </td>
                      </tr>
                    </table>

                    <!-- LOGOS OFICIALES: la tira de tres logos del evento
                         (UDES + MEN + EQUAA). El mockup trae textos de
                         marcador porque los PNG oficiales aún no se habían
                         publicado; aquí va el archivo real. Si LOGOS_URL sigue
                         vacía, el servidor borra esta <img> antes de enviar. -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td align="center" style="padding:22px 40px 0 40px;">
                          <img src="{{logos_src}}" class="logos" width="460" height="auto"
                               alt="Universidad de Santander · Acreditación Alta Calidad · EQUAA"
                               style="display:block;width:100%;max-width:460px;height:auto;border:0;margin:0 auto;">
                        </td>
                      </tr>
                    </table>

                    <!-- Esquinas art déco (fila inferior), espejo de la superior -->
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td align="left" style="padding:0 0 4px 4px;line-height:0;">
                          <img src="{{esq_ii_src}}" class="esq" width="64" height="64" alt=""
                               style="display:block;width:64px;height:64px;border:0;">
                        </td>
                        <td style="font-size:0;line-height:0;">&nbsp;</td>
                        <td align="right" style="padding:0 4px 4px 0;line-height:0;">
                          <img src="{{esq_id_src}}" class="esq" width="64" height="64" alt=""
                               style="display:block;width:64px;height:64px;border:0;">
                        </td>
                      </tr>
                    </table>

                  </td>
                </tr>
              </table>
              <!-- ========== FIN TARJETA CREMA ========== -->

            </td>
          </tr>
        </table>
        <!-- ================= FIN MARCO AZUL ================= -->

        <!-- ============ PIE (Ley 1581) ============ -->
        <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0"
               style="width:100%;max-width:600px;">
          <tr>
            <td align="center" style="padding:16px 24px 0 24px;">
              <span style="font-family:Arial,Helvetica,sans-serif;font-size:11px;line-height:1.6;color:#6f7787;">
                Recibe este mensaje porque {{graduando}} lo registró como invitado. Sus datos se
                tratan según la Ley 1581 de 2012 y se eliminan al terminar el evento.
                <a href="{{politica_url}}" style="color:#1b3463;text-decoration:underline;">Política de tratamiento de datos</a>
              </span>
            </td>
          </tr>
        </table>

      </td>
    </tr>
  </table>

  <!-- SÓLO @media: las reglas de estilo de este correo se usan únicamente
       para el ajuste en pantallas pequeñas (520px y 360px). Todo lo demás va
       en línea, porque Outlook ignora las reglas de clases. -->
  <style>
    @media only screen and (max-width: 520px) {
      .exterior { padding: 12px 6px !important; }
      .marco    { padding: 8px !important; }
      .esq      { width: 40px !important; height: 40px !important; }
      .titulo   { font-size: 38px !important; line-height: 1.2 !important; }
      .bloque   { padding-left: 18px !important; padding-right: 18px !important; }
      .nombre   { font-size: 24px !important; }
      .linea    { width: 64px !important; }
      .qr       { width: 132px !important; height: 132px !important; }
    }
    @media only screen and (max-width: 360px) {
      .titulo   { font-size: 32px !important; }
      /* En pantallas muy angostas los tres datos se apilan */
      .col      { display: block !important; width: 100% !important; border-right: 0 !important;
                  padding: 8px 0 !important; border-bottom: 1px solid #e2d6b8 !important; }
      .logos    { width: 100% !important; max-width: 100% !important; }
    }
  </style>

</body>
</html>
`;

// ─────────────── Plantilla del correo con el enlace de registro ────────────

/**
 * Correo que recibe el GRADUANDO con su enlace personal para registrar a sus
 * invitados. Mismo diseño que la invitación (tarjeta crema, dorado, logos),
 * con un botón grande y los pasos explicados, porque lo abren personas de
 * todas las edades y casi siempre desde el celular.
 * Marcas: {{nombre}} {{programa}} {{cupos}} {{enlace}} {{fecha_texto}}
 *         {{logos_src}} {{birrete_src}} {{politica_url}}
 */
const PLANTILLA_REGISTRO = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="x-apple-disable-message-reformatting">
  <title>Registre a sus invitados · Ceremonia de Grado · Universidad de Santander</title>
  <link href="https://fonts.googleapis.com/css2?family=Pinyon+Script&family=Cormorant+Garamond:ital,wght@0,500;0,600;1,400&display=swap" rel="stylesheet">
  <style>
    @media only screen and (max-width: 520px) {
      .apo-exterior { padding: 14px 6px !important; }
      .apo-marco    { padding: 7px !important; }
      .apo-bloque   { padding-left: 18px !important; padding-right: 18px !important; }
      .apo-titulo   { font-size: 38px !important; line-height: 44px !important; }
      .apo-linea    { width: 60px !important; }
    }
  </style>
</head>
<body style="margin:0;padding:0;background-color:#DFE3EA;">

  <!-- PREHEADER: la frase que Gmail muestra junto al asunto. -->
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;font-size:1px;line-height:1px;color:#DFE3EA;">
    Registre aquí a las personas que lo acompañarán en su ceremonia de grado.
  </div>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#DFE3EA;">
    <tr>
      <td class="apo-exterior" align="center" style="padding:28px 12px;">

        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
               style="max-width:580px;background-color:#003A7D;border-top:3px solid #B8975A;border-bottom:3px solid #B8975A;">
          <tr>
            <td class="apo-marco" style="padding:11px;">

              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
                     style="background-color:#FBF8F1;border:1px solid #C2A05A;">

                <!-- Esquinas art déco superiores -->
                <tr>
                  <td style="padding:8px 8px 0 8px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td width="34" valign="top" style="width:34px;padding:0;line-height:0;font-size:0;">
                          <div style="width:34px;height:34px;border-top:1px solid #B8975A;border-left:1px solid #B8975A;">
                            <div style="width:24px;height:24px;margin:5px 0 0 5px;border-top:1px solid #B8975A;border-left:1px solid #B8975A;"></div>
                          </div>
                        </td>
                        <td style="font-size:0;line-height:0;">&nbsp;</td>
                        <td width="34" valign="top" style="width:34px;padding:0;line-height:0;font-size:0;">
                          <div style="width:34px;height:34px;border-top:1px solid #B8975A;border-right:1px solid #B8975A;">
                            <div style="width:24px;height:24px;margin:5px 0 0 4px;border-top:1px solid #B8975A;border-right:1px solid #B8975A;"></div>
                          </div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- CINTA -->
                <tr>
                  <td align="center" style="padding:0 24px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center">
                      <tr>
                        <td bgcolor="#C2A05A"
                            style="background-color:#C2A05A;background-image:linear-gradient(100deg,#9C7A3C 0%,#E3C983 35%,#B8954F 60%,#ECD497 80%,#A8853F 100%);padding:6px 20px;">
                          <span style="font-family:Arial,Helvetica,sans-serif;font-size:11px;letter-spacing:3px;color:#2C2210;font-weight:bold;">REGISTRO DE INVITADOS</span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- TÍTULO -->
                <tr>
                  <td class="apo-bloque" align="center" style="padding:10px 28px 0 28px;">
                    <div class="apo-titulo"
                         style="font-family:'Pinyon Script','Brush Script MT','Segoe Script',cursive;font-size:46px;line-height:52px;color:#004899;">
                      Sus <span style="color:#A6833F;">invitados</span>
                    </div>
                  </td>
                </tr>

                <!-- SEPARADOR CON BIRRETE -->
                <tr>
                  <td align="center" style="padding:16px 0 0 0;">
                    <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center">
                      <tr>
                        <td class="apo-linea" width="100" valign="middle" style="width:100px;">
                          <div style="height:1px;line-height:1px;font-size:0;background-color:#D3BF93;">&nbsp;</div>
                        </td>
                        <td valign="middle" style="padding:0 12px;line-height:0;">
                          <img src="{{birrete_src}}" width="34" height="26" alt=""
                               style="display:block;width:34px;height:26px;border:0;">
                        </td>
                        <td class="apo-linea" width="100" valign="middle" style="width:100px;">
                          <div style="height:1px;line-height:1px;font-size:0;background-color:#D3BF93;">&nbsp;</div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- SALUDO -->
                <tr>
                  <td class="apo-bloque" align="center" style="padding:20px 32px 0 32px;">
                    <div style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:24px;line-height:30px;color:#004899;font-weight:600;">
                      Hola, {{nombre}}
                    </div>
                    <div style="font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:19px;color:#5A5A5A;margin-top:4px;">
                      {{programa}}
                    </div>
                    <div style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:19px;line-height:27px;color:#2A2A2A;margin-top:14px;">
                      ¡Felicitaciones! Ya puede registrar a las personas que lo acompañarán en su ceremonia de&nbsp;grado.
                    </div>
                  </td>
                </tr>

                <!-- CUPOS Y FECHA -->
                <tr>
                  <td class="apo-bloque" align="center" style="padding:18px 34px 0 34px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"
                           style="border-top:1px solid #E2D6B8;border-bottom:1px solid #E2D6B8;">
                      <tr>
                        <td align="center" style="padding:12px 4px;">
                          <div style="font-family:Arial,Helvetica,sans-serif;font-size:11px;letter-spacing:1px;color:#7A5F2F;font-weight:bold;">PUEDE REGISTRAR</div>
                          <div style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:22px;line-height:28px;color:#004899;margin-top:2px;">{{cupos}}</div>
                        </td>
                      </tr>
                      <!--FECHA-INICIO-->
                      <tr>
                        <td align="center" style="padding:0 4px 12px 4px;">
                          <div style="font-family:Arial,Helvetica,sans-serif;font-size:11px;letter-spacing:1px;color:#7A5F2F;font-weight:bold;">CEREMONIA</div>
                          <div style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:20px;line-height:26px;color:#004899;margin-top:2px;">{{fecha_texto}}</div>
                        </td>
                      </tr>
                      <!--FECHA-FIN-->
                    </table>
                  </td>
                </tr>

                <!-- PASOS -->
                <tr>
                  <td class="apo-bloque" style="padding:20px 34px 0 34px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td width="34" valign="top" style="width:34px;padding:0 0 12px 0;">
                          <div style="width:26px;height:26px;border:1px solid #B8975A;border-radius:13px;text-align:center;font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:26px;color:#004899;font-weight:bold;">1</div>
                        </td>
                        <td valign="top" style="padding:2px 0 12px 8px;font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:18px;line-height:24px;color:#2A2A2A;">
                          Toque el botón <b>Registrar mis invitados</b>.
                        </td>
                      </tr>
                      <tr>
                        <td width="34" valign="top" style="width:34px;padding:0 0 12px 0;">
                          <div style="width:26px;height:26px;border:1px solid #B8975A;border-radius:13px;text-align:center;font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:26px;color:#004899;font-weight:bold;">2</div>
                        </td>
                        <td valign="top" style="padding:2px 0 12px 8px;font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:18px;line-height:24px;color:#2A2A2A;">
                          Escriba el nombre, el correo y el número de documento de cada invitado.
                        </td>
                      </tr>
                      <tr>
                        <td width="34" valign="top" style="width:34px;padding:0;">
                          <div style="width:26px;height:26px;border:1px solid #B8975A;border-radius:13px;text-align:center;font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:26px;color:#004899;font-weight:bold;">3</div>
                        </td>
                        <td valign="top" style="padding:2px 0 0 8px;font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:18px;line-height:24px;color:#2A2A2A;">
                          Cada invitado recibirá en su correo una invitación con su código QR de acceso.
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- BOTÓN (tabla: se ve igual en Gmail, Outlook y el celular) -->
                <tr>
                  <td class="apo-bloque" align="center" style="padding:24px 34px 0 34px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" width="100%" style="max-width:340px;">
                      <tr>
                        <td align="center" bgcolor="#004899" style="background-color:#004899;border-radius:4px;">
                          <a href="{{enlace}}" target="_blank"
                             style="display:block;padding:16px 18px;font-family:Arial,Helvetica,sans-serif;font-size:17px;line-height:22px;font-weight:bold;color:#FFFFFF;text-decoration:none;border-radius:4px;">
                            Registrar mis invitados
                          </a>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- ENLACE DE RESPALDO -->
                <tr>
                  <td class="apo-bloque" align="center" style="padding:14px 34px 0 34px;">
                    <div style="font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:18px;color:#5A5A5A;">
                      Si el botón no funciona, copie este enlace en el navegador:<br>
                      <a href="{{enlace}}" style="color:#004899;word-break:break-all;">{{enlace}}</a>
                    </div>
                    <div style="font-family:'Cormorant Garamond',Georgia,'Times New Roman',serif;font-size:16px;line-height:22px;color:#4A4A4A;font-style:italic;margin-top:12px;">
                      Este enlace es personal: no lo comparta.
                    </div>
                  </td>
                </tr>

                <!-- LOGOS OFICIALES -->
                <tr>
                  <td class="apo-bloque" align="center" style="padding:26px 30px 4px 30px;">
                    <img src="{{logos_src}}" width="460"
                         alt="Universidad de Santander · Acreditada Alta Calidad · Acreditación Internacional EQUAA"
                         style="display:block;width:100%;max-width:460px;height:auto;border:0;margin:0 auto;">
                  </td>
                </tr>

                <!-- Esquinas art déco inferiores -->
                <tr>
                  <td style="padding:0 8px 8px 8px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td width="34" valign="bottom" style="width:34px;padding:0;line-height:0;font-size:0;">
                          <div style="width:34px;height:34px;border-bottom:1px solid #B8975A;border-left:1px solid #B8975A;">
                            <div style="width:24px;height:24px;margin:4px 0 0 5px;border-bottom:1px solid #B8975A;border-left:1px solid #B8975A;"></div>
                          </div>
                        </td>
                        <td style="font-size:0;line-height:0;">&nbsp;</td>
                        <td width="34" valign="bottom" style="width:34px;padding:0;line-height:0;font-size:0;">
                          <div style="width:34px;height:34px;border-bottom:1px solid #B8975A;border-right:1px solid #B8975A;">
                            <div style="width:24px;height:24px;margin:4px 0 0 4px;border-bottom:1px solid #B8975A;border-right:1px solid #B8975A;"></div>
                          </div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

              </table>
            </td>
          </tr>
        </table>

        <!-- PIE (Ley 1581) -->
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:580px;">
          <tr>
            <td align="center" style="padding:16px 24px 0 24px;">
              <span style="font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:18px;color:#5F6876;">
                Recibe este mensaje porque está inscrito para la ceremonia de grado de la Universidad de Santander.
                Los datos de sus invitados se tratan según la Ley 1581 de 2012 y se eliminan al terminar el evento.
                <a href="{{politica_url}}" style="color:#004899;text-decoration:underline;">Política de tratamiento de datos</a>
              </span>
            </td>
          </tr>
        </table>

      </td>
    </tr>
  </table>

</body>
</html>
`;

/** Arma el correo de registro: quita lo que no aplica y rellena las marcas. */
function htmlRegistro(datos) {
  var html = PLANTILLA_REGISTRO;
  if (!datos.fecha_texto) {
    html = html.replace(/<!--FECHA-INICIO-->[\s\S]*?<!--FECHA-FIN-->/g, '');
  }
  if (!datos.logos_src) {
    html = html.replace(/<img[^>]*\{\{logos_src\}\}[\s\S]*?>/g, '');
  }
  if (!datos.birrete_src) {
    html = html.replace(/<img[^>]*\{\{birrete_src\}\}[\s\S]*?>/g,
      '<span style="font-family:Arial,sans-serif;font-size:10px;line-height:10px;color:#B8975A;">&#9670;</span>');
  }
  if (!datos.politica_url) {
    html = html.replace(/<a[^>]*\{\{politica_url\}\}[^>]*>[\s\S]*?<\/a>/g,
      'Política de tratamiento de datos');
  }
  return renderPlantilla(html, datos);
}

/** "sábado 12 de diciembre de 2026" (con el mes completo, para el correo de registro). */
function fechaLarga(timestamp) {
  if (!timestamp || !timestamp.timestampValue) return '';
  var meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  var f = new Date(timestamp.timestampValue);
  return DIAS[f.getDay()] + ' ' + f.getDate() + ' de ' + meses[f.getMonth()] + ' de ' + f.getFullYear();
}

/** Datos del correo de registro de UN graduando (documento de Firestore). */
function datosDeRegistro(graduando) {
  var id = graduando.name.split('/').pop();
  var evento = null;
  try { evento = leerDocumento('configuracion', 'evento'); } catch (e) { /* sin fecha */ }
  var fechaTs = evento && evento.fields ? evento.fields.fechaCeremonia : null;
  var permitidos = Number(campoDocumento(graduando, 'invitadosPermitidos', 2)) || 2;
  return {
    nombre: [campoDocumento(graduando, 'nombres', ''),
      campoDocumento(graduando, 'apellidos', '')].join(' ').trim() || 'graduando',
    programa: campoDocumento(graduando, 'programa', ''),
    cupos: permitidos + (permitidos === 1 ? ' invitado' : ' invitados'),
    // El enlace LLEVA el ID del graduando: sin él la página no sabe a quién
    // registrar y muestra "Enlace inválido".
    enlace: INSCRIPCION_URL + '?id=' + encodeURIComponent(id),
    fecha_texto: fechaLarga(fechaTs),
    logos_src: LOGOS_URL,
    birrete_src: BIRRETE_URL,
    politica_url: POLITICA_URL
  };
}

/** Manda el correo de registro (HTML + texto plano, con logos y birrete). */
function enviarCorreoRegistro(destinatario, datos) {
  var imagenes = {};
  if (datos.logos_src === 'cid:logos') imagenes.logos = imagenFija(LOGOS_B64, 'logos.png');
  if (datos.birrete_src === 'cid:birrete') imagenes.birrete = imagenFija(BIRRETE_B64, 'birrete.png');
  var texto = [
    'Hola, ' + datos.nombre + '.',
    '',
    '¡Felicitaciones! Ya puede registrar a las personas que lo acompañarán en su ceremonia de grado.',
    'Puede registrar: ' + datos.cupos + '.',
    datos.fecha_texto ? 'Ceremonia: ' + datos.fecha_texto + '.' : '',
    '',
    'Regístrelos aquí: ' + datos.enlace,
    'Cada invitado recibirá en su correo una invitación con su código QR de acceso.',
    'Este enlace es personal: no lo comparta.',
    '',
    'Ceremonia de Grado · Universidad de Santander'
  ].filter(function (l, i, a) { return l !== '' || (i > 0 && a[i - 1] !== ''); }).join('\n');
  GmailApp.sendEmail(destinatario,
    'Registre a sus invitados · Ceremonia de Grado · Universidad de Santander',
    texto, { name: REMITENTE, htmlBody: htmlRegistro(datos), inlineImages: imagenes });
}

/** Prueba: manda el correo de registro de "kevin weell" a CORREO_PRUEBA. */
function enviarPruebaRegistro() {
  var graduando = leerDocumento('graduandos', '1779858505475');
  if (!graduando) throw new Error('No existe el graduando de prueba.');
  enviarCorreoRegistro(CORREO_PRUEBA, datosDeRegistro(graduando));
  Logger.log('Correo de registro de prueba enviado a ' + CORREO_PRUEBA);
}

// ─────────────────────────── Utilidades de texto ──────────────────────────

/**
 * Escapa los caracteres con los que un navegador podría interpretar texto
 * como etiqueta HTML. Se aplica SIEMPRE a los datos que vienen de Firestore,
 * porque el nombre del invitado lo escribe el público en la página de
 * registro: sin este paso, alguien podría escribir <script>...</script> en el
 * nombre y quedar dentro del correo de otra persona.
 */
function escaparHtml(valor) {
  return String(valor == null ? '' : valor)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/**
 * Marcas que pueden venir vacías y entonces se BORRAN del correo en lugar de
 * mostrar un texto de relleno: el cargo solo existe cuando el destinatario es
 * un directivo, la línea "en nombre de…" solo cuando hay graduando, y la nota
 * del recordatorio solo en ese tipo de correo.
 */
var MARCAS_OPCIONALES = [
  'en_nombre_de', 'cargo', 'programa', 'nota_extra', 'logos_src',
  'politica_url', 'birrete_src', 'enlace_invitacion'
];

/**
 * Sustituye cada {{marca}} del HTML por su valor, SIEMPRE escapado.
 *
 * @param {string} html  plantilla con {{marcas}}
 * @param {Object} datos  { marca: 'valor' } — todo se escapa antes de insertar
 * @returns {string} correo listo para htmlBody
 */
function renderPlantilla(html, datos) {
  return String(html).replace(/\{\{([a-z_]+)\}\}/g, function (todo, marca) {
    var valor = datos[marca];
    var vacio = valor === undefined || valor === null ||
      String(valor).trim() === '';
    if (vacio) {
      // Lo opcional queda en blanco; lo obligatorio lleva texto neutro para
      // que NUNCA se vea una marca {{...}} dentro del correo.
      return MARCAS_OPCIONALES.indexOf(marca) >= 0 ? '' : POR_CONFIRMAR;
    }
    return escaparHtml(valor);
  });
}

/**
 * Quita del HTML los elementos opcionales cuyo dato venga vacío, ANTES de
 * renderizar. Un <img> con src vacío se vería como imagen rota y un <a> sin
 * href no lleva a ninguna parte: así, mientras el admin no haya publicado el
 * PNG de logos ni la URL de la política de datos, el correo sale igual pero
 * sin esos dos elementos.
 */
function prepararPlantilla(datos) {
  var html = PLANTILLA;
  if (!datos.logos_src) {
    html = html.replace(/<img[^>]*\{\{logos_src\}\}[\s\S]*?>/g, '');
  }
  if (!datos.birrete_src) {
    // Sin imagen publicada: rombo dorado en texto, que se ve en cualquier
    // cliente de correo.
    html = html.replace(/<img[^>]*\{\{birrete_src\}\}[\s\S]*?>/g,
      '<span style="font-family:Arial,sans-serif;font-size:10px;line-height:10px;color:#B8975A;">&#9670;</span>');
  }
  if (!datos.enlace_invitacion) {
    html = html.replace(/<!--ENLACE-INICIO[\s\S]*?<!--ENLACE-FIN-->/g, '');
  }
  if (!datos.politica_url) {
    html = html.replace(
      /<a[^>]*\{\{politica_url\}\}[^>]*>[\s\S]*?<\/a>/g,
      'Política de tratamiento de datos');
  }
  return html;
}

/** Meses en minúscula como los escribe la universidad: "20 de nov." */
var MESES = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
];

/** Días de la semana en minúscula: "viernes" */
var DIAS = [
  'domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'
];

/**
 * Convierte un timestamp de Firestore en la fecha impresa, por ejemplo
 * "20 de nov.". Se usa el arreglo porque no depende del idioma del JVM del
 * proyecto de Apps Script (que suele venir en inglés).
 */
function fechaImpresa(timestamp) {
  if (!timestamp || !timestamp.timestampValue) return POR_CONFIRMAR;
  var fecha = new Date(timestamp.timestampValue);
  return fecha.getDate() + ' de ' + MESES[fecha.getMonth()];
}

/** Lo mismo, pero con el día de la semana: "viernes". */
function diaImpreso(timestamp) {
  if (!timestamp || !timestamp.timestampValue) return POR_CONFIRMAR;
  return DIAS[new Date(timestamp.timestampValue).getDay()];
}

/**
 * Pasa de "07:00 PM" (así lo guarda la app) a "7:00 p. m.", que es como se
 * escribe en español.
 */
function horaImpresa(hora) {
  if (!hora || !String(hora).trim()) return POR_CONFIRMAR;
  var partes = String(hora).trim().split(/\s+/);
  var numeros = partes[0].split(':');
  var hora12 = parseInt(numeros[0], 10);
  var minutos = numeros.length > 1 ? numeros[1] : '00';
  var periodo = (partes[1] || '').toLowerCase();
  var punto = periodo.charAt(0) + '. m.';
  return hora12 + ':' + minutos + ' ' + punto;
}

// ───────────────────────────── Firestore ──────────────────────────────────

/** Cabecera de autorización: el propio proyecto de Apps Script pide el acceso. */
function cabeceras() {
  return {
    Authorization: 'Bearer ' + ScriptApp.getOAuthToken(),
    'Content-Type': 'application/json'
  };
}

/** Lee un documento completo. Devuelve null si no existe. */
function leerDocumento(coleccion, id) {
  var respuesta = UrlFetchApp.fetch(BASE + '/' + coleccion + '/' + id, {
    method: 'get',
    headers: cabeceras(),
    muteHttpExceptions: true
  });
  if (respuesta.getResponseCode() === 404) return null;
  if (respuesta.getResponseCode() !== 200) {
    throw new Error('Firestore (' + coleccion + '/' + id + '): HTTP ' +
      respuesta.getResponseCode());
  }
  return JSON.parse(respuesta.getContentText());
}

/**
 * Devuelve el valor de un campo del documento. Firestore devuelve objetos como
 * {stringValue: '...'} o {integerValue: '3'}; aquí se convierten en los
 * valores normales.
 */
function campoDocumento(doc, nombre, porDefecto) {
  if (!doc || !doc.fields || doc.fields[nombre] === undefined) return porDefecto;
  var v = doc.fields[nombre];
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return Number(v.integerValue);
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.timestampValue !== undefined) return v.timestampValue;
  if (v.nullValue !== undefined) return porDefecto;
  return porDefecto;
}

/** Mapa sencillo (por ejemplo horasPorFacultad). */
function mapaDocumento(doc, nombre) {
  if (!doc || !doc.fields || !doc.fields[nombre] ||
      !doc.fields[nombre].mapValue) return {};
  return campoDocumento(doc, nombre, {});
}

/**
 * Ejecuta una consulta estructurada contra Firestore y devuelve los
 * documentos encontrados (hasta 1000, más que suficiente para una ceremonia).
 *
 * @param {string} coleccion
 * @param {Object|null} filtro  { campo, valor } o null para listar todo
 */
function consultarQuery(coleccion, filtro) {
  var consulta = { from: [{ collectionId: coleccion }], limit: 1000 };
  if (filtro) {
    consulta.where = {
      fieldFilter: {
        field: { fieldPath: filtro.campo },
        op: 'EQUAL',
        value: typeof filtro.valor === 'number'
          ? { integerValue: String(filtro.valor) }
          : { stringValue: String(filtro.valor) }
      }
    };
  }
  var respuesta = UrlFetchApp.fetch(BASE + ':runQuery', {
    method: 'post',
    headers: cabeceras(),
    payload: JSON.stringify({ structuredQuery: consulta }),
    muteHttpExceptions: true
  });
  if (respuesta.getResponseCode() !== 200) {
    throw new Error('Firestore (' + coleccion + '): HTTP ' +
      respuesta.getResponseCode() + ' ' +
      respuesta.getContentText().slice(0, 200));
  }
  var filas = JSON.parse(respuesta.getContentText());
  var documentos = [];
  for (var i = 0; i < filas.length; i++) {
    if (filas[i].document) documentos.push(filas[i].document);
  }
  return documentos;
}

/**
 * Busca documentos de una colección donde un campo tenga un valor exacto.
 * Es la misma consulta que haría la app con .where(campo, isEqualTo: valor).
 */
function buscarPor(coleccion, nombreCampo, valor) {
  return consultarQuery(coleccion, { campo: nombreCampo, valor: valor });
}

/** Devuelve todos los documentos de una colección. */
function listarColeccion(coleccion) {
  return consultarQuery(coleccion, null);
}

/**
 * Actualiza campos de un documento. Esto solo puede hacerlo este script: las
 * reglas de Firestore le prohíben a la app avanzar el estado de una solicitud
 * de correo (mentir sobre el estado taparía un fallo de envío).
 */
function actualizarDocumento(coleccion, id, campos) {
  var claves = Object.keys(campos);
  var cuerpo = { fields: {} };
  for (var i = 0; i < claves.length; i++) {
    var v = campos[claves[i]];
    if (typeof v === 'number') {
      cuerpo.fields[claves[i]] = { integerValue: String(v) };
    } else if (v instanceof Date) {
      cuerpo.fields[claves[i]] = { timestampValue: v.toISOString() };
    } else {
      cuerpo.fields[claves[i]] = { stringValue: String(v) };
    }
  }
  var mascara = '?';
  for (var j = 0; j < claves.length; j++) {
    mascara += (j > 0 ? '&' : '') + 'updateMask.fieldPaths=' + claves[j];
  }
  var respuesta = UrlFetchApp.fetch(
    BASE + '/' + coleccion + '/' + id + mascara, {
      method: 'patch',
      headers: cabeceras(),
      payload: JSON.stringify(cuerpo),
      muteHttpExceptions: true
    });
  if (respuesta.getResponseCode() !== 200) {
    throw new Error('Firestore (actualizar ' + coleccion + '/' + id + '): HTTP ' +
      respuesta.getResponseCode());
  }
}

// ───────────────────── Datos del correo (una invitación) ──────────────────

/**
 * Arma el mapa de datos de la plantilla para UN invitado. Aquí se juntan el
 * invitado, su graduando y la configuración del evento.
 */
function datosDeInvitacion(invitado, tipoCorreo) {
  var graduando = leerDocumento('graduandos',
    campoDocumento(invitado, 'graduandoId', ''));
  var evento = leerDocumento('configuracion', 'evento');

  var graduandoNombre = [campoDocumento(graduando, 'nombres', ''),
    campoDocumento(graduando, 'apellidos', '')].join(' ').trim();

  // La hora depende de la facultad del graduando; si la configuración no
  // tiene hora para esa facultad, se usa la del graduando y, si tampoco
  // hay, "Por confirmar".
  var facultad = campoDocumento(graduando, 'facultad', '');
  var horas = mapaDocumento(evento, 'horasPorFacultad');
  var hora = horas[facultad] || campoDocumento(graduando, 'horaCeremonia', '');

  var esDirectivo = tipoCorreo === 'directivo';

  return {
    invitado: campoDocumento(invitado, 'nombreInvitado', ''),
    graduando: graduandoNombre,
    programa: campoDocumento(graduando, 'programa', ''),
    ceremonia: 'N.º ' + campoDocumento(evento, 'numeroCeremonia', ''),
    fecha: fechaImpresa(evento && evento.fields ? evento.fields.fechaCeremonia : null),
    dia_semana: diaImpreso(evento && evento.fields ? evento.fields.fechaCeremonia : null),
    hora: horaImpresa(hora),
    lugar: campoDocumento(evento, 'lugarCeremonia',
      campoDocumento(evento, 'lugar', '')),
    // El QR va como imagen en línea (cid:qr); el PNG lo genera qr.gs.
    qr_src: 'cid:qr',
    logos_src: LOGOS_URL,
    birrete_src: BIRRETE_URL,
    politica_url: POLITICA_URL,
    // Enlace a "Mi invitación" con el ID del invitado (solo invitados).
    enlace_invitacion: (!esDirectivo && invitado && invitado.name)
      ? MI_INVITACION_URL + '?id=' + invitado.name.split('/').pop()
      : '',
    motivo: esDirectivo
      ? 'Recibe este mensaje como invitado especial de la Universidad de Santander.'
      : 'Recibe este mensaje porque ' + (graduandoNombre || 'un graduando') +
        ' lo registró como invitado.',
    titulo_beneficiario: esDirectivo ? 'Invitación especial para' : 'Invitación personal para',
    // En las invitaciones a directivos no se dice "en nombre de": el cargo
    // del directivo va debajo de su nombre.
    en_nombre_de: esDirectivo ? '' : (graduandoNombre ? 'en nombre de ' + graduandoNombre : ''),
    cargo: esDirectivo ? campoDocumento(invitado, 'cargo', '') : '',
    // Línea extra arriba del QR; solo el recordatorio la usa.
    nota_extra: tipoCorreo === 'recordatorio'
      ? 'Le recordamos que la ceremonia es el ' +
        fechaImpresa(evento && evento.fields ? evento.fields.fechaCeremonia : null) + '.'
      : '',
    // Lo que se imprime dentro del QR: nunca el nombre ni el documento.
    codigoAcceso: campoDocumento(invitado, 'codigoQr', '')
  };
}

/**
 * Versión en texto plano del mismo correo. Es obligatoria: hay clientes que no
 * muestran HTML (algunos lectores corporativos, algunas aplicaciones de
 * reenvío) y además sube la probabilidad de que el correo llegue a la bandeja
 * principal y no a la de correo no deseado.
 */
function textoPlano(datos) {
  var lineas = [
    'INVITACIÓN · CEREMONIA DE GRADUACIÓN',
    'Universidad de Santander',
    '',
    datos.titulo_beneficiario + ': ' + datos.invitado,
    datos.en_nombre_de,
    datos.cargo,
    datos.programa,
    '',
    'CEREMONIA: ' + datos.ceremonia,
    'FECHA: ' + datos.fecha + ' (' + datos.dia_semana + ')',
    'HORA: ' + datos.hora,
    'LUGAR: ' + datos.lugar,
    '',
    datos.nota_extra,
    '',
    'Su código de acceso es: ' + datos.codigoAcceso,
    'Presente este código al ingresar, impreso o desde su celular.',
    'Es personal y válido para una sola entrada.',
    datos.enlace_invitacion ? 'Vea su invitación en línea: ' + datos.enlace_invitacion : '',
    '',
    'Sus datos se tratan según la Ley 1581 de 2012 y se eliminan al terminar' +
      ' el evento.' + (POLITICA_URL ? ' ' + POLITICA_URL : '')
  ];
  // Las líneas vacías de los campos no usados se quitan para que el texto
  // plano se lea limpio.
  return lineas.filter(function (linea, i, lista) {
    return linea !== '' || (i > 0 && lista[i - 1] !== '');
  }).join('\n');
}

// ───────────────────────────── Envío ──────────────────────────────────────

/**
 * Manda UNA invitación por correo. El QR viaja como imagen en línea
 * (inlineImages + cid:qr) y no como data:base64, porque Gmail bloquea las
 * imágenes en línea construidas con data:. Tampoco se pide el QR a un
 * servicio externo: lo genera el propio script (qr.gs).
 */
function enviarInvitacion(destinatario, datos) {
  var html = renderPlantilla(prepararPlantilla(datos), datos);
  var asunto = 'Invitación · Ceremonia de Grado ' +
    datos.ceremonia + ' – Universidad de Santander';
  // Imágenes que van pegadas al correo: el QR siempre, y los logos y el
  // birrete solo si la plantilla los pide con cid:.
  var imagenes = { qr: generarQrPng(datos.codigoAcceso) };
  if (datos.logos_src === 'cid:logos') {
    imagenes.logos = imagenFija(LOGOS_B64, 'logos.png');
  }
  if (datos.birrete_src === 'cid:birrete') {
    imagenes.birrete = imagenFija(BIRRETE_B64, 'birrete.png');
  }
  var opciones = {
    htmlBody: html,
    name: REMITENTE,
    inlineImages: imagenes
  };
  GmailApp.sendEmail(destinatario, asunto, textoPlano(datos), opciones);
}

/**
 * Correo de campaña o de bienvenida: no lleva la tarjeta de invitación porque
 * no es una invitación individual, solo el mensaje que escribió el admin.
 */
function enviarCampana(destinatario, solicitud) {
  GmailApp.sendEmail(destinatario, campoDocumento(solicitud, 'titulo', ''), '', {
    htmlBody:
      '<div style="font-family:Georgia,serif;font-size:15px;line-height:22px;color:#3B4252;">' +
      escaparHtml(campoDocumento(solicitud, 'mensaje', '')).replace(/\n/g, '<br>') +
      '</div>',
    name: REMITENTE
  });
}

// ───────────────────── Flujo 1: solicitudes de la app ─────────────────────

/** Destinatarios de una solicitud, según lo que pidió la app. */
function destinatariosDe(solicitud) {
  var tipoDestinatarios = campoDocumento(solicitud, 'destinatarios', 'todos');

  // Envío individual: la app ya trae el correo y el invitado exacto.
  if (tipoDestinatarios === 'individual') {
    var invitado = leerDocumento('invitados',
      campoDocumento(solicitud, 'invitadoId', ''));
    if (!invitado) return [];
    return [{
      id: campoDocumento(invitado, 'id', ''),
      nombre: campoDocumento(invitado, 'nombreInvitado', ''),
      correo: campoDocumento(solicitud, 'correoOpcional',
        campoDocumento(invitado, 'correoInvitado', '')),
      graduandoId: campoDocumento(invitado, 'graduandoId', ''),
      codigoQr: campoDocumento(invitado, 'codigoQr', ''),
      documento: invitado
    }];
  }

  // Envío masivo. Los valores coinciden con las etiquetas del desplegable de
  // Notificaciones: "todos", "confirmados", "pendientes". Ojo con dos detalles
  // del dato que guarda Firestore:
  //   · el estado de un invitado confirmado se escribe 'confirmada' (con a);
  //   · "todos" son los que siguen vigentes: ni 'anulada' (le quitaron el
  //     cupo) ni 'rechazada' (ya avisó que no asiste).
  var invitados;
  if (tipoDestinatarios === 'todos') {
    invitados = listarColeccion('invitados').filter(function (inv) {
      var estado = campoDocumento(inv, 'estado', '');
      return estado !== 'anulada' && estado !== 'rechazada';
    });
  } else if (tipoDestinatarios === 'confirmados') {
    invitados = buscarPor('invitados', 'estado', 'confirmada');
  } else {
    invitados = buscarPor('invitados', 'estado', 'pendiente');
  }
  var lista = [];
  for (var i = 0; i < invitados.length; i++) {
    var inv = invitados[i];
    var correo = campoDocumento(inv, 'correoInvitado', '');
    if (!correo) continue;
    lista.push({
      id: campoDocumento(inv, 'id', ''),
      nombre: campoDocumento(inv, 'nombreInvitado', ''),
      correo: correo,
      graduandoId: campoDocumento(inv, 'graduandoId', ''),
      codigoQr: campoDocumento(inv, 'codigoQr', ''),
      documento: inv
    });
  }
  return lista;
}

/**
 * Procesa TODAS las solicitudes pendientes de la app. Se marca cada una como
 * 'en_proceso' ANTES de enviar para que dos disparos seguidos no manden el
 * mismo correo dos veces.
 */
function enviarSolicitudesPendientes() {
  var pendientes = buscarPor('solicitudes_correo', 'estado', 'pendiente');
  Logger.log('Solicitudes pendientes: ' + pendientes.length);

  for (var i = 0; i < pendientes.length; i++) {
    var solicitud = pendientes[i];
    var id = solicitud.name.split('/').pop();
    var tipo = campoDocumento(solicitud, 'tipo', 'campana');

    try {
      actualizarDocumento('solicitudes_correo', id, { estado: 'en_proceso' });

      var destinatarios = destinatariosDe(solicitud);
      var enviados = 0;

      for (var j = 0; j < destinatarios.length; j++) {
        var destino = destinatarios[j];
        try {
          if (tipo === 'campana') {
            enviarCampana(destino.correo, solicitud);
          } else {
            // 'invitacion' y 'recordatorio' usan la misma tarjeta; el
            // recordatorio agrega la línea de la fecha arriba del QR.
            var datos = datosDeInvitacion(destino.documento,
              tipo === 'recordatorio' ? 'recordatorio' : 'invitacion');
            if (!datos.codigoAcceso) {
              // Un invitado sin código no puede entrar: mejor no mandar un
              // correo sin QR y avisar en el estado.
              Logger.log('Invitado sin código, se omite: ' + destino.id);
              continue;
            }
            enviarInvitacion(destino.correo, datos);
          }
          enviados++;
        } catch (errorEnvio) {
          // Un destinatario mal escrito no debe frenar a los demás: se sigue
          // con el siguiente y al final se guarda lo que sí se pudo mandar.
          Logger.log('Fallo al enviar a ' + destino.correo + ': ' + errorEnvio);
        }
      }

      var estado = enviados === destinatarios.length && destinatarios.length > 0
        ? 'terminada'
        : (enviados > 0 ? 'en_proceso' : 'error');
      actualizarDocumento('solicitudes_correo', id, {
        estado: estado,
        enviados: enviados
      });
    } catch (error) {
      Logger.log('Fallo la solicitud ' + id + ': ' + error);
      try {
        actualizarDocumento('solicitudes_correo', id, { estado: 'error' });
      } catch (ignorada) {
        // Nada más que hacer: el intento queda registrado en el registro de
        // ejecuciones de Apps Script.
      }
    }
  }
}

// ─────────────────── Flujo 2: enlaces de registro ─────────────────────────

/**
 * Manda el enlace de registro a los graduandos que todavía no lo tienen. La
 * app no manda este correo: solo pone `correoRegistro` en 'pendiente' (también
 * para pedir un reenvío) y aquí se procesa.
 */
function enviarEnlacesRegistro() {
  var pendientes = buscarPor('graduandos', 'correoRegistro', 'pendiente');
  Logger.log('Graduandos esperando enlace de registro: ' + pendientes.length);

  for (var i = 0; i < pendientes.length; i++) {
    var graduando = pendientes[i];
    var id = graduando.name.split('/').pop();
    var correo = campoDocumento(graduando, 'correo', '');
    var nombre = [campoDocumento(graduando, 'nombres', ''),
      campoDocumento(graduando, 'apellidos', '')].join(' ').trim();

    if (!correo) {
      actualizrEstadoRegistro(id, 'error');
      continue;
    }

    try {
      // Correo con el diseño de la invitación y el enlace CON el ID del
      // graduando (antes iba sin ?id= y la página decía "Enlace inválido").
      enviarCorreoRegistro(correo, datosDeRegistro(graduando));
      actualizrEstadoRegistro(id, 'enviado');
    } catch (error) {
      Logger.log('Fallo el enlace de registro de ' + id + ': ' + error);
      actualizrEstadoRegistro(id, 'error');
    }
  }
}

/** Marca el estado del correo de registro de un graduando. */
function actualizrEstadoRegistro(graduandoId, estado) {
  // Se usa PATCH con máscara para no pisar los demás campos del graduando.
  actualizarDocumento('graduandos', graduandoId, { correoRegistro: estado });
}

// ──────────── Flujo 3: invitados registrados desde la página web ──────────

// Mismas 32 letras y números que usa la app para los códigos: no tiene 0, O,
// 1 ni I para que no se confundan al leerlos.
var ALFABETO_CODIGO = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/**
 * Crea un código con el MISMO formato que la app:
 * INV-XXXXXX-XXXXXX-XXXXXX-XXXXXX-XX (26 caracteres al azar en grupos de 6).
 * El azar sale de dos UUID (Utilities.getUuid usa un generador seguro) pasados
 * por SHA-256. Cada byte va de 0 a 255 y 256 es múltiplo de 32, así que
 * `byte % 32` reparte las 32 letras por igual.
 */
function generarCodigoAcceso(prefijo) {
  var bytes = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256,
    Utilities.getUuid() + Utilities.getUuid());
  var codigo = prefijo + '-';
  for (var i = 0; i < 26; i++) {
    if (i > 0 && i % 6 === 0) codigo += '-';
    codigo += ALFABETO_CODIGO.charAt((bytes[i] + 256) % 32);
  }
  return codigo;
}

/** Código que todavía no tenga ningún otro invitado. */
function codigoInvitadoLibre() {
  for (var intento = 0; intento < 5; intento++) {
    var codigo = generarCodigoAcceso('INV');
    if (buscarPor('invitados', 'codigoQr', codigo).length === 0) return codigo;
  }
  throw new Error('No se pudo generar un código único');
}

/**
 * La página invitados.html guarda al invitado con estado 'pendiente' y SIN
 * código: las reglas de Firestore no dejan que una página pública escriba su
 * propio código de acceso. Este script sí puede, así que aquí se le asigna el
 * código, se manda la invitación con el QR y se marca como 'enviado'.
 *
 * `correoAuto` marca a los invitados que este flujo está atendiendo: si el
 * código se guardó pero el correo falló, en la siguiente vuelta se reintenta
 * con el mismo código. Los invitados que la app ya trae con código no se
 * tocan (esos los envía el administrador).
 */
function enviarInvitacionesNuevas() {
  var pendientes = buscarPor('invitados', 'estado', 'pendiente');
  var nuevos = pendientes.filter(function (inv) {
    return !campoDocumento(inv, 'codigoQr', '') ||
      campoDocumento(inv, 'correoAuto', '') === 'pendiente';
  });
  Logger.log('Invitados registrados en la web por atender: ' + nuevos.length);

  for (var i = 0; i < nuevos.length; i++) {
    var inv = nuevos[i];
    var id = inv.name.split('/').pop();
    var correo = campoDocumento(inv, 'correoInvitado', '');
    if (!correo) continue;
    try {
      var codigo = campoDocumento(inv, 'codigoQr', '');
      if (!codigo) {
        codigo = codigoInvitadoLibre();
        // Primero se guarda el código; así, si el correo falla, el invitado
        // no se queda sin código ni recibe uno distinto en el reintento.
        actualizarDocumento('invitados', id,
          { codigoQr: codigo, correoAuto: 'pendiente' });
        inv.fields.codigoQr = { stringValue: codigo };
      }
      enviarInvitacion(correo, datosDeInvitacion(inv, 'invitacion'));
      actualizarDocumento('invitados', id,
        { estado: 'enviado', correoAuto: 'enviado', fechaEnvio: new Date() });
    } catch (error) {
      Logger.log('Fallo con el invitado ' + id + ': ' + error);
    }
  }
}

// ─────────────────────── Punto de entrada y menú ──────────────────────────

/**
 * Se ejecuta cada 5 minutos: en Ajustes del proyecto → Despachadores
 * automáticos → agregar despachador → ejecutar enviarCorreos.
 */
function enviarCorreos() {
  enviarSolicitudesPendientes();
  enviarEnlacesRegistro();
  // Para que los invitados registrados en la web reciban su invitación sola,
  // quita las dos barras de la línea siguiente y guarda.
  // enviarInvitacionesNuevas();
}

/** Añade el menú "Apolo UDES" dentro del editor de Apps Script. */
function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('Apolo UDES')
    .addItem('Enviar prueba de invitación', 'enviarPruebaInvitacion')
    .addItem('Probar renderizador', 'probarRenderizador')
    .addToUi();
}

/**
 * Prueba manual: manda una invitación de ejemplo, con datos ficticios (no se
 * usan nombres ni documentos reales). Sirve para ver cómo se ve el correo en
 * Gmail web, en el celular y en Outlook antes de mandarlo a los invitados de
 * verdad.
 *
 * El correo sale del diálogo si el proyecto está enlazado a una hoja de
 * cálculo; en un proyecto suelto se toma de la constante CORREO_PRUEBA.
 */
function enviarPruebaInvitacion() {
  var correo = CORREO_PRUEBA;
  try {
    var ui = SpreadsheetApp.getUi();
    var respuesta = ui.prompt(
      'Enviar prueba de invitación',
      'Escribe el correo donde quieres recibir la invitación de ejemplo:',
      ui.ButtonSet.OK_CANCEL);
    if (respuesta.getSelectedButton() !== ui.Button.OK) return;
    correo = respuesta.getResponseText().trim();
  } catch (sinInterfaz) {
    // Proyecto suelto (sin hoja de cálculo): se usa la constante.
  }
  if (!correo || correo === 'tucorreo@gmail.com') {
    throw new Error('Pon tu correo en la constante CORREO_PRUEBA y vuelve a ' +
      'ejecutar enviarPruebaInvitacion.');
  }

  var datos = {
    invitado: 'Invitado de Prueba',
    graduando: 'Graduando de Prueba',
    programa: 'Ingeniería de Software',
    ceremonia: 'N.º 1',
    fecha: '20 de nov.',
    dia_semana: 'viernes',
    hora: '7:00 p. m.',
    lugar: 'Auditorio Mayor · Campus Lagos del Cacique',
    qr_src: 'cid:qr',
    logos_src: LOGOS_URL,
    birrete_src: BIRRETE_URL,
    politica_url: POLITICA_URL,
    motivo: 'Recibe este mensaje porque Graduando de Prueba lo registró como invitado.',
    titulo_beneficiario: 'Invitación personal para',
    en_nombre_de: 'en nombre de Graduando de Prueba',
    cargo: '',
    nota_extra: '',
    codigoAcceso: 'INV-PRUEBA-000000-000000'
  };

  enviarInvitacion(correo, datos);
  Logger.log('Invitación de prueba enviada a ' + correo +
    '. Revisa Gmail web, el celular y Outlook.');
}

// ───────────────────────────── Pruebas ────────────────────────────────────

/**
 * Prueba automática del renderizador (menú → "Probar renderizador"). Comprueba
 * tres cosas: que reemplace todas las marcas, que escape un <script> y que no
 * quede ninguna {{...}} en el resultado.
 */
function probarRenderizador() {
  var datos = {
    invitado: '<script>alert(1)</script>Invitado',
    graduando: 'Graduando de Prueba',
    programa: 'Programa',
    ceremonia: 'N.º 1',
    fecha: '20 de nov.',
    dia_semana: 'viernes',
    hora: '7:00 p. m.',
    lugar: 'Auditorio',
    qr_src: 'cid:qr',
    logos_src: '',
    birrete_src: '',
    politica_url: '',
    motivo: 'Recibe este mensaje porque Graduando de Prueba lo registró como invitado.',
    titulo_beneficiario: 'Invitación personal para',
    en_nombre_de: 'en nombre de Graduando de Prueba',
    cargo: '',
    nota_extra: ''
  };
  var html = renderPlantilla(prepararPlantilla(datos), datos);

  var fallos = [];
  if (html.indexOf('<script>') !== -1) fallos.push('no escapó el <script>');
  if (html.indexOf('{{') !== -1) fallos.push('quedó una marca sin reemplazar');
  if (html.indexOf('cid:qr') === -1) fallos.push('no colocó el QR');
  // Con todos los datos cargados no debería verse el texto de relleno.
  if (html.indexOf(POR_CONFIRMAR) !== -1) {
    fallos.push('apareció el texto de relleno');
  }

  if (fallos.length === 0) {
    Logger.log('Renderizador OK');
  } else {
    throw new Error('Renderizador: ' + fallos.join(', '));
  }
}