import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apolo_udes/presentation/widgets/shell/cierre_inactividad.dart';

// Pruebas del cierre de sesión por inactividad del administrador.
void main() {
  Widget armar({required bool activo, required VoidCallback alVencer}) {
    return MaterialApp(
      home: CierrePorInactividad(
        activo: activo,
        minutos: 15,
        alVencer: alVencer,
        child: const Scaffold(body: SizedBox.expand(child: Text('panel'))),
      ),
    );
  }

  testWidgets('cierra la sesión a los 15 minutos sin uso', (tester) async {
    var cerro = false;
    await tester.pumpWidget(armar(activo: true, alVencer: () => cerro = true));

    await tester.pump(const Duration(minutes: 14, seconds: 59));
    expect(cerro, isFalse);

    await tester.pump(const Duration(seconds: 2));
    expect(cerro, isTrue);
  });

  testWidgets('cada toque vuelve a contar desde cero', (tester) async {
    var cerro = false;
    await tester.pumpWidget(armar(activo: true, alVencer: () => cerro = true));

    await tester.pump(const Duration(minutes: 10));
    await tester.tap(find.text('panel'));
    await tester.pump(const Duration(minutes: 10)); // 20 min en total, 10 desde el toque
    expect(cerro, isFalse);

    await tester.pump(const Duration(minutes: 6));
    expect(cerro, isTrue);
  });

  testWidgets('al operador nunca se le cierra la sesión', (tester) async {
    var cerro = false;
    await tester.pumpWidget(armar(activo: false, alVencer: () => cerro = true));

    await tester.pump(const Duration(hours: 3));
    expect(cerro, isFalse);
  });
}
