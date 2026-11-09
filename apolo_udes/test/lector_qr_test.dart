import 'package:flutter_test/flutter_test.dart';

import 'package:apolo_udes/presentation/screens/control_acceso/control_acceso_screen.dart';

// Regla del lector: qué QR se procesa cuando la cámara ve uno o varios.
void main() {
  final t0 = DateTime(2026, 11, 7, 10);

  test('un código nuevo se procesa', () {
    final vistos = <String, DateTime>{};
    expect(codigoAProcesar(['A'], vistos, t0, ocupado: false), 'A');
  });

  test('el mismo código frente a la cámara no se repite', () {
    final vistos = {'A': t0};
    final luego = t0.add(const Duration(seconds: 2));
    expect(codigoAProcesar(['A'], vistos, luego, ocupado: false), isNull);
    // Mientras siga frente a la cámara la hora se renueva: a los 4 s tampoco.
    expect(codigoAProcesar(['A'], vistos, t0.add(const Duration(seconds: 4)), ocupado: false), isNull);
  });

  test('con el QR anterior todavía visible, el nuevo sí se lee', () {
    final vistos = {'A': t0};
    final luego = t0.add(const Duration(seconds: 1));
    expect(codigoAProcesar(['A', 'B'], vistos, luego, ocupado: false), 'B');
  });

  test('si está ocupado, el nuevo espera a la siguiente detección', () {
    final vistos = <String, DateTime>{};
    expect(codigoAProcesar(['B'], vistos, t0, ocupado: true), isNull);
    expect(codigoAProcesar(['B'], vistos, t0, ocupado: false), 'B');
  });
}
