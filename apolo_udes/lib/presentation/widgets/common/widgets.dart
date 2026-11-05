import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../shell/barra_superior.dart';

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
    // Estilo del rediseño: etiqueta pequeña arriba, número grande en letra
    // de ancho fijo y el icono discreto a la derecha.
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: AppTextStyles.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppTextStyles.mono(size: 30, peso: FontWeight.w500)),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

// ---- Status Badge ----

/// Badge del estado del correo que envía el SERVIDOR (Apps Script), para
/// `graduandos.correoRegistro` y `directivos.correoInvitacion`.
///
/// - `null` → no se pinta nada: el documento es anterior a este campo y no
///   se sabe si el correo salió, mejor no mostrar "enviado" sin más.
/// - `pendiente` → ya quedó en cola, Apps Script lo manda cada 5 minutos.
/// - `enviado` / `error` → lo escribió el servidor tras intentarlo.
class EstadoCorreoBadge extends StatelessWidget {
  final String? estado;
  final String etiquetaCorta;

  const EstadoCorreoBadge({
    super.key,
    required this.estado,
    this.etiquetaCorta = '',
  });

  @override
  Widget build(BuildContext context) {
    switch (estado) {
      case 'enviado':
        return StatusBadge(
          label: etiquetaCorta.isEmpty ? 'Correo enviado' : etiquetaCorta,
          backgroundColor: AppColors.successLight,
          textColor: AppColors.success,
        );
      case 'error':
        return StatusBadge(
          label: etiquetaCorta.isEmpty ? 'Correo con error' : etiquetaCorta,
          backgroundColor: AppColors.errorLight,
          textColor: AppColors.error,
        );
      case 'pendiente':
        return StatusBadge(
          label: etiquetaCorta.isEmpty ? 'Correo en cola' : etiquetaCorta,
          backgroundColor: AppColors.warningLight,
          textColor: AppColors.warning,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
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
      // Gris: ya no es una invitación "viva", pero tampoco es un rechazo.
      case EstadoInvitacion.anulada:
        return StatusBadge(
          label: estado.label,
          backgroundColor: AppColors.surfaceVariant,
          textColor: AppColors.textSecondary,
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

  /// Con el rediseño, el texto de cada etiqueta usa el tono oscuro del mismo
  /// color (verde oscuro sobre verde claro, etc.), que se lee mejor que el
  /// color vivo de antes. Se traduce aquí para no tocar cada pantalla.
  Color get _textoLegible {
    if (textColor == AppColors.success) return AppColors.successText;
    if (textColor == AppColors.error) return AppColors.errorText;
    if (textColor == AppColors.warning) return AppColors.warningText;
    if (textColor == AppColors.info || textColor == AppColors.primaryLight) return AppColors.infoText;
    return textColor;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _textoLegible,
          fontSize: 12,
          fontWeight: FontWeight.w500,
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
    // Dentro del armazón nuevo el título ya sale en la barra superior: aquí
    // solo queda la descripción a la izquierda y los botones a la derecha.
    if (EnShell.de(context)) {
      return Row(
        children: [
          Expanded(
            child: subtitle == null
                ? const SizedBox.shrink()
                : Text(subtitle!, style: AppTextStyles.label, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          if (action != null) ...[const SizedBox(width: 16), action!],
        ],
      );
    }

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

  // Con el rediseño las iniciales van en un círculo azul suave en vez de
  // colores al azar: la lista se ve más ordenada y se lee mejor.
  Color get _bgColor => backgroundColor ?? AppColors.infoLight;

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
            color: backgroundColor == null ? AppColors.infoText : Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.w600,
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
