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
    final isMobile = MediaQuery.of(context).size.width < 600;

    final confirmados = confirmaciones.where((c) => c.estado == EstadoConfirmacion.confirmado).length;
    final rechazados = confirmaciones.where((c) => c.estado == EstadoConfirmacion.rechazado).length;
    final pendientes = confirmaciones.where((c) => c.estado == EstadoConfirmacion.pendiente).length;
    final tasa = confirmaciones.isNotEmpty ? (confirmados / confirmaciones.length * 100).round() : 0;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: 'Confirmación', subtitle: 'Estado de confirmaciones de asistencia')),
              if (isAdmin && confirmaciones.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => _limpiar(context, provider),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: Text(isMobile ? 'Limpiar' : 'Limpiar registros'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Métricas
          isMobile
              ? Column(children: [
                  Row(children: [
                    _ConfirmMetric(label: 'Confirmados', value: '$confirmados', color: AppColors.success, icon: Icons.check_circle_rounded),
                    const SizedBox(width: 10),
                    _ConfirmMetric(label: 'Pendientes', value: '$pendientes', color: AppColors.warning, icon: Icons.hourglass_empty_rounded),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _ConfirmMetric(label: 'Rechazados', value: '$rechazados', color: AppColors.error, icon: Icons.block_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primaryLight, AppColors.primary]), borderRadius: BorderRadius.circular(12)),
                        child: Column(children: [
                          Text('$tasa%', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                          const Text('Tasa de confirmación', style: TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.center),
                        ]),
                      ),
                    ),
                  ]),
                ])
              : Row(children: [
                  _ConfirmMetric(label: 'Confirmados', value: '$confirmados', color: AppColors.success, icon: Icons.check_circle_rounded),
                  const SizedBox(width: 12),
                  _ConfirmMetric(label: 'Pendientes', value: '$pendientes', color: AppColors.warning, icon: Icons.hourglass_empty_rounded),
                  const SizedBox(width: 12),
                  _ConfirmMetric(label: 'Rechazados', value: '$rechazados', color: AppColors.error, icon: Icons.block_rounded),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primaryLight, AppColors.primary]), borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      Text('$tasa%', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1)),
                      const Text('Tasa de\nconfirmación', style: TextStyle(color: Colors.white70, fontSize: 11), textAlign: TextAlign.center),
                    ]),
                  ),
                ]),

          const SizedBox(height: 16),

          Expanded(
            child: Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: confirmaciones.isEmpty
                    ? const EmptyState(icon: Icons.check_circle_outline, title: 'Sin confirmaciones', subtitle: 'Las confirmaciones aparecerán aquí')
                    : isMobile
                        ? _ConfirmacionesList(confirmaciones: confirmaciones)
                        : _ConfirmacionesTable(confirmaciones: confirmaciones),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _limpiar(BuildContext context, AppProvider provider) async {
    final cantidad = provider.confirmaciones.length;
    final confirm = await showConfirmDialog(context, title: 'Limpiar confirmaciones', content: '¿Eliminar los $cantidad registros?', confirmLabel: 'Limpiar', isDangerous: true);
    if (confirm == true && context.mounted) {
      provider.limpiarConfirmaciones();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ $cantidad registros eliminados'), backgroundColor: AppColors.success));
    }
  }
}

class _ConfirmacionesList extends StatelessWidget {
  final List<Confirmacion> confirmaciones;
  const _ConfirmacionesList({required this.confirmaciones});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: confirmaciones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = confirmaciones[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
          child: Row(children: [
            UserAvatar(name: c.invitado, size: 38),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.invitado, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
              Text(c.graduandoNombre, style: AppTextStyles.bodySmall),
              Text('Doc: ${c.documento}', style: AppTextStyles.caption),
            ])),
            StatusBadge.fromEstadoConfirmacion(c.estado),
          ]),
        );
      },
    );
  }
}

class _ConfirmacionesTable extends StatelessWidget {
  final List<Confirmacion> confirmaciones;
  const _ConfirmacionesTable({required this.confirmaciones});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Table(
        columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(3), 2: FlexColumnWidth(2), 3: FlexColumnWidth(2), 4: FlexColumnWidth(2)},
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppColors.surfaceVariant),
            children: ['Invitado', 'Graduando', 'Documento', 'Estado', 'Código QR']
                .map((h) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Text(h, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary))))
                .toList(),
          ),
          ...confirmaciones.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            return TableRow(
              decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAFBFC), border: const Border(bottom: BorderSide(color: AppColors.divider))),
              children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [UserAvatar(name: c.invitado, size: 30), const SizedBox(width: 10), Text(c.invitado, style: AppTextStyles.body)])),
                _cell(c.graduandoNombre), _cell(c.documento),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: StatusBadge.fromEstadoConfirmacion(c.estado)),
                _cell(c.codigoQr ?? '—'),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _cell(String text) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text(text, style: AppTextStyles.body));
}

class _ConfirmMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _ConfirmMetric({required this.label, required this.value, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: AppTextStyles.caption),
          ]),
        ]),
      ),
    );
  }
}