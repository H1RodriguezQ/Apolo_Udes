import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';

class ConfirmacionScreen extends StatelessWidget {
  const ConfirmacionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final confirmaciones = provider.confirmaciones;
    final isAdmin = provider.isAdmin;

    final confirmados = confirmaciones
        .where((c) => c.estado == EstadoConfirmacion.confirmado)
        .length;
    final rechazados = confirmaciones
        .where((c) => c.estado == EstadoConfirmacion.rechazado)
        .length;
    final pendientes = confirmaciones
        .where((c) => c.estado == EstadoConfirmacion.pendiente)
        .length;
    final tasa = confirmaciones.isNotEmpty
        ? (confirmados / confirmaciones.length * 100).round()
        : 0;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Confirmación',
                  subtitle: 'Estado de confirmaciones de asistencia',
                ),
              ),
              // Botón limpiar solo admin
              if (isAdmin && confirmaciones.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _limpiarConfirmaciones(context, provider),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: const Text('Limpiar registros'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Métricas
          Row(
            children: [
              _ConfirmMetric(
                label: 'Confirmados',
                value: '$confirmados',
                color: AppColors.success,
                icon: Icons.check_circle_rounded,
              ),
              const SizedBox(width: 12),
              _ConfirmMetric(
                label: 'Pendientes',
                value: '$pendientes',
                color: AppColors.warning,
                icon: Icons.hourglass_empty_rounded,
              ),
              const SizedBox(width: 12),
              _ConfirmMetric(
                label: 'Rechazados',
                value: '$rechazados',
                color: AppColors.error,
                icon: Icons.block_rounded,
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '$tasa%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const Text(
                      'Tasa de\nconfirmación',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Tabla
          Expanded(
            child: Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: confirmaciones.isEmpty
                    ? const EmptyState(
                        icon: Icons.check_circle_outline,
                        title: 'Sin confirmaciones',
                        subtitle: 'Las confirmaciones aparecerán aquí',
                      )
                    : SingleChildScrollView(
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(3),
                            1: FlexColumnWidth(3),
                            2: FlexColumnWidth(2),
                            3: FlexColumnWidth(2),
                            4: FlexColumnWidth(1.5),
                            5: FlexColumnWidth(1),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceVariant,
                              ),
                              children: [
                                'Invitado',
                                'Graduando',
                                'Documento',
                                'Estado',
                                'Código QR',
                                'Acción',
                              ]
                                  .map(
                                    (h) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      child: Text(
                                        h,
                                        style: AppTextStyles.label.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            ...confirmaciones.asMap().entries.map((entry) {
                              final i = entry.key;
                              final c = entry.value;
                              return TableRow(
                                decoration: BoxDecoration(
                                  color: i.isEven
                                      ? Colors.white
                                      : const Color(0xFFFAFBFC),
                                  border: const Border(
                                    bottom: BorderSide(color: AppColors.divider),
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        UserAvatar(name: c.invitado, size: 30),
                                        const SizedBox(width: 10),
                                        Text(c.invitado,
                                            style: AppTextStyles.body),
                                      ],
                                    ),
                                  ),
                                  _cell(c.graduandoNombre),
                                  _cell(c.documento),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: StatusBadge.fromEstadoConfirmacion(
                                        c.estado),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Text(
                                      c.codigoQr ?? '—',
                                      style: AppTextStyles.caption.copyWith(
                                        fontFamily: 'monospace',
                                        color: AppColors.primaryLight,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: IconButton(
                                      icon: const Icon(Icons.send_rounded,
                                          size: 18),
                                      color: AppColors.primaryLight,
                                      tooltip: 'Reenviar',
                                      onPressed: () {},
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Limpiar confirmaciones con registro de auditoría ──
  Future<void> _limpiarConfirmaciones(
      BuildContext context, AppProvider provider) async {
    final cantidad = provider.confirmaciones.length;
    final usuario = provider.usuarioActual?.correo ?? 'admin';

    final confirm = await showConfirmDialog(
      context,
      title: 'Limpiar confirmaciones',
      content:
          '¿Está seguro de eliminar los $cantidad registros de confirmación?\n\nEsta acción quedará registrada en la auditoría del sistema.',
      confirmLabel: 'Limpiar registros',
      isDangerous: true,
    );

    if (confirm == true && context.mounted) {
      provider.limpiarConfirmaciones();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ $cantidad registros eliminados por $usuario',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _cell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text, style: AppTextStyles.body),
    );
  }
}

class _ConfirmMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _ConfirmMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(label, style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}