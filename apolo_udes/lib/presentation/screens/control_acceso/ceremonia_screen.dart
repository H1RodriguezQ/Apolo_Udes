import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../navegacion.dart';
import '../../widgets/common/apolo_ui.dart';
import '../../widgets/common/tarjeta.dart';

/// "Ceremonia en curso" (rediseño): lo que el administrador mira el día del
/// grado mientras la gente entra. Todo sale de las lecturas de hoy que las
/// tablets guardan en `validaciones`.
class CeremoniaScreen extends StatelessWidget {
  const CeremoniaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final lecturas = provider.lecturasDelDia;
    final validas = lecturas.where((l) => l.valida).toList();
    final rechazadas = lecturas.where((l) => !l.valida).toList();
    final aforo = provider.aforoDisponible;
    final ocupacion = aforo == 0 ? 0.0 : validas.length / aforo;

    // Ritmo de los últimos 10 minutos, total y por entrada.
    final hace10 = DateTime.now().subtract(const Duration(minutes: 10));
    final recientes = validas.where((l) => l.hora.isAfter(hace10)).toList();
    final puntos = {for (final l in validas) l.punto}.toList()..sort();
    final ritmo = recientes.length / 10;

    // Directivos: los códigos de directivo empiezan por "DIR-".
    final directivosConfirmados = provider.directivosConfirmados;
    final directivosAdentro = validas.where((l) => l.codigo.startsWith('DIR-')).length;

    final alerta = ocupacion >= 0.9
        ? ('Auditorio casi lleno', 'Se llegó al ${(ocupacion * 100).round()} % de las sillas.', TonoEtiqueta.error)
        : ocupacion >= 0.75
            ? ('Atención', 'El auditorio pasó el 75 % de ocupación.', TonoEtiqueta.aviso)
            : ('Sin alertas', 'El auditorio está por debajo del 75 %.', TonoEtiqueta.ok);

    final ancho = MediaQuery.sizeOf(context).width;

    return PantallaApolo(
      desplazable: true,
      encabezado: EncabezadoPantalla(
        titulo: 'Ceremonia en curso',
        segundaLinea: 'Hoy, ${DateFormat("d 'de' MMMM", 'es_CO').format(DateTime.now())} · ${lecturas.length} lecturas en total',
        mostrarConexion: true,
        acciones: [
          ElevatedButton.icon(
            onPressed: () => provider.setSelectedIndex(Nav.lector),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('Abrir lector'),
          ),
        ],
      ),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Aviso(titulo: alerta.$1, texto: alerta.$2, tono: alerta.$3),
          const SizedBox(height: 20),
          Flex(
            direction: ancho < 1000 ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _celda(ancho, _TarjetaOcupacion(adentro: validas.length, aforo: aforo)),
              const SizedBox(width: 20, height: 20),
              _celda(
                ancho,
                Tarjeta(
                  titulo: 'Ritmo de ingreso (últimos 10 min)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(ritmo.toStringAsFixed(1), style: AppTextStyles.mono(size: 32, peso: FontWeight.w500)),
                          const SizedBox(width: 10),
                          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('personas por minuto', style: AppTextStyles.label.copyWith(fontSize: 14))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 16,
                        children: [
                          for (final p in puntos)
                            Text('$p: ${(recientes.where((l) => l.punto == p).length / 10).toStringAsFixed(1)}/min',
                                style: AppTextStyles.mono(size: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20, height: 20),
              _celda(
                ancho,
                Tarjeta(
                  titulo: 'Directivos para la mesa principal',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$directivosAdentro', style: AppTextStyles.mono(size: 32, peso: FontWeight.w500)),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('de $directivosConfirmados confirmados han ingresado',
                                style: AppTextStyles.label.copyWith(fontSize: 14)),
                          ),
                        ],
                      ),
                      TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => provider.setSelectedIndex(Nav.directivos),
                        child: const Text('Ver directivos', style: TextStyle(decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Flex(
            direction: ancho < 1000 ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: ancho < 1000 ? 0 : 3, child: _TarjetaIngresos(validas: validas, puntos: puntos)),
              const SizedBox(width: 20, height: 20),
              Expanded(flex: ancho < 1000 ? 0 : 2, child: _TarjetaRechazadas(rechazadas: rechazadas)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _celda(double ancho, Widget hijo) => ancho < 1000 ? hijo : Expanded(child: hijo);
}

class _Aviso extends StatelessWidget {
  final String titulo;
  final String texto;
  final TonoEtiqueta tono;
  const _Aviso({required this.titulo, required this.texto, required this.tono});

  @override
  Widget build(BuildContext context) {
    final (fondo, color, icono) = switch (tono) {
      TonoEtiqueta.error => (AppColors.errorLight, AppColors.errorText, Icons.error_outline),
      TonoEtiqueta.aviso => (AppColors.warningLight, AppColors.warningText, Icons.warning_amber_rounded),
      _ => (AppColors.successLight, AppColors.successText, Icons.check_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 12),
          Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: TextStyle(color: color, fontSize: 14))),
        ],
      ),
    );
  }
}

class _TarjetaOcupacion extends StatelessWidget {
  final int adentro;
  final int aforo;
  const _TarjetaOcupacion({required this.adentro, required this.aforo});

  @override
  Widget build(BuildContext context) {
    final f = aforo == 0 ? 0.0 : (adentro / aforo).clamp(0.0, 1.0);
    final color = f >= 0.9 ? AppColors.error : f >= 0.75 ? AppColors.warning : AppColors.success;
    return Tarjeta(
      titulo: 'Ocupación del auditorio',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$adentro', style: AppTextStyles.mono(size: 32, peso: FontWeight.w500)),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Text('/  $aforo', style: AppTextStyles.mono(size: 16, color: AppColors.textSecondary)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${(f * 100).round()} %', style: AppTextStyles.mono(size: 15, peso: FontWeight.w500, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Barra con marcas en el 75 % (aviso) y el 90 % (tope).
          LayoutBuilder(builder: (context, c) {
            return SizedBox(
              height: 14,
              child: Stack(
                children: [
                  Positioned.fill(child: Container(color: AppColors.pista)),
                  Positioned(left: 0, top: 0, bottom: 0, width: c.maxWidth * f, child: Container(color: color)),
                  for (final m in [0.75, 0.9])
                    Positioned(left: c.maxWidth * m - 1, top: 0, bottom: 0, width: 2, child: Container(color: AppColors.errorText)),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Aviso al 75 % · tope al 90 %', style: AppTextStyles.bodySmall)),
              Text('${(aforo - adentro).clamp(0, aforo)} sillas libres', style: AppTextStyles.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ingresos válidos cada 5 minutos, una barra por entrada.
class _TarjetaIngresos extends StatelessWidget {
  final List<LecturaDia> validas;
  final List<String> puntos;
  const _TarjetaIngresos({required this.validas, required this.puntos});

  @override
  Widget build(BuildContext context) {
    final colores = [AppColors.isDark ? const Color(0xFF5F97E2) : AppColors.serie1, AppColors.serie2];
    if (validas.isEmpty) {
      return Tarjeta(
        titulo: 'Ingresos cada 5 minutos',
        child: SizedBox(height: 240, child: Center(child: Text('Todavía no ha entrado nadie hoy.', style: AppTextStyles.label))),
      );
    }
    DateTime bloque(DateTime h) => DateTime(h.year, h.month, h.day, h.hour, h.minute - h.minute % 5);
    final primero = bloque(validas.map((l) => l.hora).reduce((a, b) => a.isBefore(b) ? a : b));
    final ultimo = bloque(DateTime.now());
    final bloques = <DateTime>[];
    for (var t = primero; !t.isAfter(ultimo) && bloques.length < 24; t = t.add(const Duration(minutes: 5))) {
      bloques.add(t);
    }
    final conteo = {for (final p in puntos) p: List<int>.filled(bloques.length, 0)};
    for (final l in validas) {
      final i = bloques.indexOf(bloque(l.hora));
      if (i >= 0) conteo[l.punto]![i]++;
    }
    final maximo = conteo.values.expand((e) => e).fold<int>(1, (a, b) => a > b ? a : b);

    return Tarjeta(
      titulo: 'Ingresos cada 5 minutos',
      accion: Wrap(
        spacing: 14,
        children: [
          for (var k = 0; k < puntos.length; k++)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, color: colores[k % 2]),
              const SizedBox(width: 6),
              Text(puntos[k], style: AppTextStyles.bodySmall),
            ]),
        ],
      ),
      child: SizedBox(
        height: 240,
        child: BarChart(BarChartData(
          maxY: (maximo * 1.2).ceilToDouble(),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          gridData: FlGridData(drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppColors.divider, strokeWidth: 1)),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text('${v.toInt()}', style: AppTextStyles.mono(size: 11, color: AppColors.textSecondary)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i % 2 != 0 || i >= bloques.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(DateFormat('H:mm').format(bloques[i]), style: AppTextStyles.mono(size: 11, color: AppColors.textSecondary)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < bloques.length; i++)
              BarChartGroupData(x: i, barsSpace: 3, barRods: [
                for (var k = 0; k < puntos.length; k++)
                  BarChartRodData(toY: conteo[puntos[k]]![i].toDouble(), width: 10, color: colores[k % 2], borderRadius: BorderRadius.zero),
              ]),
          ],
        )),
      ),
    );
  }
}

class _TarjetaRechazadas extends StatelessWidget {
  final List<LecturaDia> rechazadas;
  const _TarjetaRechazadas({required this.rechazadas});

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      titulo: 'Lecturas rechazadas',
      accion: Text('${rechazadas.length} hoy', style: AppTextStyles.label),
      lineaBajoTitulo: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rechazadas.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text('Ninguna lectura rechazada hoy.', style: AppTextStyles.label)),
          for (final l in rechazadas.take(6))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
              child: Row(
                children: [
                  Text(DateFormat('HH:mm').format(l.hora), style: AppTextStyles.mono(size: 14)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CeldaTexto(l.nombre.isEmpty ? 'Sin identificar' : l.nombre,
                        debajo: '${l.punto} · ${l.operador}'),
                  ),
                  l.resultado == 'usado'
                      ? const Etiqueta('Ya usado', tono: TonoEtiqueta.aviso)
                      : const Etiqueta('No válido', tono: TonoEtiqueta.error),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
