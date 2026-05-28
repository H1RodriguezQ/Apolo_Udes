import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';

class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final notificaciones = provider.notificaciones;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final enCola = notificaciones.where((n) => n.estado == EstadoNotificacion.pendiente).length;
    final leidos = notificaciones.where((n) => n.estado == EstadoNotificacion.enviado).fold<int>(0, (sum, n) => sum + n.totalDestinatarios);
    final rechazados = notificaciones.where((n) => n.estado == EstadoNotificacion.rechazado).fold<int>(0, (sum, n) => sum + n.totalDestinatarios);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: 'Notificaciones', subtitle: 'Gestión de campañas de comunicación')),
              ElevatedButton.icon(
                onPressed: () => _mostrarNuevaCampana(context, provider),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nueva campaña'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          isMobile
              ? Column(children: [
                  Row(children: [
                    _NotifMetric(label: 'En cola', value: '$enCola', color: AppColors.warning, icon: Icons.schedule_send_rounded),
                    const SizedBox(width: 10),
                    _NotifMetric(label: 'Leídos', value: '$leidos', color: AppColors.success, icon: Icons.mark_email_read_rounded),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _NotifMetric(label: 'Rechazados', value: '$rechazados', color: AppColors.error, icon: Icons.email_outlined),
                    const Expanded(child: SizedBox()),
                  ]),
                ])
              : Row(children: [
                  _NotifMetric(label: 'Envíos en cola', value: '$enCola', color: AppColors.warning, icon: Icons.schedule_send_rounded),
                  const SizedBox(width: 12),
                  _NotifMetric(label: 'Mensajes Leídos', value: '$leidos', color: AppColors.success, icon: Icons.mark_email_read_rounded),
                  const SizedBox(width: 12),
                  _NotifMetric(label: 'Rechazados', value: '$rechazados', color: AppColors.error, icon: Icons.email_outlined),
                ]),

          const SizedBox(height: 16),

          Expanded(
            child: notificaciones.isEmpty
                ? const EmptyState(
                    icon: Icons.campaign_rounded,
                    title: 'Sin campañas',
                    subtitle: 'Crea una nueva campaña para enviar notificaciones',
                  )
                : ListView.separated(
                    itemCount: notificaciones.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _CampaignCard(campana: notificaciones[i], isMobile: isMobile),
                  ),
          ),
        ],
      ),
    );
  }

  void _mostrarNuevaCampana(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => _NuevaCampanaDialog(provider: provider),
    );
  }
}

class _NuevaCampanaDialog extends StatefulWidget {
  final AppProvider provider;
  const _NuevaCampanaDialog({required this.provider});

  @override
  State<_NuevaCampanaDialog> createState() => _NuevaCampanaDialogState();
}

class _NuevaCampanaDialogState extends State<_NuevaCampanaDialog> {
  final _tituloCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();
  String _destinatarios = 'todos';
  bool _enviando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_tituloCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un título'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      await widget.provider.enviarCampana(
        titulo: _tituloCtrl.text.trim(),
        mensaje: _mensajeCtrl.text.trim(),
        destinatarios: _destinatarios,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Campaña enviada exitosamente'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text('Nueva campaña', style: AppTextStyles.h2)),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),
              const Text('Título', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              TextField(
                controller: _tituloCtrl,
                decoration: const InputDecoration(hintText: 'Ej: Recordatorio ceremonia de grado'),
              ),
              const SizedBox(height: 14),
              const Text('Mensaje (opcional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              TextField(
                controller: _mensajeCtrl,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Mensaje adicional para los invitados...'),
              ),
              const SizedBox(height: 14),
              const Text('Destinatarios', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _destinatarios,
                decoration: const InputDecoration(),
                items: const [
                  DropdownMenuItem(value: 'todos', child: Text('Todos los invitados')),
                  DropdownMenuItem(value: 'confirmados', child: Text('Solo confirmados')),
                  DropdownMenuItem(value: 'pendientes', child: Text('Solo pendientes')),
                ],
                onChanged: (v) => setState(() => _destinatarios = v!),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _enviando ? null : _enviar,
                    icon: _enviando
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(_enviando ? 'Enviando...' : 'Enviar campaña'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final CampanaNotificacion campana;
  final bool isMobile;
  const _CampaignCard({required this.campana, required this.isMobile});

  Color get _statusColor {
    switch (campana.estado) {
      case EstadoNotificacion.enviado: return AppColors.success;
      case EstadoNotificacion.pendiente: return AppColors.warning;
      case EstadoNotificacion.rechazado: return AppColors.error;
    }
  }

  String get _statusLabel {
    switch (campana.estado) {
      case EstadoNotificacion.enviado: return 'Enviado';
      case EstadoNotificacion.pendiente: return 'En cola';
      case EstadoNotificacion.rechazado: return 'Rechazado';
    }
  }

  IconData get _icon {
    switch (campana.estado) {
      case EstadoNotificacion.enviado: return Icons.check_circle_rounded;
      case EstadoNotificacion.pendiente: return Icons.schedule_rounded;
      case EstadoNotificacion.rechazado: return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(_icon, color: _statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(campana.titulo, style: AppTextStyles.h4)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text(_statusLabel, style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ]),
                Text(campana.descripcion, style: AppTextStyles.bodySmall),
              ])),
            ]),
            if (campana.fechaEnvio != null) ...[
              const SizedBox(height: 10),
              Text(DateFormat('dd/MM/yyyy HH:mm').format(campana.fechaEnvio!), style: AppTextStyles.caption),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotifMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _NotifMetric({required this.label, required this.value, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(label, style: AppTextStyles.label),
          ])),
        ]),
      ),
    );
  }
}