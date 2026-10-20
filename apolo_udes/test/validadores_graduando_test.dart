import 'package:flutter_test/flutter_test.dart';

import 'package:apolo_udes/core/validators/validadores_graduando.dart';

// ============================================================================
// Pruebas de los validadores CENTRALIZADOS.
//
// Son la capa 1 de validación (la app). La capa 2 son las reglas de
// firestore.rules, que replican el mismo criterio con RE2; si aquí se cambia
// un patrón hay que cambiarlo también allá (y en web/invitados.html).
//
// Los casos dependientes del año se calculan con DateTime.now() para que la
// prueba no caduque: la ventana de ingreso se desliza cada año.
// ============================================================================

void main() {
  final anioActual = DateTime.now().year % 100;
  final anioActualTexto = anioActual.toString().padLeft(2, '0');
  // Año fuera de la ventana de 10 años (siempre viejo, sea cual sea el año).
  const anioViejo = '00';

  group('limpiarEspacios', () {
    test('quita los extremos y colapsa espacios dobles', () {
      expect(limpiarEspacios('  Juan   De  Los Palotes '),
          'Juan De Los Palotes');
    });

    test('también colapsa saltos de línea y tabuladores', () {
      expect(limpiarEspacios('Ana\t\nBrest'), 'Ana Brest');
      expect(limpiarEspacios('   '), '');
    });
  });

  group('esValorFicticio', () {
    test('detecta el mismo dígito repetido', () {
      expect(esValorFicticio('0000000'), isTrue);
      expect(esValorFicticio('77'), isTrue);
      expect(esValorFicticio('1111111111'), isTrue);
    });

    test('detecta secuencias ascendentes y descendentes', () {
      expect(esValorFicticio('123456789'), isTrue);
      expect(esValorFicticio('987654321'), isTrue);
      expect(esValorFicticio('01234567'), isTrue);
    });

    test('acepta valores normales', () {
      expect(esValorFicticio('48291735'), isFalse);
      expect(esValorFicticio('1007654321'), isFalse);
      expect(esValorFicticio('1023456789'), isFalse);
    });
  });

  group('validarCodigoUdes', () {
    test('requerido', () {
      expect(validarCodigoUdes(null), 'Requerido');
      expect(validarCodigoUdes(''), 'Requerido');
      expect(validarCodigoUdes('   '), 'Requerido');
    });

    test('solo números', () {
      expect(validarCodigoUdes('0122037100A'), 'Solo números');
      expect(validarCodigoUdes('01 22037100'), 'Solo números');
    });

    test('debe empezar por 01 (sede principal)', () {
      expect(
          validarCodigoUdes('02${anioActualTexto}0371009'),
          'El código debe empezar por 01 (sede principal Bucaramanga)');
      expect(
          validarCodigoUdes('1${anioActualTexto}0371009'),
          'El código debe empezar por 01 (sede principal Bucaramanga)');
    });

    test('debe tener exactamente 11 dígitos', () {
      expect(validarCodigoUdes('01${anioActualTexto}037100'),
          'El código debe tener 11 dígitos');
      expect(validarCodigoUdes('01${anioActualTexto}03710090'),
          'El código debe tener 11 dígitos');
    });

    test('el año de ingreso no puede ser viejo ni futuro', () {
      expect(validarCodigoUdes('01$anioViejo' '0371009'),
          'Año de ingreso no válido (20$anioViejo)');

      // Año siguiente al actual: nunca se acepta (mensaje con el año real).
      final anioFuturo = ((DateTime.now().year + 1) % 100)
          .toString()
          .padLeft(2, '0');
      expect(validarCodigoUdes('01$anioFuturo' '0371009'), isNotNull);
    });

    test('rechaza el consecutivo ficticio', () {
      expect(validarCodigoUdes('01${anioActualTexto}0000000'),
          'Código no válido');
      expect(validarCodigoUdes('01${anioActualTexto}1234567'),
          'Código no válido');
      expect(validarCodigoUdes('01${anioActualTexto}9876543'),
          'Código no válido');
    });

    test('acepta un código bien formado dentro de la ventana', () {
      expect(validarCodigoUdes('01${anioActualTexto}0371009'), isNull);
      expect(validarCodigoUdes(' 01${anioActualTexto}0371009 '), isNull);
    });

    test('la ventana de ingreso es de 10 años', () {
      expect(prefijoCodigoUdes, '01');
      expect(largoCodigoUdes, 11);
      expect(aniosVentanaIngreso, 10);
    });
  });

  group('validarDocumento', () {
    test('requerido', () {
      expect(validarDocumento(null), 'Requerido');
      expect(validarDocumento('  '), 'Requerido');
    });

    test('entre 6 y 12 dígitos', () {
      expect(validarDocumento('12345'), 'Solo números, de 6 a 12 dígitos');
      expect(validarDocumento('123456789012345'),
          'Solo números, de 6 a 12 dígitos');
      expect(validarDocumento('12AB4567'), 'Solo números, de 6 a 12 dígitos');
    });

    test('la cédula colombiana no empieza por 0', () {
      expect(validarDocumento('0123456'), 'El documento no puede empezar por 0');
    });

    test('rechaza documentos ficticios', () {
      expect(validarDocumento('1111111'), 'Documento no válido');
      expect(validarDocumento('123456789'), 'Documento no válido');
      expect(validarDocumento('9876543210'), 'Documento no válido');
    });

    test('acepta documentos reales', () {
      expect(validarDocumento('1007654321'), isNull);
      expect(validarDocumento('1023456789'), isNull);
      expect(validarDocumento('102345'), isNull); // 6 dígitos
      expect(validarDocumento(' 72986543 '), isNull); // recorta espacios
    });
  });

  group('validarNombrePersona', () {
    test('requerido', () {
      expect(validarNombrePersona(null), 'Requerido');
      expect(validarNombrePersona('   '), 'Requerido');
    });

    test('solo letras, de 2 a 50 caracteres', () {
      expect(validarNombrePersona('12345'), 'Solo letras (2 a 50)');
      expect(validarNombrePersona('A'), 'Solo letras (2 a 50)');
      expect(validarNombrePersona('Ana1'), 'Solo letras (2 a 50)');
      expect(
          validarNombrePersona('x' * 51), 'Solo letras (2 a 50)');
    });

    test('demasiado corto (una sola letra entre caracteres permitidos)', () {
      // "B'" y "B-" pasan la expresión regular pero solo tienen una letra.
      expect(validarNombrePersona("B'"), 'Demasiado corto');
      expect(validarNombrePersona('B-'), 'Demasiado corto');
    });

    test('acepta tildes, Ñ, acentos, apóstrofes y guiones', () {
      expect(validarNombrePersona('José Ñandú'), isNull);
      expect(validarNombrePersona("D'Angelo"), isNull);
      expect(validarNombrePersona('María-Paz'), isNull);
      expect(validarNombrePersona('  Ana  María  '), isNull);
      expect(validarNombrePersona('Li'), isNull);
    });
  });

  group('validarTelefono', () {
    test('requerido', () {
      expect(validarTelefono(null), 'Requerido');
      expect(validarTelefono(''), 'Requerido');
    });

    test('celular 3XXXXXXXXX o fijo 60XXXXXXXX', () {
      expect(validarTelefono('3001234567'), isNull);
      expect(validarTelefono('6012345678'), isNull);
      expect(validarTelefono('300123456'),
          'Celular 3XXXXXXXXX o fijo 60XXXXXXXX');
      expect(validarTelefono('2001234567'),
          'Celular 3XXXXXXXXX o fijo 60XXXXXXXX');
      expect(validarTelefono('300123456789'),
          'Celular 3XXXXXXXXX o fijo 60XXXXXXXX');
    });

    test('rechaza teléfonos ficticios', () {
      expect(validarTelefono('3333333333'), 'Teléfono no válido');
      expect(validarTelefono('3000000000'), 'Teléfono no válido');
      expect(validarTelefono('6000000000'), 'Teléfono no válido');
    });
  });

  group('validarCorreo', () {
    test('requerido', () {
      expect(validarCorreo(null), 'Requerido');
      expect(validarCorreo('   '), 'Requerido');
    });

    test('formato válido (incluye dominios UDES)', () {
      expect(validarCorreo('usuario@udes.edu.co'), isNull);
      expect(validarCorreo('JUAN.Perez@UDES.EDU.CO'), isNull);
      expect(validarCorreo('a+b_c@dominio.co'), isNull);
      expect(validarCorreo('a@b.co'), isNull);
    });

    test('formato inválido', () {
      expect(validarCorreo('no-es-correo'), 'Correo no válido');
      expect(validarCorreo('a@dominio'), 'Correo no válido');
      expect(validarCorreo('a@b.c'), 'Correo no válido');
      expect(validarCorreo('a b@dominio.com'), 'Correo no válido');
      expect(validarCorreo('a@dominio.com.'), 'Correo no válido');
      expect(validarCorreo('@dominio.com'), 'Correo no válido');
      expect(validarCorreo('a@@dominio.com'), 'Correo no válido');
    });

    test('no admite puntos consecutivos (evita "a..b@x.com")', () {
      expect(validarCorreo('a..b@dominio.com'), 'Correo no válido');
    });

    test('respeta el límite de 254 caracteres', () {
      // '@dominio.com' ocupa 12 caracteres: 242 + 12 = 254 → válido.
      final justo = '${'a' * 242}@dominio.com';
      expect(justo.length, 254);
      expect(validarCorreo(justo), isNull);

      // 255 → inválido.
      final largo = '${'a' * 243}@dominio.com';
      expect(largo.length, 255);
      expect(validarCorreo(largo), 'Correo no válido');
    });
  });

  group('filtros de escritura', () {
    test('filtroSoloNumeros deja únicamente dígitos', () {
      const entrada = TextEditingValue(text: '12a-3 4');
      final salida =
          filtroSoloNumeros.formatEditUpdate(entrada, entrada);
      expect(salida.text, '1234');
    });

    test('filtroSinEspacios quita espacios y saltos', () {
      const entrada = TextEditingValue(text: 'a b\tc\nd');
      final salida = filtroSinEspacios.formatEditUpdate(entrada, entrada);
      expect(salida.text, 'abcd');
    });

    test('filtroSoloLetras conserva letras, espacios, \' y -', () {
      const entrada = TextEditingValue(text: "Ana-1'2 Pérez");
      final salida = filtroSoloLetras.formatEditUpdate(entrada, entrada);
      expect(salida.text, "Ana-' Pérez");
    });
  });
}
