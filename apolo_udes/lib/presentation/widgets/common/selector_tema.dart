import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/theme_provider.dart';

/// Selector de tres opciones para la pantalla de Configuración.
class SelectorTema extends StatelessWidget {
  const SelectorTema({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<ThemeProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Apariencia', style: AppTextStyles.h4),
        const SizedBox(height: 4),
        Text('Elige cómo se ve Apolo en este dispositivo',
            style: AppTextStyles.bodySmall),
        const SizedBox(height: 12),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Claro')),
            ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Oscuro')),
            ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_brightness_outlined),
                label: Text('Sistema')),
          ],
          selected: {tema.modo},
          onSelectionChanged: (s) => tema.cambiar(s.first),
        ),
      ],
    );
  }
}

/// Botón compacto para el pie del sidebar: rota entre los tres modos.
class BotonTema extends StatelessWidget {
  const BotonTema({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<ThemeProvider>();
    final (icono, texto) = switch (tema.modo) {
      ThemeMode.light => (Icons.light_mode_outlined, 'Tema claro'),
      ThemeMode.dark => (Icons.dark_mode_outlined, 'Tema oscuro'),
      ThemeMode.system => (Icons.settings_brightness_outlined, 'Tema del sistema'),
    };
    return IconButton(
      icon: Icon(icono, color: AppColors.sidebarText, size: 16),
      tooltip: '$texto (clic para cambiar)',
      onPressed: tema.siguiente,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}