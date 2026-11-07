import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../navegacion.dart';
import '../../widgets/common/apolo_ui.dart';

/// "Enviar recordatorio a invitados" (rediseño). A la izquierda se arma el
/// correo; a la derecha están los envíos anteriores y cómo van.
///
/// La app NO manda correos: deja una petición en `solicitudes_correo` y el
/// servidor (Apps Script) la procesa cada 5 minutos, respetando el límite
/// diario de Gmail.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _asuntoCtrl = TextEditingController(text: 'Recuerde confirmar su asistencia a la ceremonia de grado');
  final _mensajeCtrl = TextEditingController();
  String _destinatarios = 'pendientes';
  bool _enviando = false;

  @override
  void dispose() {
    _asuntoCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _programar(AppProvider provider) async {
    final asunto = _asuntoCtrl.text.trim();
    if (asunto.isEmpty) {
      _aviso('Escriba el asunto del correo.', error: true);
      return;
    }
    setState(() => _enviando = true);
    try {
      await provider.enviarCampana(titulo: asunto, mensaje: _mensajeCtrl.text.trim(), destinatarios: _destinatarios);
      _mensajeCtrl.clear();
      _aviso('Envío programado. El servidor lo procesa en unos minutos.');
    } catch (e) {
      _aviso('No se pudo programar el envío: $e', error: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _aviso(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: error ? AppColors.error : AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final invitaciones = provider.invitaciones.where((i) => i.estado != EstadoInvitacion.anulada).toList();
    final confirmados = invitaciones.where((i) => i.estado == EstadoInvitacion.confirmada).length;
    final pendientes = invitaciones
        .where((i) => i.estado == EstadoInvitacion.enviada || i.estado == EstadoInvitacion.pendiente)
        .length;
    final ancho = MediaQuery.sizeOf(context).width;

    final formulario = Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('¿A quién se envía?', style: AppTextStyles.h4),
          const SizedBox(height: 12),
          for (final o in [
            ('pendientes', 'Invitados que no han confirmado', pendientes),
            ('confirmados', 'Invitados que ya confirmaron', confirmados),
            ('todos', 'Todos los invitados (sin anulados)', invitaciones.length),
          ])
            _OpcionDestino(
              texto: o.$2,
              cantidad: o.$3,
              elegida: _destinatarios == o.$1,
              onTap: () => setState(() => _destinatarios = o.$1),
            ),
          const SizedBox(height: 14),
          CampoConEtiqueta(
            etiqueta: 'Asunto del correo',
            campo: TextField(controller: _asuntoCtrl, maxLength: 120, decoration: const InputDecoration(counterText: '')),
          ),
          const SizedBox(height: 14),
          CampoConEtiqueta(
            etiqueta: 'Mensaje',
            nota: '(opcional; el correo ya incluye la fecha, la hora y el enlace a su código QR)',
            campo: TextField(controller: _mensajeCtrl, maxLines: 4, maxLength: 1000, decoration: const InputDecoration(counterText: '')),
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'El servidor de correos toma la petición en máximo 5 minutos. El avance se ve en «Envíos anteriores».',
                  style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _enviando ? null : () => _programar(provider),
                  child: Text(_enviando ? 'Programando…' : 'Programar envío'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final anteriores = Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 14), child: Text('Envíos anteriores', style: AppTextStyles.h4)),
          Divider(height: 1, color: AppColors.border),
          if (provider.notificaciones.isEmpty)
            Padding(padding: const EdgeInsets.all(20), child: Text('Todavía no se ha enviado ningún correo masivo.', style: AppTextStyles.label)),
          for (final c in provider.notificaciones.take(8)) _FilaEnvio(campana: c, provider: provider),
        ],
      ),
    );

    return PantallaApolo(
      desplazable: true,
      encabezado: EncabezadoPantalla(
        titulo: 'Enviar recordatorio a invitados',
        alVolver: () => provider.setSelectedIndex(Nav.invitados),
      ),
      cuerpo: ancho >= 1100
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: formulario),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: anteriores),
              ],
            )
          : Column(children: [formulario, const SizedBox(height: 20), anteriores]),
    );
  }
}

class _OpcionDestino extends StatelessWidget {
  final String texto;
  final int cantidad;
  final bool elegida;
  final VoidCallback onTap;
  const _OpcionDestino({required this.texto, required this.cantidad, required this.elegida, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: elegida ? AppColors.infoLight : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: elegida ? AppColors.boton : AppColors.border, width: elegida ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(elegida ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 20, color: elegida ? AppColors.boton : AppColors.textHint),
                const SizedBox(width: 12),
                Expanded(child: Text(texto, style: AppTextStyles.body)),
                Text('$cantidad personas', style: AppTextStyles.mono(size: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaEnvio extends StatelessWidget {
  final CampanaNotificacion campana;
  final AppProvider provider;
  const _FilaEnvio({required this.campana, required this.provider});

  @override
  Widget build(BuildContext context) {
    final (texto, tono) = switch (campana.estado) {
      EstadoNotificacion.terminada || EstadoNotificacion.enviado => ('Terminado', TonoEtiqueta.ok),
      EstadoNotificacion.enProceso => ('En curso', TonoEtiqueta.info),
      EstadoNotificacion.rechazado => ('Con error', TonoEtiqueta.error),
      EstadoNotificacion.pendiente => ('En cola', TonoEtiqueta.aviso),
    };
    final fecha = campana.fechaEnvio == null ? '' : DateFormat("d 'de' MMMM, h:mm a", 'es_CO').format(campana.fechaEnvio!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(campana.titulo, style: AppTextStyles.body, maxLines: 1, overflow: TextOverflow.ellipsis)),
              Etiqueta(texto, tono: tono),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text('${campana.totalDestinatarios} enviados · $fecha',
                    style: AppTextStyles.mono(size: 12, color: AppColors.textSecondary)),
              ),
              if (campana.estado == EstadoNotificacion.rechazado)
                TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await provider.reintentarCorreo(campana);
                    messenger.showSnackBar(SnackBar(
                      backgroundColor: ok ? AppColors.success : AppColors.error,
                      content: Text(ok ? 'Reintentado: el servidor lo procesa en unos minutos.' : 'No fue posible reintentar.'),
                    ));
                  },
                  child: const Text('Reintentar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
