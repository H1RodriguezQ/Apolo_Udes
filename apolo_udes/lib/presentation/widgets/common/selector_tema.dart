import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/theme_provider.dart';
import 'apolo_ui.dart';

/// Selector de tres opciones para la pantalla de Configuración.
class SelectorTema extends StatelessWidget {
  const SelectorTema({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<ThemeProvider>();
    return Row(
      children: [
        Expanded(child: Text('Solo cambia en este dispositivo', style: AppTextStyles.bodySmall)),
        FiltroSegmentado<ThemeMode>(
          valor: tema.modo,
          onChanged: tema.cambiar,
          opciones: const [
            (ThemeMode.light, 'Claro', null),
            (ThemeMode.dark, 'Oscuro', null),
            (ThemeMode.system, 'Igual que el sistema', null),
          ],
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