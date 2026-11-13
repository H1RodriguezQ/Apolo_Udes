import 'package:flutter_test/flutter_test.dart';

import 'package:apolo_udes/data/models/models.dart';
import 'package:apolo_udes/providers/app_provider.dart';

// Regla de uso único: una invitación da UN ingreso, por QR o por documento.
Confirmacion invitado(String qr, String doc) => Confirmacion(
      id: qr, invitado: 'Invitado $qr', documento: doc,
      graduandoNombre: 'Graduando', estado: EstadoConfirmacion.confirmado,
      codigoQr: qr);

void main() {
  final ana = invitado('QR-ANA', '1098');
  final luis = invitado('QR-LUIS', '2077');

  test('si entró con el QR, su documento queda bloqueado', () {
    final usados = calcularCodigosUsados({'QR-ANA'}, {}, [ana, luis]);
    expect(usados, containsAll(['QR-ANA', '1098']));
  });

  test('si entró digitando el documento, su QR queda bloqueado', () {
    final usados = calcularCodigosUsados({}, {'1098'}, [ana, luis]);
    expect(usados, contains('QR-ANA'));
  });

  test('el ingreso de un invitado no bloquea a otro', () {
    final usados = calcularCodigosUsados({'QR-ANA'}, {}, [ana, luis]);
    expect(usados, isNot(contains('QR-LUIS')));
    expect(usados, isNot(contains('2077')));
  });

  test('las validaciones de la otra tablet y las locales se suman', () {
    final usados = calcularCodigosUsados({'QR-ANA'}, {'QR-LUIS'}, [ana, luis]);
    expect(usados, containsAll(['QR-ANA', '1098', 'QR-LUIS', '2077']));
  });

  test('un invitado sin documento ni QR no bloquea a nadie por cadena vacía', () {
    final sinDatos = Confirmacion(
        id: 'x', invitado: 'Sin datos', documento: '', graduandoNombre: 'G',
        estado: EstadoConfirmacion.confirmado);
    final usados = calcularCodigosUsados({'QR-ANA'}, {}, [sinDatos, luis]);
    expect(usados, isNot(contains('')));
    expect(usados, isNot(contains('QR-LUIS')));
  });
}
