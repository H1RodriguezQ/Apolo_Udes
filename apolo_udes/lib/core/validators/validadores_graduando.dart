import 'package:flutter/services.dart';

// ============================================================================
// Validaciones de graduandos
//
// Un solo lugar para las reglas: las usan el formulario de "Agregar
// graduando" y la importación desde Excel. Así ambos caminos aceptan y
// rechazan exactamente lo mismo.
//
// Cada función devuelve `null` si el valor es válido, o el mensaje de error.
// ============================================================================

const _letras = 'A-Za-zÁÉÍÓÚÜÑáéíóúüñ';

/// Formato del código estudiantil UDES (11 dígitos):
///   01       → sede (01 = sede principal Bucaramanga)
///   AA       → año de ingreso (ej. 22 = 2022)
///   NNNNNNN  → consecutivo de 7 dígitos
const prefijoCodigoUdes = '01';
const largoCodigoUdes = 11;

/// Ventana de años de ingreso aceptados, contados hacia atrás desde el año
/// actual. Con 10, en 2026 se aceptan ingresos de 2016 a 2026, y cada año
/// la ventana avanza sola.
const aniosVentanaIngreso = 10;

// ── Filtros de escritura (impiden teclear caracteres no permitidos) ──

final filtroSoloNumeros = FilteringTextInputFormatter.digitsOnly;
final filtroSoloLetras = FilteringTextInputFormatter.allow(RegExp("[$_letras '\\-]"));
final filtroSinEspacios = FilteringTextInputFormatter.deny(RegExp(r'\s'));

// ── Utilidades ──

/// Quita espacios al inicio y al final y deja un solo espacio entre palabras.
String limpiarEspacios(String v) => v.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Detecta valores de relleno: el mismo dígito repetido (0000000, 3333333)
/// o una secuencia simple (123456789, 987654321).
bool esValorFicticio(String t) {
  if (RegExp(r'^(\d)\1+$').hasMatch(t)) return true;
  const asc = '01234567890123456789';
  const desc = '98765432109876543210';
  return asc.contains(t) || desc.contains(t);
}

// ── Validadores ──

String? validarCodigoUdes(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Requerido';
  if (!RegExp(r'^\d+$').hasMatch(t)) return 'Solo números';
  if (!t.startsWith(prefijoCodigoUdes)) {
    return 'El código debe empezar por $prefijoCodigoUdes (sede principal Bucaramanga)';
  }
  if (t.length != largoCodigoUdes) {
    return 'El código debe tener $largoCodigoUdes dígitos';
  }

  // Año de ingreso: dentro de la ventana y nunca en el futuro.
  final anio = int.parse(t.substring(2, 4));
  final anioActual = DateTime.now().year % 100;
  final anioMinimo = anioActual - aniosVentanaIngreso;
  if (anio < anioMinimo || anio > anioActual) {
    return 'Año de ingreso no válido (20${t.substring(2, 4)})';
  }

  if (esValorFicticio(t.substring(4))) return 'Código no válido';
  return null;
}

String? validarDocumento(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Requerido';
  if (!RegExp(r'^\d{6,12}$').hasMatch(t)) return 'Solo números, de 6 a 12 dígitos';
  // Una cédula colombiana no empieza por 0.
  if (t.startsWith('0')) return 'El documento no puede empezar por 0';
  if (esValorFicticio(t)) return 'Documento no válido';
  return null;
}

String? validarNombrePersona(String? v) {
  final t = limpiarEspacios(v ?? '');
  if (t.isEmpty) return 'Requerido';
  if (!RegExp("^[$_letras][$_letras '\\-]{1,49}\$").hasMatch(t)) {
    return 'Solo letras (2 a 50)';
  }
  if (t.replaceAll(RegExp("[^$_letras]"), '').length < 2) return 'Demasiado corto';
  return null;
}

String? validarTelefono(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Requerido';
  // Celular colombiano (3XXXXXXXXX) o fijo con indicativo (60XXXXXXXX).
  if (!RegExp(r'^(3\d{9}|60\d{8})$').hasMatch(t)) {
    return 'Celular 3XXXXXXXXX o fijo 60XXXXXXXX';
  }
  if (esValorFicticio(t) || RegExp(r'^\d0{9}$').hasMatch(t)) {
    return 'Teléfono no válido';
  }
  return null;
}

String? validarCorreo(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Requerido';
  final ok = RegExp(
          r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$')
      .hasMatch(t);
  if (t.length > 254 || !ok || t.contains('..')) return 'Correo no válido';
  return null;
}