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
    final isMobile = MediaQuery.of(context).size.width < 600;

    final graduandosPorFacultad = <String, int>{};
    for (final g in provider.graduandos) {
      graduandosPorFacultad[g.facultad] =
          (graduandosPorFacultad[g.facultad] ?? 0) + 1;
    }

    final confirmados = provider.confirmaciones
        .where((c) => c.estado.name == 'confirmado').length;
    final rechazados = provider.confirmaciones
        .where((c) => c.estado.name == 'rechazado').length;
    final pendientes = provider.invitaciones
        .where((i) => i.estado.name == 'pendiente' || i.estado.name == 'enviada').length;

    final estadoConfirmaciones = {
      'Confirmados': confirmados,
      'Pendientes': pendientes,
      'Rechazados': rechazados,
    };

    final aforoConfirmados = provider.confirmaciones
        .where((c) => c.estado.name == 'confirmado').length;
    final aforoPendientes = provider.confirmaciones
        .where((c) => c.estado.name == 'pendiente').length;
    final aforoRechazados = provider.confirmaciones
        .where((c) => c.estado.name == 'rechazado').length;

    final estadoAforo = {
      'Confirmados': aforoConfirmados,
      'Pendientes': aforoPendientes,
      'Rechazados': aforoRechazados,
    };

    final directivosConfirmados = provider.directivos
        .where((d) => d.estado.name == 'confirmado').length;
    final directivosPendientes = provider.directivos
        .where((d) => d.estado.name == 'pendiente').length;
    final directivosRechazados = provider.directivos
        .where((d) => d.estado.name == 'rechazado').length;

    final estadoDirectivos = {
      'Confirmados': directivosConfirmados,
      'Pendientes': directivosPendientes,
      'Rechazados': directivosRechazados,
    };

    final padding = isMobile ? 16.0 : 28.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text('Dashboard', style: AppTextStyles.h1),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  DateFormat("d 'de' MMMM, yyyy", 'es_CO').format(DateTime.now()),
                  style: AppTextStyles.label,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: AppColors.success, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    const Text('Sistema activo',
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Metric Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: isMobile ? 10 : 16,
            mainAxisSpacing: isMobile ? 10 : 16,
            childAspectRatio: isMobile ? 1.1 : 1.3,
            children: [
              MetricCard(
                title: 'Graduandos',
                value: provider.totalGraduandos.toString(),
                icon: Icons.school_rounded,
                color: AppColors.primaryLight,
              ),
              MetricCard(
                title: 'Invitaciones',
                value: provider.totalInvitaciones.toString(),
                icon: Icons.mail_rounded,
                color: AppColors.success,
              ),
              MetricCard(
                title: 'Aforo',
                value: provider.aforoDisponible.toString(),
                icon: Icons.event_seat_rounded,
                color: AppColors.warning,
              ),
              MetricCard(
                title: 'Directivos',
                value: provider.totalDirectivos.toString(),
                icon: Icons.person_outline_rounded,
                color: AppColors.pending,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Charts — en móvil apilados, en tablet lado a lado
          if (isMobile) ...[
            _chartCard(
              title: 'Estado de Confirmaciones',
              subtitle: confirmados + rechazados + pendientes > 0
                  ? '${(confirmados / (confirmados + rechazados + pendientes) * 100).round()}% confirmados'
                  : 'Sin datos aún',
              child: confirmados + rechazados + pendientes == 0
                  ? const Center(child: Text('Sin confirmaciones aún', style: AppTextStyles.bodySmall))
                  : _ConfirmacionDonutChart(data: estadoConfirmaciones),
            ),
            const SizedBox(height: 16),
            _chartCard(
              title: 'Control de Aforo (QR)',
              subtitle: aforoConfirmados + aforoRechazados + aforoPendientes > 0
                  ? '${(aforoConfirmados / (aforoConfirmados + aforoRechazados + aforoPendientes) * 100).round()}% confirmados'
                  : 'Sin datos aún',
              child: aforoConfirmados + aforoRechazados + aforoPendientes == 0
                  ? const Center(child: Text('Sin registros de aforo', style: AppTextStyles.bodySmall))
                  : _AforoDonutChart(data: estadoAforo),
            ),
            const SizedBox(height: 16),
            _chartCard(
              title: 'Confirmación de Directivos',
              subtitle: directivosConfirmados + directivosRechazados + directivosPendientes > 0
                  ? '${(directivosConfirmados / (directivosConfirmados + directivosRechazados + directivosPendientes) * 100).round()}% confirmados'
                  : 'Sin datos aún',
              child: directivosConfirmados + directivosRechazados + directivosPendientes == 0
                  ? const Center(child: Text('Sin registros de directivos', style: AppTextStyles.bodySmall))
                  : _DirectivosDonutChart(data: estadoDirectivos),
            ),
          ] else ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Graduandos por Facultad', style: AppTextStyles.h4),
                            const SizedBox(height: 4),
                            const Text('Distribución por facultad académica', style: AppTextStyles.bodySmall),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 200,
                              child: graduandosPorFacultad.isEmpty
                                  ? const Center(child: Text('Sin datos aún', style: AppTextStyles.bodySmall))
                                  : _FacultadBarChart(data: graduandosPorFacultad),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _chartCard(
                      title: 'Estado de Confirmaciones',
                      subtitle: confirmados + rechazados + pendientes > 0
                          ? '${(confirmados / (confirmados + rechazados + pendientes) * 100).round()}% confirmados'
                          : 'Sin datos aún',
                      child: confirmados + rechazados + pendientes == 0
                          ? const Center(child: Text('Sin confirmaciones aún', style: AppTextStyles.bodySmall))
                          : _ConfirmacionDonutChart(data: estadoConfirmaciones),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 4,
                    child: _chartCard(
                      title: 'Control de Aforo (QR)',
                      subtitle: aforoConfirmados + aforoRechazados + aforoPendientes > 0
                          ? '${(aforoConfirmados / (aforoConfirmados + aforoRechazados + aforoPendientes) * 100).round()}% confirmados'
                          : 'Sin datos aún',
                      child: aforoConfirmados + aforoRechazados + aforoPendientes == 0
                          ? const Center(child: Text('Sin registros de aforo', style: AppTextStyles.bodySmall))
                          : _AforoDonutChart(data: estadoAforo),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _chartCard(
                      title: 'Confirmación de Directivos',
                      subtitle: directivosConfirmados + directivosRechazados + directivosPendientes > 0
                          ? '${(directivosConfirmados / (directivosConfirmados + directivosRechazados + directivosPendientes) * 100).round()}% confirmados'
                          : 'Sin datos aún',
                      child: directivosConfirmados + directivosRechazados + directivosPendientes == 0
                          ? const Center(child: Text('Sin registros de directivos', style: AppTextStyles.bodySmall))
                          : _DirectivosDonutChart(data: estadoDirectivos),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Actividades recientes
          Card(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Últimas Actividades', style: AppTextStyles.h4),
                      const Spacer(),
                      TextButton(onPressed: () {}, child: const Text('Ver todas')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  provider.actividades.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Sin actividad reciente', style: AppTextStyles.bodySmall),
                          ))
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

  Widget _chartCard({required String title, required String subtitle, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.h4),
            const SizedBox(height: 4),
            Text(subtitle, style: AppTextStyles.bodySmall),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: child),
          ],
        ),
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
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= entries.length) return const SizedBox.shrink();
                final label = entries[index].key;
                final shortLabel = label.contains('Salud') ? 'C. Salud'
                    : label.contains('Económ') ? 'C. Econ.'
                    : label.contains('Ingen') ? 'Ing.'
                    : label.substring(0, label.length > 8 ? 8 : label.length);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(shortLabel, style: AppTextStyles.caption, textAlign: TextAlign.center),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) =>
                  Text(value.toInt().toString(), style: AppTextStyles.caption),
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
          final colors = [AppColors.primaryLight, AppColors.success, AppColors.warning, AppColors.error, AppColors.pending];
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: entries[i].value.toDouble(),
                color: colors[i % colors.length],
                width: 30,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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
  State<_ConfirmacionDonutChart> createState() => _ConfirmacionDonutChartState();
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
          child: PieChart(PieChartData(
            pieTouchData: PieTouchData(touchCallback: (event, res) {
              setState(() {
                _touchedIndex = (!event.isInterestedForInteractions || res == null || res.touchedSection == null)
                    ? -1 : res.touchedSection!.touchedSectionIndex;
              });
            }),
            sections: List.generate(entries.length, (i) => PieChartSectionData(
              color: colors[i],
              value: entries[i].value.toDouble(),
              title: total > 0 ? '${(entries[i].value / total * 100).round()}%' : '0%',
              radius: i == _touchedIndex ? 80 : 70,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            )),
            centerSpaceRadius: 40,
            sectionsSpace: 2,
          )),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(entries.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entries[i].key, style: AppTextStyles.caption),
                Text(entries[i].value.toString(), style: AppTextStyles.h4.copyWith(fontSize: 14)),
              ]),
            ]),
          )),
        ),
      ],
    );
  }
}

class _AforoDonutChart extends StatefulWidget {
  final Map<String, int> data;
  const _AforoDonutChart({required this.data});
  @override
  State<_AforoDonutChart> createState() => _AforoDonutChartState();
}

class _AforoDonutChartState extends State<_AforoDonutChart> {
  int _touchedIndex = -1;
  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries.toList();
    final total = widget.data.values.reduce((a, b) => a + b);
    final colors = [AppColors.success, AppColors.warning, AppColors.error];
    return Row(
      children: [
        Expanded(
          child: PieChart(PieChartData(
            pieTouchData: PieTouchData(touchCallback: (event, res) {
              setState(() {
                _touchedIndex = (!event.isInterestedForInteractions || res == null || res.touchedSection == null)
                    ? -1 : res.touchedSection!.touchedSectionIndex;
              });
            }),
            sections: List.generate(entries.length, (i) => PieChartSectionData(
              color: colors[i],
              value: entries[i].value.toDouble(),
              title: total > 0 ? '${(entries[i].value / total * 100).round()}%' : '0%',
              radius: i == _touchedIndex ? 80 : 70,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            )),
            centerSpaceRadius: 40,
            sectionsSpace: 2,
          )),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(entries.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entries[i].key, style: AppTextStyles.caption),
                Text(entries[i].value.toString(), style: AppTextStyles.h4.copyWith(fontSize: 14)),
              ]),
            ]),
          )),
        ),
      ],
    );
  }
}

class _DirectivosDonutChart extends StatefulWidget {
  final Map<String, int> data;
  const _DirectivosDonutChart({required this.data});
  @override
  State<_DirectivosDonutChart> createState() => _DirectivosDonutChartState();
}

class _DirectivosDonutChartState extends State<_DirectivosDonutChart> {
  int _touchedIndex = -1;
  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries.toList();
    final total = widget.data.values.reduce((a, b) => a + b);
    final colors = [AppColors.success, AppColors.warning, AppColors.error];
    return Row(
      children: [
        Expanded(
          child: PieChart(PieChartData(
            pieTouchData: PieTouchData(touchCallback: (event, res) {
              setState(() {
                _touchedIndex = (!event.isInterestedForInteractions || res == null || res.touchedSection == null)
                    ? -1 : res.touchedSection!.touchedSectionIndex;
              });
            }),
            sections: List.generate(entries.length, (i) => PieChartSectionData(
              color: colors[i],
              value: entries[i].value.toDouble(),
              title: total > 0 ? '${(entries[i].value / total * 100).round()}%' : '0%',
              radius: i == _touchedIndex ? 80 : 70,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
            )),
            centerSpaceRadius: 40,
            sectionsSpace: 2,
          )),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(entries.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entries[i].key, style: AppTextStyles.caption),
                Text(entries[i].value.toString(), style: AppTextStyles.h4.copyWith(fontSize: 14)),
              ]),
            ]),
          )),
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
    final horaStr = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
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