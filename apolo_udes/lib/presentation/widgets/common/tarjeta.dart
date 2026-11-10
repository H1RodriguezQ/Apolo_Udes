import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Tarjeta blanca con borde fino, como en el diseño. Si lleva `titulo`, se
/// dibuja una cabecera con el título a la izquierda y `accion` a la derecha.
class Tarjeta extends StatelessWidget {
  final String? titulo;
  final Widget? accion;
  final Widget child;
  final EdgeInsets padding;
  final bool lineaBajoTitulo;

  const Tarjeta({
    super.key,
    this.titulo,
    this.accion,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 22),
    this.lineaBajoTitulo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (titulo != null) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, lineaBajoTitulo ? 16 : 0),
              child: Row(
                children: [
                  Expanded(child: Text(titulo!, style: AppTextStyles.h4.copyWith(fontSize: 16))),
                  if (accion != null) accion!,
                ],
              ),
            ),
            if (lineaBajoTitulo) Divider(height: 1, color: AppColors.border),
          ],
          Padding(
            padding: titulo != null && !lineaBajoTitulo
                ? padding.copyWith(top: 14)
                : padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Etiqueta pequeña sobre un dato (por ejemplo "Lugar" sobre la dirección).
class DatoEtiquetado extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String? nota;
  final bool mono;
  const DatoEtiquetado({super.key, required this.etiqueta, required this.valor, this.nota, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: AppTextStyles.label),
        const SizedBox(height: 6),
        Text(
          valor,
          style: mono
              ? AppTextStyles.mono(size: 16, peso: FontWeight.w500)
              : AppTextStyles.h4.copyWith(fontSize: 16),
        ),
        if (nota != null) ...[
          const SizedBox(height: 2),
          Text(nota!, style: AppTextStyles.label),
        ],
      ],
    );
  }
}

/// Fila de "avance": nombre, barra, "x / y" y el porcentaje.
class BarraAvance extends StatelessWidget {
  final String nombre;
  final int valor;
  final int total;
  const BarraAvance({super.key, required this.nombre, required this.valor, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraccion = total == 0 ? 0.0 : (valor / total).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, caja) {
      final barra = ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: fraccion,
          minHeight: 10,
          backgroundColor: AppColors.pista,
          color: AppColors.boton,
        ),
      );
      // Angosto (celular): el nombre y los números arriba, la barra completa abajo.
      if (caja.maxWidth < 480) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(nombre, style: AppTextStyles.body.copyWith(fontSize: 15))),
                  Text('$valor / $total · ${(fraccion * 100).round()} %', style: AppTextStyles.mono(size: 14)),
                ],
              ),
              const SizedBox(height: 6),
              barra,
            ],
          ),
        );
      }
      return _fila(fraccion);
    });
  }

  Widget _fila(double fraccion) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 230, child: Text(nombre, style: AppTextStyles.body.copyWith(fontSize: 15))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraccion,
                minHeight: 10,
                backgroundColor: AppColors.pista,
                color: AppColors.boton,
              ),
            ),
          ),
          // "3 / 7" y debajo el porcentaje, para que se lea rápido cuánto falta.
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$valor / $total', style: AppTextStyles.mono(size: 15)),
                Text('${(fraccion * 100).round()} %',
                    style: AppTextStyles.mono(size: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
