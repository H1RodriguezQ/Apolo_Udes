import 'package:flutter/material.dart';

// ============================================================================
// Tema de Apolo UDES (rediseño para tablets, noviembre de 2026).
//
// Los colores salen del lienzo de diseño: azul institucional de la UDES,
// fondo gris cálido y tarjetas blancas con borde fino. Cada color que cambia
// entre modo claro y oscuro está en `_Paleta`; las pantallas los leen con
// `AppColors.<nombre>` y así no tienen que preguntar en qué modo están.
// ============================================================================

/// Colores que cambian entre modo claro y oscuro.
class _Paleta {
  final Color primary; // enlaces y textos de acento
  final Color boton; // fondo de los botones principales
  final Color background; // fondo de la pantalla
  final Color header; // barra superior de cada pantalla
  final Color surface; // tarjetas
  final Color surfaceVariant; // encabezados de tabla, campos de solo lectura
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color border;
  final Color borderFuerte; // borde de los botones secundarios
  final Color divider;
  final Color successLight;
  final Color successText;
  final Color errorLight;
  final Color errorText;
  final Color warningLight;
  final Color warningText;
  final Color infoLight;
  final Color infoText;
  final Color pendingLight;
  final Color pista; // fondo de las barras de progreso
  final Color rail; // menú lateral
  final Color railBorde;

  const _Paleta({
    required this.primary,
    required this.boton,
    required this.background,
    required this.header,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.border,
    required this.borderFuerte,
    required this.divider,
    required this.successLight,
    required this.successText,
    required this.errorLight,
    required this.errorText,
    required this.warningLight,
    required this.warningText,
    required this.infoLight,
    required this.infoText,
    required this.pendingLight,
    required this.pista,
    required this.rail,
    required this.railBorde,
  });
}

const _claro = _Paleta(
  primary: Color(0xFF0A4A98),
  boton: Color(0xFF0B4A99),
  background: Color(0xFFECEEE9),
  header: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  surfaceVariant: Color(0xFFF5F6F3),
  textPrimary: Color(0xFF1B2433),
  textSecondary: Color(0xFF5B6472),
  textHint: Color(0xFF8A919C),
  border: Color(0xFFDCDFD8),
  borderFuerte: Color(0xFFC9CDC5),
  divider: Color(0xFFE5E7E2),
  successLight: Color(0xFFDCEFE2),
  successText: Color(0xFF1D5E37),
  errorLight: Color(0xFFF8DCD8),
  errorText: Color(0xFF8F2A1F),
  warningLight: Color(0xFFFBE6CC),
  warningText: Color(0xFF80460D),
  infoLight: Color(0xFFE4E9F1),
  infoText: Color(0xFF2B3C5C),
  pendingLight: Color(0xFFE9E4F3),
  pista: Color(0xFFE7E9E4),
  rail: Color(0xFF06387A),
  railBorde: Color(0xFF5D7FB0),
);

const _oscuro = _Paleta(
  primary: Color(0xFF8FB4EA),
  boton: Color(0xFF2F6BC4),
  background: Color(0xFF0F141C),
  header: Color(0xFF141B25),
  surface: Color(0xFF171E29),
  surfaceVariant: Color(0xFF1E2733),
  textPrimary: Color(0xFFE6EBF2),
  textSecondary: Color(0xFFA3ADBB),
  textHint: Color(0xFF7D8796),
  border: Color(0xFF2B3442),
  borderFuerte: Color(0xFF3A4556),
  divider: Color(0xFF263040),
  successLight: Color(0xFF173828),
  successText: Color(0xFF8FE0B4),
  errorLight: Color(0xFF3D1C19),
  errorText: Color(0xFFF5B0A6),
  warningLight: Color(0xFF3A2B14),
  warningText: Color(0xFFF3CC8A),
  infoLight: Color(0xFF1F2B3D),
  infoText: Color(0xFFB8C9E6),
  pendingLight: Color(0xFF2A2440),
  pista: Color(0xFF252F3D),
  rail: Color(0xFF0A1426),
  railBorde: Color(0xFF3B4A63),
);

class AppColors {
  /// Lo actualiza main.dart según el modo elegido (claro/oscuro/sistema).
  static bool isDark = false;
  static _Paleta get _p => isDark ? _oscuro : _claro;

  // ── Cambian según el modo ──
  static Color get primary => _p.primary;
  static Color get boton => _p.boton;
  static Color get background => _p.background;
  static Color get header => _p.header;
  static Color get surface => _p.surface;
  static Color get surfaceVariant => _p.surfaceVariant;
  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get textHint => _p.textHint;
  static Color get border => _p.border;
  static Color get borderFuerte => _p.borderFuerte;
  static Color get divider => _p.divider;
  static Color get successLight => _p.successLight;
  static Color get successText => _p.successText;
  static Color get errorLight => _p.errorLight;
  static Color get errorText => _p.errorText;
  static Color get warningLight => _p.warningLight;
  static Color get warningText => _p.warningText;
  static Color get infoLight => _p.infoLight;
  static Color get infoText => _p.infoText;
  static Color get pendingLight => _p.pendingLight;
  static Color get pista => _p.pista;
  static Color get rail => _p.rail;
  static Color get railBorde => _p.railBorde;

  // ── Iguales en ambos modos ──
  // Se dejan los mismos nombres de antes para no tener que tocar cada
  // pantalla; solo cambian los tonos a los del diseño nuevo.
  // Azul medio: se lee sobre blanco y sobre el fondo oscuro (iconos y textos).
  static const Color primaryLight = Color(0xFF2F6BC4);
  static const Color primaryDark = Color(0xFF06387A);
  static const Color accent = Color(0xFFC4956A); // línea dorada del login
  static const Color accentLight = Color(0xFFE0BE96);

  static const Color sidebarBg = Color(0xFF06387A);
  static const Color sidebarActive = Color(0xFF0B4A99);
  static const Color sidebarText = Color(0xFFC7D4E8);
  static const Color sidebarTextActive = Color(0xFFFFFFFF);

  // Colores de estado para iconos, gráficos y textos sobre fondo claro.
  static const Color success = Color(0xFF2E7D4F);
  static const Color error = Color(0xFFC8473A);
  static const Color warning = Color(0xFFB26A16);
  static const Color info = Color(0xFF2F6BC4);
  static const Color pending = Color(0xFF7B6CC0);

  // Serie de los gráficos (entradas, facultades): tonos del mismo azul.
  static const Color serie1 = Color(0xFF0B4A99);
  static const Color serie2 = Color(0xFF9DB5DC);

  static const Color textOnPrimary = Color(0xFFFFFFFF);
}

class AppTextStyles {
  static const String fontFamily = 'IBMPlexSans';
  static const String fontMono = 'IBMPlexMono';

  static TextStyle get h1 => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get h2 => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  static TextStyle get h3 => TextStyle(
        fontSize: 17,
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
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get caption => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textHint,
      );

  /// Números, horas y códigos: letra de ancho fijo para que no "bailen".
  static TextStyle mono({double size = 14, FontWeight peso = FontWeight.w400, Color? color}) =>
      TextStyle(
        fontFamily: fontMono,
        fontSize: size,
        fontWeight: peso,
        color: color ?? AppColors.textPrimary,
      );
}

class AppTheme {
  static ThemeData get light => _build(_claro, Brightness.light);
  static ThemeData get dark => _build(_oscuro, Brightness.dark);

  static ThemeData _build(_Paleta p, Brightness brillo) {
    final redondeo = BorderRadius.circular(8);
    return ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _claro.boton,
        brightness: brillo,
      ).copyWith(
        primary: p.boton,
        onPrimary: Colors.white,
        secondary: p.primary,
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
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: p.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        border: OutlineInputBorder(
          borderRadius: redondeo,
          borderSide: BorderSide(color: p.borderFuerte),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: redondeo,
          borderSide: BorderSide(color: p.borderFuerte),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: redondeo,
          borderSide: BorderSide(color: p.boton, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(fontSize: 14, color: p.textHint),
        labelStyle: TextStyle(fontSize: 14, color: p.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.boton,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: redondeo),
          textStyle: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          backgroundColor: p.surface,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: p.borderFuerte),
          shape: RoundedRectangleBorder(borderRadius: redondeo),
          textStyle: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle: const TextStyle(
            fontFamily: AppTextStyles.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceVariant,
        side: BorderSide(color: p.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: TextStyle(fontSize: 13, color: p.textPrimary),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(p.surfaceVariant),
        headingTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: p.textSecondary,
        ),
        dataTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 14,
          color: p.textPrimary,
        ),
        dividerThickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: redondeo),
      ),
      dividerTheme: DividerThemeData(
        color: p.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
