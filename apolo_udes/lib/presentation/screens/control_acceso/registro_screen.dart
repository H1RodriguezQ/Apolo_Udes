import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/apolo_ui.dart';

/// Registro de la entrada (rediseño, operador): todas las lecturas de hoy
/// en SU punto de entrada, válidas y rechazadas, la más reciente arriba.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  String _filtro = 'todo';
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final punto = provider.miPunto;
    final mias = provider.lecturasDelDia.where((l) => punto.isEmpty || l.punto == punto).toList();
    final q = _busqueda.trim().toLowerCase();
    final filtradas = mias.where((l) {
      if (_filtro == 'validas' && !l.valida) return false;
      if (_filtro == 'rechazadas' && l.valida) return false;
      return q.isEmpty || l.nombre.toLowerCase().contains(q) || l.codigo.toLowerCase().contains(q);
    }).toList();

    return PantallaApolo(
      encabezado: EncabezadoPantalla(
        titulo: 'Registro de la entrada',
        detalle: '${punto.isEmpty ? 'Todas las entradas' : punto} · hoy',
        mostrarConexion: true,
      ),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FiltroSegmentado<String>(
                valor: _filtro,
                onChanged: (v) => setState(() => _filtro = v),
                opciones: [
                  ('todo', 'Todo', mias.length),
                  ('validas', 'Válidas', mias.where((l) => l.valida).length),
                  ('rechazadas', 'Rechazadas', mias.where((l) => !l.valida).length),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 280,
                child: CampoConEtiqueta(
                  etiqueta: 'Buscar',
                  campo: CampoBusqueda(hint: 'Nombre o código', onChanged: (v) => setState(() => _busqueda = v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TablaApolo(
              vacio: 'Todavía no hay lecturas en esta entrada.',
              porPagina: 12,
              columnas: const [
                ColumnaTabla('Hora', flex: 1),
                ColumnaTabla('Persona', flex: 4),
                ColumnaTabla('Resultado', flex: 2),
                ColumnaTabla('Operador', flex: 3),
              ],
              filas: [
                for (final l in filtradas)
                  [
                    CeldaTexto(DateFormat('HH:mm').format(l.hora), mono: true),
                    CeldaTexto(l.nombre.isEmpty ? 'Sin identificar' : l.nombre, fuerte: true),
                    switch (l.resultado) {
                      'valido' => const Etiqueta('Válido', tono: TonoEtiqueta.ok),
                      'usado' => const Etiqueta('Ya usado', tono: TonoEtiqueta.aviso),
                      _ => const Etiqueta('No válido', tono: TonoEtiqueta.error),
                    },
                    Text(l.operador, style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
