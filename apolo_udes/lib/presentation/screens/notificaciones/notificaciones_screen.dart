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

    final enCola = notificaciones
        .where((n) => n.estado == EstadoNotificacion.pendiente)
        .length;
    final leidos = notificaciones
        .where((n) => n.estado == EstadoNotificacion.enviado)
        .fold<int>(0, (sum, n) => sum + n.totalDestinatarios);
    final rechazados = notificaciones
        .where((n) => n.estado == EstadoNotificacion.rechazado)
        .fold<int>(0, (sum, n) => sum + n.totalDestinatarios);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Notificaciones',
            subtitle: 'Gestión de campañas de comunicación',
            action: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva campaña'),
            ),
          ),

          const SizedBox(height: 20),

          // Metrics
          Row(
            children: [
              _NotifMetric(
                label: 'Envíos en cola',
                value: '$enCola',
                color: AppColors.warning,
                icon: Icons.schedule_send_rounded,
              ),
              const SizedBox(width: 12),
              _NotifMetric(
                label: 'Mensajes Leídos',
                value: '$leidos',
                color: AppColors.success,
                icon: Icons.mark_email_read_rounded,
              ),
              const SizedBox(width: 12),
              _NotifMetric(
                label: 'Rechazados',
                value: '$rechazados',
                color: AppColors.error,
                icon: Icons.email_outlined,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Campaigns list
          Expanded(
            child: ListView.separated(
              itemCount: notificaciones.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final n = notificaciones[i];
                return _CampaignCard(campana: n);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final CampanaNotificacion campana;

  const _CampaignCard({required this.campana});

  Color get _statusColor {
    switch (campana.estado) {
      case EstadoNotificacion.enviado:
        return AppColors.success;
      case EstadoNotificacion.pendiente:
        return AppColors.warning;
      case EstadoNotificacion.rechazado:
        return AppColors.error;
    }
  }

  String get _statusLabel {
    switch (campana.estado) {
      case EstadoNotificacion.enviado:
        return 'Enviado';
      case EstadoNotificacion.pendiente:
        return 'En cola';
      case EstadoNotificacion.rechazado:
        return 'Rechazado';
    }
  }

  IconData get _icon {
    switch (campana.estado) {
      case EstadoNotificacion.enviado:
        return Icons.check_circle_rounded;
      case EstadoNotificacion.pendiente:
        return Icons.schedule_rounded;
      case EstadoNotificacion.rechazado:
        return Icons.cancel_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: _statusColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        campana.titulo,
                        style: AppTextStyles.h4,
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel,
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(campana.descripcion, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (campana.fechaEnvio != null) ...[
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(campana.fechaEnvio!),
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 4),
                ] else
                  const Text('Sin enviar', style: AppTextStyles.caption),
                if (campana.estado == EstadoNotificacion.enviado) ...[
                  Row(
                    children: [
                      const Icon(Icons.people_rounded, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(
                        '${campana.totalDestinatarios} dest.',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${campana.tasaEntrega.toStringAsFixed(0)}% entrega',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(width: 12),
            if (campana.estado == EstadoNotificacion.pendiente)
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Enviar', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                onPressed: () {},
              ),
          ],
        ),
      ),
    );
  }
}

class _NotifMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _NotifMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(label, style: AppTextStyles.label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
