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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Cambiamos a disposición vertical/cuadrícula 2x2 en pantallas menores a 850px 
    // para evitar que se aprieten las tarjetas en modo vertical de tablet
    final useCompactLayout = screenWidth < 850;

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

          useCompactLayout
              ? Column(children: [
                  Row(children: [
                    Expanded(child: _ConfirmMetric(label: 'Confirmados', value: '$confirmados', color: AppColors.success, icon: Icons.check_circle_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _ConfirmMetric(label: 'Pendientes', value: '$pendientes', color: AppColors.warning, icon: Icons.hourglass_empty_rounded)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _ConfirmMetric(label: 'Rechazados', value: '$rechazados', color: AppColors.error, icon: Icons.block_rounded)),
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
                  Expanded(child: _ConfirmMetric(label: 'Confirmados', value: '$confirmados', color: AppColors.success, icon: Icons.check_circle_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _ConfirmMetric(label: 'Pendientes', value: '$pendientes', color: AppColors.warning, icon: Icons.hourglass_empty_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _ConfirmMetric(label: 'Rechazados', value: '$rechazados', color: AppColors.error, icon: Icons.block_rounded)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primaryLight, AppColors.primary]), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$tasa%', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1)),
                          const Text(
                            'Tasa de\nconfirmación', 
                            style: TextStyle(color: Colors.white70, fontSize: 11), 
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
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
        
        final graduandoText = c.graduandoNombre.trim().isNotEmpty
            ? c.graduandoNombre
            : 'Sin graduando asignado';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
          child: Row(children: [
            UserAvatar(name: c.invitado, size: 38),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.invitado, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
              Text(
                graduandoText, 
                style: AppTextStyles.bodySmall.copyWith(
                  color: graduandoText == 'Sin graduando asignado' ? AppColors.textSecondary.withValues(alpha: 0.6) : AppColors.textSecondary,
                  fontStyle: graduandoText == 'Sin graduando asignado' ? FontStyle.italic : FontStyle.normal,
                ),
              ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 940, 
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Table(
              // SOLUCIÓN CLAVE: Centra verticalmente todos los componentes en la fila
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: const {
                0: FlexColumnWidth(2.5), 
                1: FlexColumnWidth(2.5), 
                2: FlexColumnWidth(1.8), 
                3: FlexColumnWidth(1.7), 
                4: FlexColumnWidth(3.5), 
              },
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
                  
                  final graduandoText = c.graduandoNombre.trim().isNotEmpty
                      ? c.graduandoNombre
                      : '—';

                  return TableRow(
                    decoration: BoxDecoration(color: i.isEven ? Colors.white : const Color(0xFFFAFBFC), border: const Border(bottom: BorderSide(color: AppColors.divider))),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
                        child: Row(
                          children: [
                            UserAvatar(name: c.invitado, size: 30), 
                            const SizedBox(width: 10), 
                            Expanded(child: Text(c.invitado, style: AppTextStyles.body, overflow: TextOverflow.ellipsis))
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          graduandoText, 
                          style: AppTextStyles.body.copyWith(
                            color: graduandoText == '—' ? AppColors.textSecondary.withValues(alpha: 0.5) : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _cell(c.documento),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: StatusBadge.fromEstadoConfirmacion(c.estado)),
                      _qrCell(c.codigoQr ?? '—'), 
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(String text) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text(text, style: AppTextStyles.body));

  Widget _qrCell(String text) {
    if (text == '—') return _cell(text);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Ajustado a 12 para perfecta simetría
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE9ECEF)),
          ),
          child: Text(
            text,
            maxLines: 1,
            style: const TextStyle(
              fontFamily: 'Courier', 
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF495057),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _ConfirmMetric({required this.label, required this.value, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
                Text(
                  label, 
                  style: AppTextStyles.caption, 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}