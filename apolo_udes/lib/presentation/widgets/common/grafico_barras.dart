import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Gráfico de barras sencillo hecho con contenedores de Flutter.
///
/// Se hizo a mano (en vez de usar fl_chart) para que cada barra muestre su
/// número encima y se entienda sin tener que leer el eje. Cada barra puede
/// tener varias partes apiladas (por ejemplo, una por entrada del auditorio).
///
/// - [valores]: una lista por barra; cada lista tiene un número por serie.
/// - [etiquetas]: el texto debajo de cada barra.
/// - [colores]: un color por serie.
/// - [detalle]: texto opcional que sale al pasar el mouse o dejar el dedo
///   sobre la barra.
class GraficoBarras extends StatelessWidget {
  final List<List<int>> valores;
  final List<String> etiquetas;
  final List<Color> colores;
  final double alto;
  final String textoVacio;
  final String Function(int i)? detalle;

  /// Resalta una barra (por ejemplo la de "hoy").
  final int? resaltada;

  const GraficoBarras({
    super.key,
    required this.valores,
    required this.etiquetas,
    required this.colores,
    this.alto = 160,
    this.textoVacio = 'Sin datos.',
    this.detalle,
    this.resaltada,
  });

  @override
  Widget build(BuildContext context) {
    final totales = [for (final v in valores) v.fold<int>(0, (a, b) => a + b)];
    final maximo = totales.fold<int>(0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: alto + 44, // espacio para el número de arriba y la etiqueta de abajo
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < valores.length; i++)
                Expanded(child: _barra(i, totales[i], maximo)),
            ],
          ),
          // Si todo está en cero, se dice con palabras en vez de dejar el gráfico vacío.
          if (maximo == 0)
            Positioned.fill(
              bottom: 24,
              child: Center(child: Text(textoVacio, style: AppTextStyles.label)),
            ),
        ],
      ),
    );
  }

  Widget _barra(int i, int total, int maximo) {
    // La barra más alta ocupa todo el alto; las demás, en proporción.
    final altoBarra = maximo == 0 ? 0.0 : alto * total / maximo;
    final esResaltada = resaltada == i;

    final columna = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Número encima de la barra (si es cero no se pone, para no llenar de ceros).
          SizedBox(
            height: 20,
            child: total > 0
                ? Text('$total', style: AppTextStyles.mono(size: 13, peso: FontWeight.w600))
                : null,
          ),
          // Partes apiladas: la primera serie abajo.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var s = valores[i].length - 1; s >= 0; s--)
                  if (valores[i][s] > 0)
                    Container(
                      height: total == 0 ? 0 : altoBarra * valores[i][s] / total,
                      color: colores[s % colores.length],
                    ),
              ],
            ),
          ),
          // Línea de base.
          Container(height: 1, color: AppColors.borderFuerte),
          SizedBox(
            height: 23,
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                etiquetas[i],
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: AppTextStyles.mono(
                  size: 11,
                  peso: esResaltada ? FontWeight.w600 : FontWeight.w400,
                  color: esResaltada ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (detalle == null) return columna;
    return Tooltip(message: detalle!(i), child: columna);
  }
}

/// Cuadrito de color con su nombre, para explicar qué es cada color.
class Leyenda extends StatelessWidget {
  final Color color;
  final String texto;
  const Leyenda({super.key, required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 6),
        Text(texto, style: AppTextStyles.bodySmall),
      ],
    );
  }
}
