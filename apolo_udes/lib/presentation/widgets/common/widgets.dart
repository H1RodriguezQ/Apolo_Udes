import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';

// ---- Metric Card (Optimizado para pantallas estrechas) ----
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    // Detectamos si la pantalla es muy angosta (como un celular en modo vertical)
    final bool isSmallScreen = MediaQuery.of(context).size.width < 360;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 20), // Padding dinámico
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                if (subtitle != null)
                  Flexible( // Evita que un subtítulo largo rompa el Row
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Ajuste Responsivo para números muy grandes (FittedBox evita el overflow)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 28, // Bajado ligeramente de 30 para mejor ajuste
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title, 
              style: AppTextStyles.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // Si el título es largo, añade '...'
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Status Badge ----
class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  factory StatusBadge.fromEstadoGraduando(EstadoGraduando estado) {
    switch (estado) {
      case EstadoGraduando.activo:
        return StatusBadge(
          label: estado.label,
          backgroundColor: AppColors.successLight,
          textColor: AppColors.success,
        );
      case EstadoGraduando.pendiente:
        return StatusBadge(
          label: estado.label,
          backgroundColor: AppColors.warningLight,
          textColor: AppColors.warning,
        );
      case EstadoGraduando.inactivo:
        return StatusBadge(
          label: estado.label,
          backgroundColor: AppColors.errorLight,
          textColor: AppColors.error,
        );
    }
  }

  factory StatusBadge.fromEstadoInvitacion(EstadoInvitacion estado) {
    switch (estado) {
      case EstadoInvitacion.confirmada:
        return StatusBadge(
          label: estado.label,
          backgroundColor: AppColors.successLight,
          textColor: AppColors.success,
        );
      case EstadoInvitacion.pendiente:
        return StatusBadge(
          label: estado.label,
          backgroundColor: AppColors.warningLight,
          textColor: AppColors.warning,
        );
      case EstadoInvitacion.enviada:
        return StatusBadge(
          label: estado.label,
          backgroundColor: AppColors.infoLight,
          textColor: AppColors.info,
        );
      case EstadoInvitacion.rechazada:
        return StatusBadge(
          label: estado.label,
          backgroundColor: AppColors.errorLight,
          textColor: AppColors.error,
        );
    }
  }

  factory StatusBadge.fromEstadoConfirmacion(EstadoConfirmacion estado) {
    switch (estado) {
      case EstadoConfirmacion.confirmado:
        return StatusBadge(
          label: estado.label,
          backgroundColor: AppColors.successLight,
          textColor: AppColors.success,
        );
      case EstadoConfirmacion.pendiente:
        return StatusBadge(
          label: estado.label,
          backgroundColor: AppColors.warningLight,
          textColor: AppColors.warning,
        );
      case EstadoConfirmacion.rechazado:
        return StatusBadge(
          label: estado.label,
          backgroundColor: AppColors.errorLight,
          textColor: AppColors.error,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11, // Bajado sutilmente de 12 para pantallas pequeñas
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---- Section Header (Anti-desbordamiento en Celulares) ----
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    // Verificamos si la pantalla es de tamaño móvil
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    // Si es móvil y hay un botón de acción, envolvemos en una columna para que no se corte
    if (isMobile && action != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h2),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTextStyles.label),
          ],
          const SizedBox(height: 12),
          // El botón de acción se sitúa abajo ocupando el espacio necesario
          Align(
            alignment: Alignment.centerLeft,
            child: action!,
          ),
        ],
      );
    }

    // Diseño original optimizado con Flexible para Tablets/Web
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title, 
                style: AppTextStyles.h2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!, 
                  style: AppTextStyles.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 16),
          action!,
        ],
      ],
    );
  }
}

// ---- Empty State ----
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              title, 
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle, 
              style: AppTextStyles.label, 
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Avatar ----
class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    required this.name,
    this.size = 36,
    this.backgroundColor,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color get _bgColor {
    if (backgroundColor != null) return backgroundColor!;
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
    ];
    return colors[name.length % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ---- Confirm Dialog ----
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool isDangerous = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: AppTextStyles.h3),
      content: Text(content, style: AppTextStyles.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDangerous ? AppColors.error : AppColors.primaryLight,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}