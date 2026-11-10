import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:apolo_udes/core/theme/app_theme.dart';
import 'package:apolo_udes/presentation/widgets/common/apolo_ui.dart';
import 'package:apolo_udes/presentation/widgets/common/widgets.dart';

// Datos del peor caso real (break-ui): nombres y correos largos que sí
// existen, nombres de una letra, campos vacíos y listas grandes. Si algún
// componente se desborda, Flutter lanza un error de "overflowed" y la
// prueba falla.
const _filas = [
  ['María Fernanda de los Ángeles Wiśniewska Rodríguez-Kowalczyk', 'bartholomew.fitzgerald@northwind-industries-holdings.example.com', 'Confirmada'],
  ['Jo', 'jo@x.co', 'Pendiente de confirmación por el graduando'],
  ['', '', ''],
  ['José Ñúñez O\'Connor', 'jose@udes.edu.co', 'Rechazada'],
];

Widget _tabla(int repetir) => TablaApolo(
      columnas: const [
        ColumnaTabla('Nombre', flex: 3),
        ColumnaTabla('Estado', flex: 2),
        ColumnaTabla('Acciones', flex: 1, derecha: true),
      ],
      filas: [
        for (var i = 0; i < repetir; i++)
          for (final f in _filas)
            [
              CeldaTexto(f[0], debajo: f[1], fuerte: true),
              Etiqueta(f[2], tono: TonoEtiqueta.aviso),
              Row(mainAxisSize: MainAxisSize.min, children: [
                AccionFila(icono: Icons.edit_outlined, ayuda: 'Editar', onPressed: () {}),
                AccionFila(icono: Icons.delete_outline, ayuda: 'Eliminar', onPressed: () {}, peligro: true),
              ]),
            ],
      ],
    );

Future<void> _pintar(WidgetTester t, Size tamano, double escala, Widget hijo) async {
  t.view.physicalSize = tamano;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(size: tamano, textScaler: TextScaler.linear(escala)),
      child: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: hijo)),
    ),
  ));
}

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  const tamanos = {'tablet': Size(1280, 800), 'celular': Size(360, 740)};
  for (final MapEntry(key: nombre, value: tamano) in tamanos.entries) {
    for (final escala in [1.0, 2.0]) {
      testWidgets('tabla con datos extremos en $nombre, letra x$escala', (t) async {
        await _pintar(t, tamano, escala, _tabla(321)); // 1.284 filas
        expect(t.takeException(), isNull);
        expect(find.textContaining('de 1.284'), findsOneWidget);
      });
    }
  }

  testWidgets('tabla vacía muestra el mensaje', (t) async {
    await _pintar(t, const Size(1280, 800), 1, _tabla(0));
    expect(find.text('No hay registros.'), findsOneWidget);
  });

  testWidgets('tarjeta de métrica con número enorme y título largo en celular', (t) async {
    await _pintar(
      t,
      const Size(360, 740),
      2,
      const MetricCard(
        title: 'Invitados confirmados para la ceremonia de la tarde',
        value: '1.284.000',
        icon: Icons.people_outline,
        color: Colors.blue,
        subtitle: 'De 2.568 cupos autorizados por la Secretaría General',
      ),
    );
    expect(t.takeException(), isNull);
  });
}
