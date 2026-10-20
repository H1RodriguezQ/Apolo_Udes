import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../bitacora/bitacora_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

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

    // Ocupación del Aforo
    final totalGraduandos = provider.graduandos.length;
    final totalInvitados = provider.invitaciones.length;
    final totalDirectivos = provider.directivos
        .where((d) => d.estado.name == 'confirmado').length;
    final aforoTotal = provider.aforoDisponible;
    final ocupado = totalGraduandos + totalInvitados + totalDirectivos;
    final disponible = (aforoTotal - ocupado).clamp(0, aforoTotal);

    final ocupacionAforo = {
      'Graduandos': totalGraduandos,
      'Invitados': totalInvitados,
      'Directivos': totalDirectivos,
      'Disponible': disponible,
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
          Text('Dashboard', style: AppTextStyles.h1),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                DateFormat("d 'de' MMMM, yyyy", 'es_CO').format(DateTime.now()),
                style: AppTextStyles.label,
              ),
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

          LayoutBuilder(
            builder: (context, constraints) {
              final columns = screenWidth < 850 ? 2 : 4;
              final spacing = isMobile ? 10.0 : 16.0;
              final itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;
              const targetHeight = 145.0;
              final computedAspectRatio = itemWidth / targetHeight;

              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: computedAspectRatio,
                children: [
                  _LocalMetricCard(
                    title: 'Graduandos',
                    value: provider.totalGraduandos.toString(),
                    icon: Icons.school_rounded,
                    color: AppColors.primaryLight,
                  ),
                  _LocalMetricCard(
                    title: 'Invitaciones',
                    value: provider.totalInvitaciones.toString(),
                    icon: Icons.mail_rounded,
                    color: AppColors.success,
                  ),
                  _LocalMetricCard(
                    title: 'Aforo',
                    value: provider.aforoDisponible.toString(),
                    icon: Icons.event_seat_rounded,
                    color: AppColors.warning,
                  ),
                  _LocalMetricCard(
                    title: 'Directivos',
                    value: provider.totalDirectivos.toString(),
                    icon: Icons.person_outline_rounded,
                    color: AppColors.pending,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          if (isMobile || isTablet) ...[
            _chartCard(
              title: 'Estado de Confirmaciones',
              subtitle: confirmados + rechazados + pendientes > 0
                  ? '${(confirmados / (confirmados + rechazados + pendientes) * 100).round()}% confirmados'
                  : 'Sin datos aún',
              child: confirmados + rechazados + pendientes == 0
                  ? Center(child: Text('Sin confirmaciones aún', style: AppTextStyles.bodySmall))
                  : _ConfirmacionDonutChart(data: estadoConfirmaciones),
            ),
            const SizedBox(height: 16),
            _chartCard(
              title: 'Ocupación del Aforo',
              subtitle: aforoTotal > 0
                  ? '$ocupado de $aforoTotal ocupados (${(ocupado / aforoTotal * 100).round()}%)'
                  : 'Sin aforo configurado',
              child: aforoTotal == 0
                  ? Center(child: Text('Configura el aforo en Configuración', style: AppTextStyles.bodySmall))
                  : _AforoOcupacionDonutChart(data: ocupacionAforo),
            ),
            const SizedBox(height: 16),
            _chartCard(
              title: 'Confirmación de Directivos',
              subtitle: directivosConfirmados + directivosRechazados + directivosPendientes > 0
                  ? '${(directivosConfirmados / (directivosConfirmados + directivosRechazados + directivosPendientes) * 100).round()}% confirmados'
                  : 'Sin datos aún',
              child: directivosConfirmados + directivosRechazados + directivosPendientes == 0
                  ? Center(child: Text('Sin registros de directivos', style: AppTextStyles.bodySmall))
                  : _DirectivosDonutChart(data: estadoDirectivos),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Graduandos por Facultad', style: AppTextStyles.h4),
                    const SizedBox(height: 4),
                    Text('Distribución por facultad académica', style: AppTextStyles.bodySmall),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: graduandosPorFacultad.isEmpty
                          ? Center(child: Text('Sin datos aún', style: AppTextStyles.bodySmall))
                          : _FacultadBarChart(data: graduandosPorFacultad),
                    ),
                  ],
                ),
              ),
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
                            Text('Graduandos por Facultad', style: AppTextStyles.h4),
                            const SizedBox(height: 4),
                            Text('Distribución por facultad académica', style: AppTextStyles.bodySmall),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 200,
                              child: graduandosPorFacultad.isEmpty
                                  ? Center(child: Text('Sin datos aún', style: AppTextStyles.bodySmall))
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
                          ? Center(child: Text('Sin confirmaciones aún', style: AppTextStyles.bodySmall))
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
                      title: 'Ocupación del Aforo',
                      subtitle: aforoTotal > 0
                          ? '$ocupado de $aforoTotal (${(ocupado / aforoTotal * 100).round()}%)'
                          : 'Sin aforo configurado',
                      child: aforoTotal == 0
                          ? Center(child: Text('Configura el aforo en Configuración', style: AppTextStyles.bodySmall))
                          : _AforoOcupacionDonutChart(data: ocupacionAforo),
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
                          ? Center(child: Text('Sin registros de directivos', style: AppTextStyles.bodySmall))
                          : _DirectivosDonutChart(data: estadoDirectivos),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          _ActividadCard(
            isAdmin: provider.isAdmin,
            actividades: provider.actividades,
            isMobile: isMobile,
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
            SizedBox(height: 220, child: child),
          ],
        ),
      ),
    );
  }
}

// ── Actividad: bitácora (admin) o sesión actual (operador) ──

class _ActividadCard extends StatefulWidget {
  final bool isAdmin;
  final List<ActividadReciente> actividades;
  final bool isMobile;
  const _ActividadCard({
    required this.isAdmin,
    required this.actividades,
    required this.isMobile,
  });

  @override
  State<_ActividadCard> createState() => _ActividadCardState();
}

class _ActividadCardState extends State<_ActividadCard> {
  Stream<List<BitacoraEntrada>>? _stream;

  @override
  void initState() {
    super.initState();
    // El stream se crea una sola vez: si se creara en build(), cada
    // actualizacion del dashboard abriria una nueva conexion.
    if (widget.isAdmin) _stream = streamBitacora(limite: 6);
  }

  void _abrirBitacora() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Bitácora'),
          backgroundColor: AppColors.sidebarBg,
          foregroundColor: Colors.white,
        ),
        body: const BitacoraScreen(),
      ),
    ));
  }

  Widget _vacio(String texto) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(texto, style: AppTextStyles.bodySmall),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isAdmin ? 'Bitácora reciente' : 'Actividad de esta sesión',
                    style: AppTextStyles.h4,
                  ),
                ),
                if (widget.isAdmin)
                  TextButton.icon(
                    onPressed: _abrirBitacora,
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('Ver bitácora completa'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 8),
            if (widget.isAdmin)
              StreamBuilder<List<BitacoraEntrada>>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return _vacio('No fue posible cargar la bitácora');
                  }
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final lista = snap.data!;
                  if (lista.isEmpty) return _vacio('Sin registros todavía');
                  return Column(
                    children: lista.map((e) => BitacoraRow(entrada: e)).toList(),
                  );
                },
              )
            else if (widget.actividades.isEmpty)
              _vacio('Sin actividad reciente')
            else
              Column(
                children: widget.actividades
                    .take(5)
                    .map((a) => _ActividadRow(actividad: a))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _LocalMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _LocalMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surface, // antes: Colors.white fijo
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AforoOcupacionDonutChart extends StatefulWidget {
  final Map<String, int> data;
  const _AforoOcupacionDonutChart({required this.data});

  @override
  State<_AforoOcupacionDonutChart> createState() =>
      _AforoOcupacionDonutChartState();
}

class _AforoOcupacionDonutChartState extends State<_AforoOcupacionDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries.toList();
    final total = widget.data.values.reduce((a, b) => a + b);

    final colors = [
      const Color(0xFF3B82F6), // Graduandos
      const Color(0xFF10B981), // Invitados
      const Color(0xFF8B5CF6), // Directivos
      // Disponible: gris más oscuro en modo oscuro para que no deslumbre
      AppColors.isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
    ];

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(PieChartData(
            pieTouchData: PieTouchData(touchCallback: (event, res) {
              setState(() {
                _touchedIndex =
                    (!event.isInterestedForInteractions || res == null || res.touchedSection == null)
                        ? -1
                        : res.touchedSection!.touchedSectionIndex;
              });
            }),
            sections: List.generate(entries.length, (i) {
              final isTouched = i == _touchedIndex;
              final percentage = total > 0 ? (entries[i].value / total * 100) : 0;
              return PieChartSectionData(
                color: colors[i],
                value: entries[i].value.toDouble(),
                title: percentage >= 5 ? '${percentage.round()}%' : '',
                radius: isTouched ? 70 : 60,
                titleStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: i == 3 ? AppColors.textSecondary : Colors.white,
                ),
              );
            }),
            centerSpaceRadius: 35,
            sectionsSpace: 2,
          )),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(entries.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entries[i].key,
                            style: AppTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(entries[i].value.toString(),
                            style: AppTextStyles.h4.copyWith(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ),
        ),
      ],
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
              FlLine(color: AppColors.divider, strokeWidth: 1),
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
              radius: i == _touchedIndex ? 70 : 60,
              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            )),
            centerSpaceRadius: 35,
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
              radius: i == _touchedIndex ? 70 : 60,
              titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            )),
            centerSpaceRadius: 35,
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
  final ActividadReciente actividad;
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
    final hora = actividad.hora;
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
                Text(actividad.detalle, style: AppTextStyles.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(actividad.usuario, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(horaStr, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}