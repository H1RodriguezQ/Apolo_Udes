import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import '../../../core/constants/app_constants.dart';
import '../models/models.dart';

class EmailService {
  // ── Envía invitación con QR y botones de confirmación ──
  static Future<bool> enviarInvitacion({
    required Graduando graduando,
    required String nombreInvitado,
    required String correoInvitado,
    required String codigoQr,
    required String qrBase64,
    required String fechaCeremonia,
    String qrUrl = '',
    String invitadoId = '',
  }) async {
    if (kIsWeb) {
      debugPrint('ERROR EMAIL: SMTP no disponible en web');
      return false;
    }

    try {
      debugPrint('Enviando correo a: $correoInvitado');
      final smtpServer = gmail(
        AppConstants.emailRemitente,
        AppConstants.emailPassword,
      );

      final qrSrc = qrUrl.isNotEmpty
          ? qrUrl
          : 'data:image/png;base64,$qrBase64';

      final message = Message()
        ..from = Address(AppConstants.emailRemitente, AppConstants.emailNombre)
        ..recipients.add(correoInvitado)
        ..subject =
            'Invitación - Ceremonia de Grado UDES | ${graduando.nombreCompleto}'
        ..html = _buildEmailHtml(
          graduando: graduando,
          nombreInvitado: nombreInvitado,
          codigoQr: codigoQr,
          qrSrc: qrSrc,
          fechaCeremonia: fechaCeremonia,
          invitadoId: invitadoId,
        );

      final sendReport = await send(message, smtpServer);
      debugPrint('Correo enviado: ${sendReport.toString()}');
      return true;
    } on MailerException catch (e) {
      debugPrint('ERROR MAILER: ${e.message}');
      for (final p in e.problems) {
        debugPrint('  Problema: ${p.code} - ${p.msg}');
      }
      return false;
    } catch (e) {
      debugPrint('ERROR EMAIL: $e');
      return false;
    }
  }

  // ── Envía recordatorio a invitado ──
  static Future<bool> enviarRecordatorio({
    required String nombreInvitado,
    required String correoInvitado,
    required String codigoQr,
    required String fechaCeremonia,
    required String horaCeremonia,
    required String graduandoNombre,
    String qrUrl = '',
    String qrBase64 = '',
  }) async {
    if (kIsWeb) return false;

    try {
      final smtpServer = gmail(
        AppConstants.emailRemitente,
        AppConstants.emailPassword,
      );

      final qrSrc = qrUrl.isNotEmpty
          ? qrUrl
          : qrBase64.isNotEmpty
              ? 'data:image/png;base64,$qrBase64'
              : '';

      final message = Message()
        ..from = Address(AppConstants.emailRemitente, AppConstants.emailNombre)
        ..recipients.add(correoInvitado)
        ..subject = '🔔 Recordatorio - Ceremonia de Grado UDES'
        ..html = _buildRecordatorioHtml(
          nombreInvitado: nombreInvitado,
          codigoQr: codigoQr,
          fechaCeremonia: fechaCeremonia,
          horaCeremonia: horaCeremonia,
          graduandoNombre: graduandoNombre,
          qrSrc: qrSrc,
        );

      await send(message, smtpServer);
      debugPrint('Recordatorio enviado a: $correoInvitado');
      return true;
    } catch (e) {
      debugPrint('ERROR recordatorio: $e');
      return false;
    }
  }

  // ── Envía correo al graduando para registrar invitados ──
  static Future<bool> enviarCorreoRegistroInvitados({
    required Graduando graduando,
    String fechaCeremonia = '',
  }) async {
    if (kIsWeb) return false;

    try {
      final smtpServer = gmail(
        AppConstants.emailRemitente,
        AppConstants.emailPassword,
      );

      final urlRegistro =
          'https://apolo-udes.web.app/invitados.html?id=${graduando.id}';

      final message = Message()
        ..from = Address(AppConstants.emailRemitente, AppConstants.emailNombre)
        ..recipients.add(graduando.correo)
        ..subject =
            '¡Felicitaciones! Registra tus invitados - Ceremonia de Grado UDES'
        ..html = _buildCorreoGraduando(
          graduando: graduando,
          urlRegistro: urlRegistro,
          fechaCeremonia: fechaCeremonia,
        );

      await send(message, smtpServer);
      debugPrint('Correo graduando enviado a ${graduando.correo}');
      return true;
    } catch (e) {
      debugPrint('ERROR correo graduando: $e');
      return false;
    }
  }

  // ── Plantilla HTML recordatorio ──
  static String _buildRecordatorioHtml({
    required String nombreInvitado,
    required String codigoQr,
    required String fechaCeremonia,
    required String horaCeremonia,
    required String graduandoNombre,
    String qrSrc = '',
  }) {
    final qrHtml = qrSrc.isNotEmpty
        ? '''
        <div style="text-align:center;margin-bottom:28px;">
          <p style="margin:0 0 16px;color:#2d3748;font-size:14px;font-weight:600;">
            Tu código QR de acceso
          </p>
          <div style="display:inline-block;padding:16px;background:#ffffff;border:2px solid #1A3A6B;border-radius:12px;">
            <img src="$qrSrc" width="180" height="180" alt="Código QR de acceso" style="display:block;" />
          </div>
          <p style="margin:12px 0 0;color:#718096;font-size:12px;">Código: <strong style="color:#0F2347;">$codigoQr</strong></p>
        </div>'''
        : '<p style="text-align:center;color:#718096;font-size:13px;">Código: <strong style="color:#0F2347;">$codigoQr</strong></p>';

    return '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Recordatorio - Ceremonia de Grado UDES</title>
</head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.10);">

          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#0F2347 0%,#1A3A6B 60%,#1E4D8C 100%);padding:40px 40px 30px;text-align:center;">
              <p style="margin:0 0 8px;color:#B8CCE8;font-size:12px;letter-spacing:2px;text-transform:uppercase;">Universidad de Santander</p>
              <h1 style="margin:0;color:#ffffff;font-size:32px;font-weight:800;">Apolo UDES</h1>
              <p style="margin:8px 0 0;color:#B8CCE8;font-size:14px;">Sistema de Gestión de Ceremonia de Grado</p>
            </td>
          </tr>

          <!-- Banner dorado -->
          <tr>
            <td style="background:linear-gradient(90deg,#C9A84C,#F0D060,#C9A84C);padding:12px;text-align:center;">
              <p style="margin:0;color:#3D2B00;font-size:13px;font-weight:700;letter-spacing:2px;text-transform:uppercase;">🔔 Recordatorio de Ceremonia</p>
            </td>
          </tr>

          <!-- Cuerpo -->
          <tr>
            <td style="padding:40px;">
              <p style="margin:0 0 20px;color:#1A3A6B;font-size:18px;font-weight:600;">
                Estimado/a <strong>$nombreInvitado</strong>,
              </p>

              <div style="background:#f8f9fb;border-left:4px solid #C9A84C;border-radius:0 8px 8px 0;padding:20px 24px;margin-bottom:28px;">
                <p style="margin:0;color:#2d3748;font-size:15px;line-height:1.7;">
                  Le recordamos que está invitado/a a la <strong>Ceremonia de Graduación</strong>
                  de la <strong>Universidad de Santander – UDES</strong>.
                  ${graduandoNombre.isNotEmpty ? 'Como invitado de <strong>$graduandoNombre</strong>.' : ''}
                </p>
              </div>

              <!-- Datos evento -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px;">
                <tr>
                  <td width="48%" style="text-align:center;padding:20px;background:#f8f9fb;border-radius:8px;">
                    <p style="margin:0 0 4px;color:#718096;font-size:11px;text-transform:uppercase;">📅 Fecha</p>
                    <p style="margin:0;color:#0F2347;font-size:14px;font-weight:700;">$fechaCeremonia</p>
                  </td>
                  <td width="4%"></td>
                  <td width="48%" style="text-align:center;padding:20px;background:#f8f9fb;border-radius:8px;">
                    <p style="margin:0 0 4px;color:#718096;font-size:11px;text-transform:uppercase;">🕐 Hora</p>
                    <p style="margin:0;color:#0F2347;font-size:14px;font-weight:700;">$horaCeremonia</p>
                  </td>
                </tr>
              </table>

              <!-- Lugar -->
              <div style="text-align:center;margin-bottom:28px;padding:16px;border:1px solid #e2e8f0;border-radius:8px;">
                <p style="margin:0 0 4px;color:#718096;font-size:11px;text-transform:uppercase;">📍 Lugar</p>
                <p style="margin:0;color:#0F2347;font-size:15px;font-weight:700;">${AppConstants.eventoLugar}</p>
                <p style="margin:4px 0 0;color:#718096;font-size:13px;">${AppConstants.eventoDireccion}</p>
              </div>

              $qrHtml

              <div style="background:#FFF8E1;border:1px solid #F0D060;border-radius:8px;padding:16px;">
                <p style="margin:0;color:#7B5800;font-size:13px;text-align:center;">
                  ⚠️ Recuerde presentar su código QR el día del evento. Esta invitación es personal e intransferible.
                </p>
              </div>

            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#0F2347;padding:28px 40px;text-align:center;">
              <p style="margin:0 0 8px;color:#B8CCE8;font-size:13px;font-weight:600;">Universidad de Santander – UDES</p>
              <p style="margin:0 0 4px;color:#4A6785;font-size:12px;">${AppConstants.eventoDireccion}</p>
              <p style="margin:0;color:#4A6785;font-size:12px;">${AppConstants.eventoCiudad}</p>
              <div style="margin-top:16px;padding-top:16px;border-top:1px solid #1E3A5F;">
                <p style="margin:0;color:#4A6785;font-size:11px;">Acreditada Alta Calidad por el Ministerio de Educación Nacional | SNIES 2832</p>
              </div>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  // ── Plantilla HTML invitación ──
  static String _buildEmailHtml({
    required Graduando graduando,
    required String nombreInvitado,
    required String codigoQr,
    required String qrSrc,
    required String fechaCeremonia,
    String invitadoId = '',
  }) {
    final botonesConfirmacion = invitadoId.isNotEmpty
        ? '''
        <div style="text-align:center;margin-bottom:28px;">
          <p style="margin:0 0 16px;color:#2d3748;font-size:15px;font-weight:600;">¿Confirmas tu asistencia?</p>
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr>
              <td width="50%" style="padding-right:8px;">
                <a href="https://apolo-udes.web.app/confirmar.html?id=$invitadoId&r=si"
                   style="display:block;padding:16px 8px;background:linear-gradient(135deg,#276749,#38A169);color:#ffffff;border-radius:10px;text-decoration:none;font-size:15px;font-weight:700;text-align:center;">
                  ✅ Sí, asistiré
                </a>
              </td>
              <td width="50%" style="padding-left:8px;">
                <a href="https://apolo-udes.web.app/confirmar.html?id=$invitadoId&r=no"
                   style="display:block;padding:16px 8px;background:#ffffff;color:#e53e3e;border:2px solid #e53e3e;border-radius:10px;text-decoration:none;font-size:15px;font-weight:700;text-align:center;">
                  ❌ No podré asistir
                </a>
              </td>
            </tr>
          </table>
        </div>'''
        : '';

    return '''
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Invitación Ceremonia de Grado UDES</title>
</head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.10);">
          <tr>
            <td style="background:linear-gradient(135deg,#0F2347 0%,#1A3A6B 60%,#1E4D8C 100%);padding:40px 40px 30px;text-align:center;">
              <p style="margin:0 0 8px;color:#B8CCE8;font-size:12px;letter-spacing:2px;text-transform:uppercase;">Universidad de Santander</p>
              <h1 style="margin:0;color:#ffffff;font-size:32px;font-weight:800;letter-spacing:-0.5px;">Apolo UDES</h1>
              <p style="margin:8px 0 0;color:#B8CCE8;font-size:14px;">Sistema de Gestión de Ceremonia de Grado</p>
            </td>
          </tr>
          <tr>
            <td style="background:linear-gradient(90deg,#C9A84C,#F0D060,#C9A84C);padding:12px;text-align:center;">
              <p style="margin:0;color:#3D2B00;font-size:13px;font-weight:700;letter-spacing:2px;text-transform:uppercase;">✦ Invitación a: Ceremonia de Graduación ✦</p>
            </td>
          </tr>
          <tr>
            <td style="padding:40px;">
              <p style="margin:0 0 20px;color:#1A3A6B;font-size:18px;font-weight:600;">
                Estimado/a <strong>$nombreInvitado</strong>,
              </p>
              <div style="background:#f8f9fb;border-left:4px solid #1A3A6B;border-radius:0 8px 8px 0;padding:20px 24px;margin-bottom:28px;">
                <p style="margin:0;color:#2d3748;font-size:15px;line-height:1.7;">
                  El Rector General y el Consejo Académico de la
                  <strong>Universidad de Santander – UDES</strong>
                  tienen el gusto de invitarle al acto académico por medio del
                  cual se otorga el título de tecnólogos y profesionales.
                </p>
              </div>
              <div style="text-align:center;margin-bottom:28px;">
                <p style="margin:0 0 4px;color:#718096;font-size:13px;text-transform:uppercase;letter-spacing:1px;">Graduando</p>
                <h2 style="margin:0;color:#0F2347;font-size:26px;font-weight:800;">${graduando.nombreCompleto}</h2>
                <p style="margin:6px 0 0;color:#1A3A6B;font-size:15px;font-weight:500;">${graduando.programa}</p>
                <p style="margin:4px 0 0;color:#718096;font-size:13px;">${graduando.facultad}</p>
              </div>
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px;">
                <tr>
                  <td width="33%" style="text-align:center;padding:16px;background:#f8f9fb;border-radius:8px;">
                    <p style="margin:0 0 4px;color:#718096;font-size:11px;text-transform:uppercase;">Fecha</p>
                    <p style="margin:0;color:#0F2347;font-size:14px;font-weight:700;">$fechaCeremonia</p>
                  </td>
                  <td width="4%"></td>
                  <td width="29%" style="text-align:center;padding:16px;background:#f8f9fb;border-radius:8px;">
                    <p style="margin:0 0 4px;color:#718096;font-size:11px;text-transform:uppercase;">Hora</p>
                    <p style="margin:0;color:#0F2347;font-size:14px;font-weight:700;">${graduando.horaCeremonia}</p>
                  </td>
                  <td width="4%"></td>
                  <td width="30%" style="text-align:center;padding:16px;background:#f8f9fb;border-radius:8px;">
                    <p style="margin:0 0 4px;color:#718096;font-size:11px;text-transform:uppercase;">Válido para</p>
                    <p style="margin:0;color:#0F2347;font-size:14px;font-weight:700;">1 persona</p>
                  </td>
                </tr>
              </table>
              <div style="text-align:center;margin-bottom:28px;padding:16px;border:1px solid #e2e8f0;border-radius:8px;">
                <p style="margin:0 0 4px;color:#718096;font-size:11px;text-transform:uppercase;">Lugar</p>
                <p style="margin:0;color:#0F2347;font-size:15px;font-weight:700;">${AppConstants.eventoLugar}</p>
                <p style="margin:4px 0 0;color:#718096;font-size:13px;">${AppConstants.eventoDireccion}</p>
              </div>
              <div style="text-align:center;margin-bottom:28px;">
                <p style="margin:0 0 16px;color:#2d3748;font-size:14px;font-weight:600;">
                  Presenta este código QR el día del evento para ingresar
                </p>
                <div style="display:inline-block;padding:16px;background:#ffffff;border:2px solid #1A3A6B;border-radius:12px;">
                  <img src="$qrSrc" width="180" height="180" alt="Código QR de acceso" style="display:block;" />
                </div>
                <p style="margin:12px 0 0;color:#718096;font-size:12px;">Código: <strong style="color:#0F2347;">$codigoQr</strong></p>
              </div>
              $botonesConfirmacion
              <div style="background:#FFF8E1;border:1px solid #F0D060;border-radius:8px;padding:16px;">
                <p style="margin:0;color:#7B5800;font-size:13px;text-align:center;">
                  ⚠️ Esta invitación es personal e intransferible. Solo permite el ingreso de <strong>1 persona</strong>.
                </p>
              </div>
            </td>
          </tr>
          <tr>
            <td style="background:#0F2347;padding:28px 40px;text-align:center;">
              <p style="margin:0 0 8px;color:#B8CCE8;font-size:13px;font-weight:600;">Universidad de Santander – UDES</p>
              <p style="margin:0 0 4px;color:#4A6785;font-size:12px;">${AppConstants.eventoDireccion}</p>
              <p style="margin:0;color:#4A6785;font-size:12px;">${AppConstants.eventoCiudad}</p>
              <div style="margin-top:16px;padding-top:16px;border-top:1px solid #1E3A5F;">
                <p style="margin:0;color:#4A6785;font-size:11px;">Acreditada Alta Calidad por el Ministerio de Educación Nacional | SNIES 2832</p>
              </div>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  // ── Plantilla HTML correo al graduando ──
  static String _buildCorreoGraduando({
    required Graduando graduando,
    required String urlRegistro,
    String fechaCeremonia = '',
  }) {
    final fechaHtml = fechaCeremonia.isNotEmpty
        ? '<p style="margin:8px 0 0;color:#0F2347;font-size:15px;font-weight:600;">📅 $fechaCeremonia</p>'
        : '';

    return '''
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.10);">
          <tr>
            <td style="background:linear-gradient(135deg,#0F2347 0%,#1A3A6B 60%,#1E4D8C 100%);padding:40px;text-align:center;">
              <h1 style="margin:0;color:#ffffff;font-size:28px;font-weight:800;">¡Felicitaciones!</h1>
              <p style="margin:8px 0 0;color:#B8CCE8;font-size:14px;">Universidad de Santander – UDES</p>
            </td>
          </tr>
          <tr>
            <td style="background:linear-gradient(90deg,#C9A84C,#F0D060,#C9A84C);padding:10px;text-align:center;">
              <p style="margin:0;color:#3D2B00;font-size:12px;font-weight:700;letter-spacing:2px;">✦ CEREMONIA DE GRADUACIÓN ✦</p>
            </td>
          </tr>
          <tr>
            <td style="padding:40px;">
              <p style="color:#0F2347;font-size:18px;font-weight:600;">Estimado/a <strong>${graduando.nombreCompleto}</strong>,</p>
              <p style="color:#2d3748;font-size:15px;line-height:1.7;">
                Nos complace informarte que has sido registrado/a para la <strong>Ceremonia de Graduación</strong>
                de la Universidad de Santander – UDES.
              </p>
              <div style="background:#f8f9fb;border-radius:12px;padding:20px;margin:24px 0;text-align:center;">
                <p style="margin:0 0 4px;color:#718096;font-size:12px;text-transform:uppercase;">Programa</p>
                <p style="margin:0;color:#0F2347;font-size:16px;font-weight:700;">${graduando.programa}</p>
                <p style="margin:4px 0 0;color:#718096;font-size:13px;">${graduando.facultad}</p>
                $fechaHtml
                <p style="margin:8px 0 0;color:#0F2347;font-size:15px;font-weight:600;">🕐 ${graduando.horaCeremonia}</p>
                <p style="margin:4px 0 0;color:#718096;font-size:13px;">📍 ${AppConstants.eventoLugar}</p>
              </div>
              <p style="color:#2d3748;font-size:15px;">
                Puedes registrar hasta <strong>${AppConstants.maxInvitadosPorGraduando} invitados</strong>.
                Toca el botón para registrarlos:
              </p>
              <div style="text-align:center;margin:32px 0;">
                <a href="$urlRegistro"
                   style="background:linear-gradient(135deg,#0F2347,#1E4D8C);color:#ffffff;padding:16px 40px;border-radius:10px;text-decoration:none;font-size:16px;font-weight:700;display:inline-block;">
                  Registrar mis invitados →
                </a>
              </div>
              <div style="background:#FFF8E1;border:1px solid #F0D060;border-radius:8px;padding:16px;">
                <p style="margin:0;color:#7B5800;font-size:13px;text-align:center;">
                  ⚠️ Cada invitado recibirá su código QR de acceso por correo electrónico.
                </p>
              </div>
            </td>
          </tr>
          <tr>
            <td style="background:#0F2347;padding:24px;text-align:center;">
              <p style="margin:0;color:#B8CCE8;font-size:12px;">Universidad de Santander – UDES | ${AppConstants.eventoCiudad}</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
  }

  // ── Envía invitación a directivo ──
  static Future<bool> enviarInvitacionDirectivo({
    required String nombre,
    required String cargo,
    required String correo,
    required String directivoId,
    required String fechaCeremonia,
    String horaCeremonia = '',
  }) async {
    if (kIsWeb) return false;

    try {
      final smtpServer = gmail(
        AppConstants.emailRemitente,
        AppConstants.emailPassword,
      );

      final urlConfirmar = 'https://apolo-udes.web.app/directivos.html?id=$directivoId&r=si';
      final urlRechazar = 'https://apolo-udes.web.app/directivos.html?id=$directivoId&r=no';

      final html = '''
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:40px 20px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.10);">
        <tr>
          <td style="background:linear-gradient(135deg,#0F2347 0%,#1A3A6B 60%,#1E4D8C 100%);padding:40px;text-align:center;">
            <p style="margin:0 0 8px;color:#B8CCE8;font-size:12px;letter-spacing:2px;text-transform:uppercase;">Universidad de Santander</p>
            <h1 style="margin:0;color:#ffffff;font-size:32px;font-weight:800;">Apolo UDES</h1>
            <p style="margin:8px 0 0;color:#B8CCE8;font-size:14px;">Sistema de Gestión de Ceremonia de Grado</p>
          </td>
        </tr>
        <tr>
          <td style="background:linear-gradient(90deg,#C9A84C,#F0D060,#C9A84C);padding:12px;text-align:center;">
            <p style="margin:0;color:#3D2B00;font-size:13px;font-weight:700;letter-spacing:2px;text-transform:uppercase;">✦ Invitación Oficial - Ceremonia de Graduación ✦</p>
          </td>
        </tr>
        <tr>
          <td style="padding:40px;">
            <p style="margin:0 0 20px;color:#1A3A6B;font-size:18px;font-weight:600;">
              Estimado/a <strong>$nombre</strong>,
            </p>
            <p style="margin:0 0 8px;color:#718096;font-size:13px;font-weight:600;text-transform:uppercase;letter-spacing:1px;">$cargo</p>
            <div style="background:#f8f9fb;border-left:4px solid #C9A84C;border-radius:0 8px 8px 0;padding:20px 24px;margin-bottom:28px;">
              <p style="margin:0;color:#2d3748;font-size:15px;line-height:1.7;">
                En su calidad de <strong>$cargo</strong> de la <strong>Universidad de Santander – UDES</strong>,
                le extendemos una cordial invitación a presidir la <strong>Ceremonia de Graduación</strong>
                de nuestros estudiantes.
              </p>
            </div>
            <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:32px;">
              <tr>
                <td width="48%" style="text-align:center;padding:20px;background:#f8f9fb;border-radius:8px;">
                  <p style="margin:0 0 4px;color:#718096;font-size:11px;text-transform:uppercase;">📅 Fecha</p>
                  <p style="margin:0;color:#0F2347;font-size:14px;font-weight:700;">$fechaCeremonia</p>
                </td>
                <td width="4%"></td>
                <td width="48%" style="text-align:center;padding:20px;background:#f8f9fb;border-radius:8px;">
                  <p style="margin:0 0 4px;color:#718096;font-size:11px;text-transform:uppercase;">🕐 Hora</p>
                  <p style="margin:0;color:#0F2347;font-size:14px;font-weight:700;">${horaCeremonia.isNotEmpty ? horaCeremonia : 'Por confirmar'}</p>
                </td>
              </tr>
            </table>
            <div style="text-align:center;margin-bottom:28px;padding:16px;border:1px solid #e2e8f0;border-radius:8px;">
              <p style="margin:0 0 4px;color:#718096;font-size:11px;text-transform:uppercase;">📍 Lugar</p>
              <p style="margin:0;color:#0F2347;font-size:15px;font-weight:700;">${AppConstants.eventoLugar}</p>
              <p style="margin:4px 0 0;color:#718096;font-size:13px;">${AppConstants.eventoDireccion}</p>
            </div>
            <div style="text-align:center;margin-bottom:28px;">
              <p style="margin:0 0 16px;color:#2d3748;font-size:15px;font-weight:600;">¿Confirma su asistencia?</p>
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td width="50%" style="padding-right:8px;">
                    <a href="$urlConfirmar" style="display:block;padding:16px 8px;background:linear-gradient(135deg,#276749,#38A169);color:#ffffff;border-radius:10px;text-decoration:none;font-size:15px;font-weight:700;text-align:center;">
                      ✅ Sí, asistiré
                    </a>
                  </td>
                  <td width="50%" style="padding-left:8px;">
                    <a href="$urlRechazar" style="display:block;padding:16px 8px;background:#ffffff;color:#e53e3e;border:2px solid #e53e3e;border-radius:10px;text-decoration:none;font-size:15px;font-weight:700;text-align:center;">
                      ❌ No podré asistir
                    </a>
                  </td>
                </tr>
              </table>
            </div>
            <div style="background:#FFF8E1;border:1px solid #F0D060;border-radius:8px;padding:16px;">
              <p style="margin:0;color:#7B5800;font-size:13px;text-align:center;">
                Su presencia es muy importante para nuestra comunidad universitaria.
              </p>
            </div>
          </td>
        </tr>
        <tr>
          <td style="background:#0F2347;padding:28px 40px;text-align:center;">
            <p style="margin:0 0 8px;color:#B8CCE8;font-size:13px;font-weight:600;">Universidad de Santander – UDES</p>
            <p style="margin:0 0 4px;color:#4A6785;font-size:12px;">${AppConstants.eventoDireccion}</p>
            <p style="margin:0;color:#4A6785;font-size:12px;">${AppConstants.eventoCiudad}</p>
            <div style="margin-top:16px;padding-top:16px;border-top:1px solid #1E3A5F;">
              <p style="margin:0;color:#4A6785;font-size:11px;">Acreditada Alta Calidad por el Ministerio de Educación Nacional | SNIES 2832</p>
            </div>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
''';

      final message = Message()
        ..from = Address(AppConstants.emailRemitente, AppConstants.emailNombre)
        ..recipients.add(correo)
        ..subject = 'Invitación Oficial - Ceremonia de Graduación UDES'
        ..html = html;

      await send(message, smtpServer);
      debugPrint('Invitación directivo enviada a: $correo');
      return true;
    } catch (e) {
      debugPrint('ERROR invitación directivo: $e');
      return false;
    }
  }
}