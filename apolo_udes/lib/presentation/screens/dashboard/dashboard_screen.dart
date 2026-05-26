import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // Graduandos por facultad desde el provider
    final graduandosPorFacultad = <String, int>{};
    for (final g in provider.graduandos) {
      graduandosPorFacultad[g.facultad] =
          (graduandosPorFacultad[g.facultad] ?? 0) + 1;
    }

    // Estado de confirmaciones desde el provider
    final confirmados = provider.confirmaciones
        .where((c) => c.estado.name == 'confirmado')
        .length;
    final rechazados = provider.confirmaciones
        .where((c) => c.estado.name == 'rechazado')
        .length;
    final pendientes = provider.invitaciones
        .where((i) => i.estado.name == 'pendiente' || i.estado.name == 'enviada')
        .length;

    final estadoConfirmaciones = {
      'Confirmados': confirmados,
      'Pendientes': pendientes,
      'Rechazados': rechazados,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dashboard', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        DateFormat('d \'de\' MMMM, yyyy', 'es_CO')
                            .format(DateTime.now()),
                        style: AppTextStyles.label,
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Sistema activo',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Metric Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              MetricCard(
                title: 'Graduandos',
                value: provider.totalGraduandos.toString(),
                icon: Icons.school_rounded,
                color: AppColors.primaryLight,
              ),
              MetricCard(
                title: 'Invitaciones Enviadas',
                value: provider.totalInvitaciones.toString(),
                icon: Icons.mail_rounded,
                color: AppColors.success,
              ),
              MetricCard(
                title: 'Aforo Disponible',
                value: provider.aforoDisponible.toString(),
                icon: Icons.event_seat_rounded,
                color: AppColors.warning,
              ),
              MetricCard(
                title: 'Confirmaciones',
                value: provider.totalConfirmaciones.toString(),
                icon: Icons.check_circle_rounded,
                color: AppColors.pending,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Charts row
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bar chart - Graduandos por Facultad
                Expanded(
                  flex: 6,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Graduandos por Facultad',
                              style: AppTextStyles.h4),
                          const SizedBox(height: 4),
                          const Text('Distribución por facultad académica',
                              style: AppTextStyles.bodySmall),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 200,
                            child: graduandosPorFacultad.isEmpty
                                ? const Center(
                                    child: Text('Sin datos aún',
                                        style: AppTextStyles.bodySmall))
                                : _FacultadBarChart(
                                    data: graduandosPorFacultad),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Donut chart - Confirmaciones
                Expanded(
                  flex: 4,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estado de Confirmaciones',
                              style: AppTextStyles.h4),
                          const SizedBox(height: 4),
                          Text(
                            confirmados + rechazados + pendientes > 0
                                ? '${(confirmados / (confirmados + rechazados + pendientes) * 100).round()}% confirmados'
                                : 'Sin datos aún',
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: confirmados + rechazados + pendientes == 0
                                ? const Center(
                                    child: Text('Sin confirmaciones aún',
                                        style: AppTextStyles.bodySmall))
                                : _ConfirmacionDonutChart(
                                    data: estadoConfirmaciones),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Recent Activity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Últimas Actividades',
                          style: AppTextStyles.h4),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Ver todas'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  provider.actividades.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Sin actividad reciente',
                                style: AppTextStyles.bodySmall),
                          ),
                        )
                      : Column(
                          children: provider.actividades
                              .take(5)
                              .map((a) => _ActividadRow(actividad: a))
                              .toList(),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FacultadBarChart extends StatelessWidget {
  final Map<String, int> data;
  const _FacultadBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final maxVal = data.values.reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.3,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${entries[group.x].key}\n${rod.toY.toInt()} graduandos',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) {
                  return const SizedBox.shrink();
                }
                final label = entries[index].key;
                final shortLabel = label.contains('Salud')
                    ? 'C. Salud'
                    : label.contains('Económ')
                        ? 'C. Económicas'
                        : label.contains('Ingen')
                            ? 'Ingenierías'
                            : label.substring(0, label.length > 10 ? 10 : label.length);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(shortLabel,
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString(),
                    style: AppTextStyles.caption);
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: AppColors.divider, strokeWidth: 1),
        ),
        barGroups: List.generate(entries.length, (i) {
          final colors = [
            AppColors.primaryLight,
            AppColors.success,
            AppColors.warning,
            AppColors.error,
            AppColors.pending,
          ];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value.toDouble(),
                color: colors[i % colors.length],
                width: 40,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _ConfirmacionDonutChart extends StatefulWidget {
  final Map<String, int> data;
  const _ConfirmacionDonutChart({required this.data});

  @override
  State<_ConfirmacionDonutChart> createState() =>
      _ConfirmacionDonutChartState();
}

class _ConfirmacionDonutChartState extends State<_ConfirmacionDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries.toList();
    final total = widget.data.values.reduce((a, b) => a + b);
    final colors = [AppColors.success, AppColors.warning, AppColors.error];

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = -1;
                      return;
                    }
                    _touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sections: List.generate(entries.length, (i) {
                final isTouched = i == _touchedIndex;
                return PieChartSectionData(
                  color: colors[i],
                  value: entries[i].value.toDouble(),
                  title: total > 0
                      ? '${(entries[i].value / total * 100).round()}%'
                      : '0%',
                  radius: isTouched ? 80 : 70,
                  titleStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                );
              }),
              centerSpaceRadius: 44,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(entries.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entries[i].key, style: AppTextStyles.caption),
                      Text(
                        entries[i].value.toString(),
                        style: AppTextStyles.h4.copyWith(fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ActividadRow extends StatelessWidget {
  final dynamic actividad;
  const _ActividadRow({required this.actividad});

  IconData get _icon {
    switch (actividad.tipo) {
      case 'email': return Icons.mail_rounded;
      case 'confirm': return Icons.check_circle_rounded;
      case 'user': return Icons.person_add_rounded;
      case 'qr': return Icons.qr_code_scanner_rounded;
      case 'notification': return Icons.notifications_rounded;
      default: return Icons.info_rounded;
    }
  }

  Color get _color {
    switch (actividad.tipo) {
      case 'email': return AppColors.info;
      case 'confirm': return AppColors.success;
      case 'user': return AppColors.primaryLight;
      case 'qr': return AppColors.warning;
      case 'notification': return AppColors.pending;
      default: return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hora = actividad.hora as DateTime;
    final horaStr =
        '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_icon, color: _color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(actividad.detalle, style: AppTextStyles.body),
                const SizedBox(height: 2),
                Text(actividad.usuario, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text(horaStr, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}