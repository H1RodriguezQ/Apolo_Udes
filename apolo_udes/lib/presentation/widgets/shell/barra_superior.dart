import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/theme_provider.dart';

/// Marca que la pantalla se está mostrando dentro del armazón nuevo (menú
/// lateral + barra superior). Los encabezados de cada pantalla la consultan
/// para no repetir el título, que ya sale en la barra.
class EnShell extends InheritedWidget {
  const EnShell({super.key, required super.child});

  static bool de(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EnShell>() != null;

  @override
  bool updateShouldNotify(EnShell oldWidget) => false;
}

/// Barra blanca de 76 px con el título de la pantalla. A la derecha muestra
/// si la tablet está en línea y el botón para cambiar entre claro y oscuro.
class BarraSuperior extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  const BarraSuperior({super.key, required this.titulo, this.subtitulo});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final tema = context.watch<ThemeProvider>();
    final enLinea = provider.enLinea;

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: AppColors.header,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppTextStyles.h1, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitulo != null)
                  Text(subtitulo!, style: AppTextStyles.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Estado de la conexión: importante en la entrada, porque sin
          // internet la tablet valida con su copia local.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: enLinea ? AppColors.successLight : AppColors.warningLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enLinea ? AppColors.successText : AppColors.warningText,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  enLinea ? 'En línea' : 'Sin conexión',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: enLinea ? AppColors.successText : AppColors.warningText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 44)),
              onPressed: tema.siguiente,
              child: Tooltip(
                message: AppColors.isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
                child: Icon(
                  AppColors.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla con pestañas debajo de la barra (por ejemplo Invitaciones y
/// Confirmaciones). Cada pestaña es una pantalla que ya existía.
class PantallaConPestanas extends StatelessWidget {
  final List<(String, Widget)> pestanas;
  const PantallaConPestanas({super.key, required this.pestanas});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: pestanas.length,
      child: Column(
        children: [
          Container(
            color: AppColors.header,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              dividerColor: AppColors.border,
              labelStyle: const TextStyle(
                fontFamily: AppTextStyles.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: [for (final p in pestanas) Tab(text: p.$1)],
            ),
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final p in pestanas) p.$2],
            ),
          ),
        ],
      ),
    );
  }
}
