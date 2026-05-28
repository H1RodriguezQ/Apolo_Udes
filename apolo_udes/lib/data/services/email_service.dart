import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import '../../../core/constants/app_constants.dart';
import '../models/models.dart';

class EmailService {
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
    if (kIsWeb) return false;
    final correoLimpio = correoInvitado.trim().toLowerCase();
    try {
      final smtpServer = gmail(AppConstants.emailRemitente, AppConstants.emailPassword);
      final qrSrc = qrUrl.isNotEmpty ? qrUrl : 'data:image/png;base64,$qrBase64';
      final message = Message()
        ..from = Address(AppConstants.emailRemitente, AppConstants.emailNombre)
        ..recipients.add(correoLimpio)
        ..subject = 'Invitación - Ceremonia de Grado UDES | ${graduando.nombreCompleto}'
        ..html = _buildEmailHtml(
          graduando: graduando,
          nombreInvitado: nombreInvitado,
          codigoQr: codigoQr,
          qrSrc: qrSrc,
          fechaCeremonia: fechaCeremonia,
          invitadoId: invitadoId,
        );
      await send(message, smtpServer);
      debugPrint('✅ Invitación enviada a $correoLimpio');
      return true;
    } catch (e) {
      debugPrint('ERROR EMAIL invitación: $e');
      return false;
    }
  }

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
    final correoLimpio = correoInvitado.trim().toLowerCase();
    try {
      final smtpServer = gmail(AppConstants.emailRemitente, AppConstants.emailPassword);
      final qrSrc = qrUrl.isNotEmpty ? qrUrl : (qrBase64.isNotEmpty ? 'data:image/png;base64,$qrBase64' : '');
      final message = Message()
        ..from = Address(AppConstants.emailRemitente, AppConstants.emailNombre)
        ..recipients.add(correoLimpio)
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
      return true;
    } catch (e) {
      debugPrint('ERROR recordatorio: $e');
      return false;
    }
  }

  static Future<bool> enviarCorreoRegistroInvitados({
    required Graduando graduando,
    String fechaCeremonia = '',
  }) async {
    if (kIsWeb) return false;
    final correoLimpio = graduando.correo.trim().toLowerCase();
    try {
      final smtpServer = gmail(AppConstants.emailRemitente, AppConstants.emailPassword);
      final urlRegistro = 'https://apolo-udes.web.app/invitados.html?id=${graduando.id}';
      final message = Message()
        ..from = Address(AppConstants.emailRemitente, AppConstants.emailNombre)
        ..recipients.add(correoLimpio)
        ..subject = '¡Felicitaciones! Registra tus invitados - Ceremonia de Grado UDES'
        ..html = _buildCorreoGraduando(
          graduando: graduando,
          urlRegistro: urlRegistro,
          fechaCeremonia: fechaCeremonia,
        );
      await send(message, smtpServer);
      debugPrint('✅ Correo graduando enviado a $correoLimpio');
      return true;
    } catch (e) {
      debugPrint('ERROR correo graduando: $e');
      return false;
    }
  }

  static Future<bool> enviarInvitacionDirectivo({
    required String nombre,
    required String cargo,
    required String correo,
    required String directivoId,
    required String fechaCeremonia,
    String horaCeremonia = '',
  }) async {
    if (kIsWeb) return false;
    final correoLimpio = correo.trim().toLowerCase();
    try {
      final smtpServer = gmail(AppConstants.emailRemitente, AppConstants.emailPassword);
      final urlConfirmar = 'https://apolo-udes.web.app/directivos.html?id=$directivoId&r=si';
      final urlRechazar = 'https://apolo-udes.web.app/directivos.html?id=$directivoId&r=no';
      final horaTexto = horaCeremonia.isNotEmpty ? horaCeremonia : 'Por confirmar';
      final html = _buildDirectivoHtml(
        nombre: nombre,
        cargo: cargo,
        fechaCeremonia: fechaCeremonia,
        horaTexto: horaTexto,
        urlConfirmar: urlConfirmar,
        urlRechazar: urlRechazar,
      );
      final message = Message()
        ..from = Address(AppConstants.emailRemitente, AppConstants.emailNombre)
        ..recipients.add(correoLimpio)
        ..subject = 'Invitación Oficial - Ceremonia de Graduación UDES'
        ..html = html;
      await send(message, smtpServer);
      debugPrint('✅ Invitación directivo enviada a $correoLimpio');
      return true;
    } catch (e) {
      debugPrint('ERROR directivo: $e');
      return false;
    }
  }

  static String _buildCorreoGraduando({
    required Graduando graduando,
    required String urlRegistro,
    String fechaCeremonia = '',
  }) {
    final nombre = graduando.nombreCompleto;
    final programa = graduando.programa;
    final facultad = graduando.facultad;
    final hora = graduando.horaCeremonia;
    final lugar = AppConstants.eventoLugar;
    final maxInvitados = AppConstants.maxInvitadosPorGraduando;
    final fechaHtml = fechaCeremonia.isNotEmpty
        ? '<p style="margin:8px 0 0;color:#0F2347;font-size:15px;font-weight:600;">📅 $fechaCeremonia</p>'
        : '';

    return '''
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:40px 20px;">
    <tr><td align="center">
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
            <p style="color:#0F2347;font-size:18px;font-weight:600;">Estimado/a <strong>$nombre</strong>,</p>
            <p style="color:#2d3748;font-size:15px;line-height:1.7;">
              Nos complace informarte que has sido registrado/a para la <strong>Ceremonia de Graduación</strong>
              de la Universidad de Santander – UDES.
            </p>
            <div style="background:#f8f9fb;border-radius:12px;padding:20px;margin:24px 0;text-align:center;">
              <p style="margin:0 0 4px;color:#718096;font-size:12px;text-transform:uppercase;">Programa</p>
              <p style="margin:0;color:#0F2347;font-size:16px;font-weight:700;">$programa</p>
              <p style="margin:4px 0 0;color:#718096;font-size:13px;">$facultad</p>
              $fechaHtml
              <p style="margin:8px 0 0;color:#0F2347;font-size:15px;font-weight:600;">🕐 $hora</p>
              <p style="margin:4px 0 0;color:#718096;font-size:13px;">📍 $lugar</p>
            </div>
            <p style="color:#2d3748;font-size:15px;">
              Puedes registrar hasta <strong>$maxInvitados invitados</strong>. Toca el botón para registrarlos:
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
            <p style="margin:0;color:#B8CCE8;font-size:12px;">Universidad de Santander – UDES</p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
''';
  }

  static String _buildEmailHtml({
    required Graduando graduando,
    required String nombreInvitado,
    required String codigoQr,
    required String qrSrc,
    required String fechaCeremonia,
    String invitadoId = '',
  }) {
    final nombreGrad = graduando.nombreCompleto;
    final programa = graduando.programa;
    final facultad = graduando.facultad;
    final hora = graduando.horaCeremonia;
    final lugar = AppConstants.eventoLugar;
    final direccion = AppConstants.eventoDireccion;

    final botonesConfirmacion = invitadoId.isNotEmpty ? '''
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
      </div>''' : '';

    return '''
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:40px 20px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.10);">
        <tr>
          <td style="background:linear-gradient(135deg,#0F2347 0%,#1A3A6B 60%,#1E4D8C 100%);padding:40px;text-align:center;">
            <p style="margin:0 0 8px;color:#B8CCE8;font-size:12px;letter-spacing:2px;text-transform:uppercase;">Universidad de Santander</p>
            <h1 style="margin:0;color:#ffffff;font-size:32px;font-weight:800;">Apolo UDES</h1>
          </td>
        </tr>
        <tr>
          <td style="background:linear-gradient(90deg,#C9A84C,#F0D060,#C9A84C);padding:12px;text-align:center;">
            <p style="margin:0;color:#3D2B00;font-size:13px;font-weight:700;letter-spacing:2px;">✦ Invitación a: Ceremonia de Graduación ✦</p>
          </td>
        </tr>
        <tr>
          <td style="padding:40px;">
            <p style="margin:0 0 20px;color:#1A3A6B;font-size:18px;font-weight:600;">Estimado/a <strong>$nombreInvitado</strong>,</p>
            <div style="background:#f8f9fb;border-left:4px solid #1A3A6B;border-radius:0 8px 8px 0;padding:20px 24px;margin-bottom:28px;">
              <p style="margin:0;color:#2d3748;font-size:15px;line-height:1.7;">
                El Rector General y el Consejo Académico de la <strong>Universidad de Santander – UDES</strong>
                tienen el gusto de invitarle al acto académico por medio del cual se otorga el título de tecnólogos y profesionales.
              </p>
            </div>
            <div style="text-align:center;margin-bottom:28px;">
              <p style="margin:0 0 4px;color:#718096;font-size:13px;text-transform:uppercase;">Graduando</p>
              <h2 style="margin:0;color:#0F2347;font-size:26px;font-weight:800;">$nombreGrad</h2>
              <p style="margin:6px 0 0;color:#1A3A6B;font-size:15px;font-weight:500;">$programa</p>
              <p style="margin:4px 0 0;color:#718096;font-size:13px;">$facultad</p>
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
                  <p style="margin:0;color:#0F2347;font-size:14px;font-weight:700;">$hora</p>
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
              <p style="margin:0;color:#0F2347;font-size:15px;font-weight:700;">$lugar</p>
              <p style="margin:4px 0 0;color:#718096;font-size:13px;">$direccion</p>
            </div>
            <div style="text-align:center;margin-bottom:28px;">
              <p style="margin:0 0 16px;color:#2d3748;font-size:14px;font-weight:600;">Presenta este código QR el día del evento</p>
              <div style="display:inline-block;padding:16px;background:#ffffff;border:2px solid #1A3A6B;border-radius:12px;">
                <img src="$qrSrc" width="180" height="180" alt="Código QR" style="display:block;" />
              </div>
              <p style="margin:12px 0 0;color:#718096;font-size:12px;">Código: <strong style="color:#0F2347;">$codigoQr</strong></p>
            </div>
            $botonesConfirmacion
            <div style="background:#FFF8E1;border:1px solid #F0D060;border-radius:8px;padding:16px;">
              <p style="margin:0;color:#7B5800;font-size:13px;text-align:center;">
                ⚠️ Esta invitación es personal e intransferible.
              </p>
            </div>
          </td>
        </tr>
        <tr>
          <td style="background:#0F2347;padding:28px 40px;text-align:center;">
            <p style="margin:0;color:#B8CCE8;font-size:13px;">Universidad de Santander – UDES</p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
''';
  }

  static String _buildRecordatorioHtml({
    required String nombreInvitado,
    required String codigoQr,
    required String fechaCeremonia,
    required String horaCeremonia,
    required String graduandoNombre,
    String qrSrc = '',
  }) {
    final qrHtml = qrSrc.isNotEmpty ? '''
      <div style="text-align:center;margin-bottom:28px;">
        <div style="display:inline-block;padding:16px;background:#ffffff;border:2px solid #1A3A6B;border-radius:12px;">
          <img src="$qrSrc" width="180" height="180" alt="QR" style="display:block;" />
        </div>
        <p style="margin:12px 0 0;color:#718096;font-size:12px;">Código: <strong>$codigoQr</strong></p>
      </div>''' : '<p style="text-align:center;color:#718096;">Código: <strong>$codigoQr</strong></p>';

    return '''
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:40px 20px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;">
        <tr>
          <td style="background:linear-gradient(135deg,#0F2347,#1A3A6B);padding:40px;text-align:center;">
            <h1 style="margin:0;color:#ffffff;font-size:28px;">Apolo UDES</h1>
            <p style="margin:8px 0 0;color:#B8CCE8;font-size:14px;">Universidad de Santander</p>
          </td>
        </tr>
        <tr>
          <td style="background:linear-gradient(90deg,#C9A84C,#F0D060,#C9A84C);padding:12px;text-align:center;">
            <p style="margin:0;color:#3D2B00;font-size:13px;font-weight:700;">🔔 Recordatorio de Ceremonia</p>
          </td>
        </tr>
        <tr>
          <td style="padding:40px;">
            <p style="color:#1A3A6B;font-size:18px;font-weight:600;">Estimado/a <strong>$nombreInvitado</strong>,</p>
            <p style="color:#2d3748;font-size:15px;">Le recordamos su invitación a la Ceremonia de Graduación de la Universidad de Santander – UDES.</p>
            <table width="100%" cellpadding="0" cellspacing="0" style="margin:24px 0;">
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
            $qrHtml
            <div style="background:#FFF8E1;border:1px solid #F0D060;border-radius:8px;padding:16px;">
              <p style="margin:0;color:#7B5800;font-size:13px;text-align:center;">⚠️ Presente su QR el día del evento.</p>
            </div>
          </td>
        </tr>
        <tr>
          <td style="background:#0F2347;padding:24px;text-align:center;">
            <p style="margin:0;color:#B8CCE8;font-size:12px;">Universidad de Santander – UDES</p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
''';
  }

  static String _buildDirectivoHtml({
    required String nombre,
    required String cargo,
    required String fechaCeremonia,
    required String horaTexto,
    required String urlConfirmar,
    required String urlRechazar,
  }) {
    final lugar = AppConstants.eventoLugar;
    final direccion = AppConstants.eventoDireccion;
    final ciudad = AppConstants.eventoCiudad;

    return '''
<!DOCTYPE html>
<html lang="es">
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:'Segoe UI',Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:40px 20px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:16px;overflow:hidden;">
        <tr>
          <td style="background:linear-gradient(135deg,#0F2347,#1A3A6B);padding:40px;text-align:center;">
            <h1 style="margin:0;color:#ffffff;font-size:32px;font-weight:800;">Apolo UDES</h1>
            <p style="margin:8px 0 0;color:#B8CCE8;font-size:14px;">Universidad de Santander</p>
          </td>
        </tr>
        <tr>
          <td style="background:linear-gradient(90deg,#C9A84C,#F0D060,#C9A84C);padding:12px;text-align:center;">
            <p style="margin:0;color:#3D2B00;font-size:13px;font-weight:700;">✦ Invitación Oficial - Ceremonia de Graduación ✦</p>
          </td>
        </tr>
        <tr>
          <td style="padding:40px;">
            <p style="color:#1A3A6B;font-size:18px;font-weight:600;">Estimado/a <strong>$nombre</strong>,</p>
            <p style="color:#718096;font-size:13px;font-weight:600;text-transform:uppercase;">$cargo</p>
            <p style="color:#2d3748;font-size:15px;line-height:1.7;">
              En su calidad de <strong>$cargo</strong>, le extendemos una cordial invitación a presidir
              la <strong>Ceremonia de Graduación</strong> de la Universidad de Santander – UDES.
            </p>
            <table width="100%" cellpadding="0" cellspacing="0" style="margin:24px 0;">
              <tr>
                <td width="48%" style="text-align:center;padding:20px;background:#f8f9fb;border-radius:8px;">
                  <p style="margin:0 0 4px;color:#718096;font-size:11px;text-transform:uppercase;">📅 Fecha</p>
                  <p style="margin:0;color:#0F2347;font-size:14px;font-weight:700;">$fechaCeremonia</p>
                </td>
                <td width="4%"></td>
                <td width="48%" style="text-align:center;padding:20px;background:#f8f9fb;border-radius:8px;">
                  <p style="margin:0 0 4px;color:#718096;font-size:11px;text-transform:uppercase;">🕐 Hora</p>
                  <p style="margin:0;color:#0F2347;font-size:14px;font-weight:700;">$horaTexto</p>
                </td>
              </tr>
            </table>
            <div style="text-align:center;margin-bottom:28px;padding:16px;border:1px solid #e2e8f0;border-radius:8px;">
              <p style="margin:0 0 4px;color:#718096;font-size:11px;text-transform:uppercase;">📍 Lugar</p>
              <p style="margin:0;color:#0F2347;font-size:15px;font-weight:700;">$lugar</p>
              <p style="margin:4px 0 0;color:#718096;font-size:13px;">$direccion</p>
            </div>
            <div style="text-align:center;margin-bottom:28px;">
              <p style="margin:0 0 16px;color:#2d3748;font-size:15px;font-weight:600;">¿Confirma su asistencia?</p>
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td width="50%" style="padding-right:8px;">
                    <a href="$urlConfirmar" style="display:block;padding:16px;background:linear-gradient(135deg,#276749,#38A169);color:#ffffff;border-radius:10px;text-decoration:none;font-size:15px;font-weight:700;text-align:center;">
                      ✅ Sí, asistiré
                    </a>
                  </td>
                  <td width="50%" style="padding-left:8px;">
                    <a href="$urlRechazar" style="display:block;padding:16px;background:#ffffff;color:#e53e3e;border:2px solid #e53e3e;border-radius:10px;text-decoration:none;font-size:15px;font-weight:700;text-align:center;">
                      ❌ No podré asistir
                    </a>
                  </td>
                </tr>
              </table>
            </div>
          </td>
        </tr>
        <tr>
          <td style="background:#0F2347;padding:24px;text-align:center;">
            <p style="margin:0;color:#B8CCE8;font-size:12px;">Universidad de Santander – UDES | $ciudad</p>
          </td>
        </tr>
      </table>
    </td></tr>
  </table>
</body>
</html>
''';
  }
}