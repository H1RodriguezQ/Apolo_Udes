import 'package:flutter/material.dart';

/// Colores que cambian entre modo claro y oscuro.
class _Paleta {
  final Color primary;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color border;
  final Color divider;
  final Color successLight;
  final Color errorLight;
  final Color warningLight;
  final Color infoLight;
  final Color pendingLight;

  const _Paleta({
    required this.primary,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.border,
    required this.divider,
    required this.successLight,
    required this.errorLight,
    required this.warningLight,
    required this.infoLight,
    required this.pendingLight,
  });
}

const _claro = _Paleta(
  primary: Color(0xFF1A3A6B),
  background: Color(0xFFF0F4F8),
  surface: Color(0xFFFFFFFF),
  surfaceVariant: Color(0xFFE8EFF7),
  textPrimary: Color(0xFF1E293B),
  textSecondary: Color(0xFF64748B),
  textHint: Color(0xFF94A3B8),
  border: Color(0xFFE2E8F0),
  divider: Color(0xFFF1F5F9),
  successLight: Color(0xFFD1FAE5),
  errorLight: Color(0xFFFEE2E2),
  warningLight: Color(0xFFFEF3C7),
  infoLight: Color(0xFFDBEAFE),
  pendingLight: Color(0xFFEDE9FE),
);

const _oscuro = _Paleta(
  primary: Color(0xFF93B4F0),
  background: Color(0xFF0B1220),
  surface: Color(0xFF131C2E),
  surfaceVariant: Color(0xFF1B2640),
  textPrimary: Color(0xFFE2E8F0),
  textSecondary: Color(0xFF94A3B8),
  textHint: Color(0xFF64748B),
  border: Color(0xFF26324A),
  divider: Color(0xFF1C2740),
  successLight: Color(0xFF0F3B2E),
  errorLight: Color(0xFF4A1D1D),
  warningLight: Color(0xFF4A3510),
  infoLight: Color(0xFF172B54),
  pendingLight: Color(0xFF2E2352),
);

class AppColors {
  /// Lo actualiza main.dart según el modo elegido (claro/oscuro/sistema).
  static bool isDark = false;
  static _Paleta get _p => isDark ? _oscuro : _claro;

  // ── Cambian según el modo ──
  static Color get primary => _p.primary;
  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get surfaceVariant => _p.surfaceVariant;
  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get textHint => _p.textHint;
  static Color get border => _p.border;
  static Color get divider => _p.divider;
  static Color get successLight => _p.successLight;
  static Color get errorLight => _p.errorLight;
  static Color get warningLight => _p.warningLight;
  static Color get infoLight => _p.infoLight;
  static Color get pendingLight => _p.pendingLight;

  // ── Iguales en ambos modos ──
  static const Color primaryLight = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF0F2347);
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentLight = Color(0xFFFBBF24);

  static const Color sidebarBg = Color(0xFF0F2347);
  static const Color sidebarActive = Color(0xFF2563EB);
  static const Color sidebarText = Color(0xFFB8CCE8);
  static const Color sidebarTextActive = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color pending = Color(0xFF8B5CF6);

  static const Color textOnPrimary = Color(0xFFFFFFFF);
}

class AppTextStyles {
  static const String fontFamily = 'Roboto';

  static TextStyle get h1 => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get h2 => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get h3 => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get h4 => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get body => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySmall => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get label => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textHint,
        letterSpacing: 0.2,
      );
}

class AppTheme {
  static ThemeData get light => _build(_claro, Brightness.light);
  static ThemeData get dark => _build(_oscuro, Brightness.dark);

  static ThemeData _build(_Paleta p, Brightness brillo) {
    return ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _claro.primary, // mismo seed original (0xFF1A3A6B)
        brightness: brillo,
      ).copyWith(
        primary: p.primary,
        secondary: AppColors.primaryLight,
        surface: p.surface,
        onSurface: p.textPrimary,
        onSurfaceVariant: p.textSecondary,
        surfaceContainerHighest: p.surfaceVariant,
        outline: p.border,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: p.background,
      fontFamily: AppTextStyles.fontFamily,
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: p.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(backgroundColor: p.surface),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(fontSize: 14, color: p.textHint),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}