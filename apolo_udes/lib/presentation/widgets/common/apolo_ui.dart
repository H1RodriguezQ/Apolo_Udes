import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/theme_provider.dart';

// ============================================================================
// Piezas del diseño para tablets que usan todas las pantallas: el encabezado
// con título y botones, los filtros con contador, la búsqueda y la tabla con
// paginación. Están juntas para que todas las pantallas se vean iguales.
// ============================================================================

/// Barra superior de 76 px: título, un dato al lado (por ejemplo "186
/// registrados") y los botones de la pantalla a la derecha. Siempre termina
/// con el botón de modo claro/oscuro.
class EncabezadoPantalla extends StatelessWidget {
  final String titulo;
  final String? detalle; // texto gris al lado del título
  final String? segundaLinea; // texto gris debajo del título
  final List<Widget> acciones;
  final bool mostrarConexion;
  final VoidCallback? alVolver; // flecha "<" a la izquierda del título

  const EncabezadoPantalla({
    super.key,
    required this.titulo,
    this.detalle,
    this.segundaLinea,
    this.acciones = const [],
    this.mostrarConexion = false,
    this.alVolver,
  });

  @override
  Widget build(BuildContext context) {
    final enLinea = context.watch<AppProvider>().enLinea;
    final angosto = MediaQuery.sizeOf(context).width < 800;

    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: EdgeInsets.symmetric(horizontal: angosto ? 16 : 32, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.header,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (alVolver != null) ...[
            IconButton(
              onPressed: alVolver,
              icon: Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary),
              tooltip: 'Volver',
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(titulo,
                          style: AppTextStyles.h1, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (detalle != null && !angosto) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(detalle!,
                            style: AppTextStyles.label.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
                if (segundaLinea != null)
                  Text(segundaLinea!,
                      style: AppTextStyles.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (!angosto)
            for (final a in acciones) ...[const SizedBox(width: 10), a],
          if (mostrarConexion) ...[
            const SizedBox(width: 10),
            _PildoraConexion(enLinea: enLinea),
          ],
          const SizedBox(width: 10),
          const BotonModoOscuro(),
        ],
      ),
    );
  }
}

class _PildoraConexion extends StatelessWidget {
  final bool enLinea;
  const _PildoraConexion({required this.enLinea});

  @override
  Widget build(BuildContext context) {
    final fondo = enLinea ? AppColors.successLight : AppColors.warningLight;
    final texto = enLinea ? AppColors.successText : AppColors.warningText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: texto, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(enLinea ? 'En línea' : 'Sin conexión',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: texto)),
        ],
      ),
    );
  }
}

/// Botón cuadrado con la luna (o el sol) para cambiar el tema.
class BotonModoOscuro extends StatelessWidget {
  const BotonModoOscuro({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<ThemeProvider>();
    return Tooltip(
      message: AppColors.isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
      child: SizedBox(
        width: 44,
        height: 44,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 44)),
          // Desde aquí se alterna solo entre claro y oscuro: lo que se ve es
          // lo que se pide. "Igual que el sistema" queda en Ajustes.
          onPressed: () => tema.cambiar(AppColors.isDark ? ThemeMode.light : ThemeMode.dark),
          child: Icon(AppColors.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Botón secundario blanco con borde (como "Importar Excel").
class BotonSecundario extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;
  final bool peligro; // texto rojo para acciones que borran
  const BotonSecundario({super.key, required this.texto, this.onPressed, this.icono, this.peligro = false});

  @override
  Widget build(BuildContext context) {
    final estilo = OutlinedButton.styleFrom(
      foregroundColor: peligro ? AppColors.errorText : AppColors.textPrimary,
      side: BorderSide(color: peligro ? AppColors.errorText.withValues(alpha: 0.5) : AppColors.borderFuerte),
    );
    return icono == null
        ? OutlinedButton(style: estilo, onPressed: onPressed, child: Text(texto))
        : OutlinedButton.icon(style: estilo, onPressed: onPressed, icon: Icon(icono, size: 18), label: Text(texto));
  }
}

/// Grupo de botones pegados para filtrar, cada uno con su número:
/// [ Todos 319 | Confirmaron 201 | Sin confirmar 104 ].
class FiltroSegmentado<T> extends StatelessWidget {
  final List<(T, String, int?)> opciones;
  final T valor;
  final ValueChanged<T> onChanged;
  const FiltroSegmentado({super.key, required this.opciones, required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderFuerte),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < opciones.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, thickness: 1, color: AppColors.borderFuerte),
              _Segmento(
                texto: opciones[i].$2,
                numero: opciones[i].$3,
                activo: opciones[i].$1 == valor,
                onTap: () => onChanged(opciones[i].$1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Segmento extends StatelessWidget {
  final String texto;
  final int? numero;
  final bool activo;
  final VoidCallback onTap;
  const _Segmento({required this.texto, required this.numero, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = activo ? Colors.white : AppColors.textPrimary;
    return Material(
      color: activo ? AppColors.boton : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(texto, style: TextStyle(fontSize: 14, fontWeight: activo ? FontWeight.w600 : FontWeight.w500, color: color)),
              if (numero != null) ...[
                const SizedBox(width: 8),
                Text('$numero', style: AppTextStyles.mono(size: 13, color: color)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo con etiqueta pequeña encima ("Buscar", "Facultad"...).
class CampoConEtiqueta extends StatelessWidget {
  final String etiqueta;
  final Widget campo;
  final String? nota; // texto gris al lado de la etiqueta
  const CampoConEtiqueta({super.key, required this.etiqueta, required this.campo, this.nota});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(TextSpan(children: [
          TextSpan(text: etiqueta, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          if (nota != null) TextSpan(text: ' $nota', style: AppTextStyles.label),
        ])),
        const SizedBox(height: 6),
        campo,
      ],
    );
  }
}

/// Caja de búsqueda del diseño (sin icono, texto gris de ejemplo).
class CampoBusqueda extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const CampoBusqueda({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

/// Fila de filtros o campos: en pantallas anchas van uno al lado del otro;
/// en el celular (menos de 600 px) van uno debajo del otro y a todo el ancho.
/// Recibe los mismos hijos que un Row (Expanded, SizedBox de ancho fijo y
/// SizedBox vacíos como separadores).
class FilaAdaptable extends StatelessWidget {
  final List<Widget> children;
  final CrossAxisAlignment alinear;
  const FilaAdaptable({super.key, required this.children, this.alinear = CrossAxisAlignment.end});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, caja) {
      if (caja.maxWidth >= 600) {
        return Row(crossAxisAlignment: alinear, children: children);
      }
      final columna = <Widget>[];
      for (final w in children) {
        if (w is SizedBox && w.child == null) continue; // separador horizontal
        if (w is Spacer) continue; // espacio flexible: no aplica en columna
        Widget hijo = w;
        if (w is Flexible) hijo = w.child; // Expanded también es Flexible
        if (w is SizedBox && w.child != null) hijo = w.child!;
        if (columna.isNotEmpty) columna.add(const SizedBox(height: 12));
        columna.add(hijo);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: columna);
    });
  }
}

/// Columna de una tabla: título y cuánto espacio toma (flex). `derecha`
/// alinea el contenido a la derecha (por ejemplo los botones de acciones).
class ColumnaTabla {
  final String titulo;
  final int flex;
  final bool derecha;
  const ColumnaTabla(this.titulo, {this.flex = 2, this.derecha = false});
}

/// Tabla del diseño: encabezado gris, filas separadas por una línea fina y
/// un pie con "Mostrando 1 a 10 de N" y los botones Anterior / Siguiente.
/// Recibe TODAS las filas y pagina sola.
class TablaApolo extends StatefulWidget {
  final List<ColumnaTabla> columnas;
  final List<List<Widget>> filas;
  final String vacio;
  final int porPagina;
  final String? pie; // texto fijo del pie en vez de la paginación

  const TablaApolo({
    super.key,
    required this.columnas,
    required this.filas,
    this.vacio = 'No hay registros.',
    this.porPagina = 10,
    this.pie,
  });

  @override
  State<TablaApolo> createState() => _TablaApoloState();
}

class _TablaApoloState extends State<TablaApolo> {
  int _pagina = 0;

  static final _formatoMiles = NumberFormat.decimalPattern('es_CO');
  static String _miles(int n) => _formatoMiles.format(n); // 1284 → "1.284"

  @override
  void didUpdateWidget(TablaApolo viejo) {
    super.didUpdateWidget(viejo);
    // Si el filtro dejó menos filas, se vuelve a una página que exista.
    final paginas = (widget.filas.length / widget.porPagina).ceil();
    if (_pagina > 0 && _pagina >= paginas) _pagina = (paginas - 1).clamp(0, 1 << 30);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.filas.length;
    final desde = _pagina * widget.porPagina;
    final hasta = (desde + widget.porPagina).clamp(0, total);
    final visibles = widget.filas.sublist(desde.clamp(0, total), hasta);

    return LayoutBuilder(
      builder: (context, caja) => _tabla(context, visibles, total, desde, hasta, caja.maxWidth < 600),
    );
  }

  /// En el celular cada fila se muestra como una tarjeta: la primera columna
  /// (el nombre) arriba, las demás como "Columna: valor" y los botones de la
  /// columna Acciones abajo a la derecha. Así no se parten las palabras.
  Widget _tarjeta(List<Widget> celdas) {
    final columnas = widget.columnas;
    final tieneAcciones = columnas.last.titulo.toLowerCase().startsWith('acci') && celdas.length == columnas.length;
    final hastaDatos = tieneAcciones ? columnas.length - 1 : columnas.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (celdas.isNotEmpty) celdas[0],
          for (var k = 1; k < hastaDatos && k < celdas.length; k++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 100, child: Text(columnas[k].titulo, style: AppTextStyles.label.copyWith(fontSize: 13))),
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: celdas[k])),
                ],
              ),
            ),
          if (tieneAcciones) Align(alignment: Alignment.centerRight, child: celdas.last),
        ],
      ),
    );
  }

  Widget _tabla(BuildContext context, List<List<Widget>> visibles, int total, int desde, int hasta, bool celular) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Encabezado (en el celular no se muestra: cada tarjeta dice qué es cada dato)
          if (!celular) ...[
            Container(
              color: AppColors.surfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  for (final c in widget.columnas)
                    Expanded(
                      flex: c.flex,
                      child: Text(c.titulo,
                          textAlign: c.derecha ? TextAlign.right : TextAlign.left,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border),
          ],
          // Filas
          Expanded(
            child: visibles.isEmpty
                ? Center(child: Text(widget.vacio, style: AppTextStyles.label.copyWith(fontSize: 14)))
                : ListView.separated(
                    itemCount: visibles.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (_, i) => celular ? _tarjeta(visibles[i]) : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          for (var k = 0; k < widget.columnas.length; k++)
                            Expanded(
                              flex: widget.columnas[k].flex,
                              child: Align(
                                alignment: widget.columnas[k].derecha ? Alignment.centerRight : Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: k < visibles[i].length ? visibles[i][k] : const SizedBox.shrink(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          Divider(height: 1, color: AppColors.border),
          // Pie
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: widget.pie != null
                ? Align(alignment: Alignment.centerLeft, child: Text(widget.pie!, style: AppTextStyles.label))
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          total == 0 ? 'Sin resultados' : 'Mostrando ${_miles(desde + 1)} a ${_miles(hasta)} de ${_miles(total)}',
                          style: AppTextStyles.label,
                        ),
                      ),
                      // En el celular, flechas: con la letra grande del sistema
                      // los botones con texto no caben y se salían de la pantalla.
                      if (celular) ...[
                        IconButton(
                          tooltip: 'Anterior',
                          onPressed: _pagina > 0 ? () => setState(() => _pagina--) : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        IconButton(
                          tooltip: 'Siguiente',
                          onPressed: hasta < total ? () => setState(() => _pagina++) : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ] else ...[
                        OutlinedButton(
                          onPressed: _pagina > 0 ? () => setState(() => _pagina--) : null,
                          child: const Text('Anterior'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: hasta < total ? () => setState(() => _pagina++) : null,
                          child: const Text('Siguiente'),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Texto de celda: principal arriba y, si hay, uno gris debajo.
class CeldaTexto extends StatelessWidget {
  final String texto;
  final String? debajo;
  final bool mono;
  final bool fuerte;
  const CeldaTexto(this.texto, {super.key, this.debajo, this.mono = false, this.fuerte = false});

  @override
  Widget build(BuildContext context) {
    final estilo = mono
        ? AppTextStyles.mono(size: 14)
        : AppTextStyles.body.copyWith(fontWeight: fuerte ? FontWeight.w500 : FontWeight.w400);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dos líneas: los nombres completos largos se leen enteros en vez de cortarse.
        Text(texto.isEmpty ? '—' : texto, style: estilo, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (debajo != null && debajo!.isNotEmpty)
          Text(debajo!, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

/// Etiqueta de estado del diseño: fondo suave y texto oscuro del mismo tono.
enum TonoEtiqueta { ok, aviso, error, info, neutro }

class Etiqueta extends StatelessWidget {
  final String texto;
  final TonoEtiqueta tono;
  const Etiqueta(this.texto, {super.key, this.tono = TonoEtiqueta.neutro});

  @override
  Widget build(BuildContext context) {
    final (fondo, color) = switch (tono) {
      TonoEtiqueta.ok => (AppColors.successLight, AppColors.successText),
      TonoEtiqueta.aviso => (AppColors.warningLight, AppColors.warningText),
      TonoEtiqueta.error => (AppColors.errorLight, AppColors.errorText),
      TonoEtiqueta.info => (AppColors.infoLight, AppColors.infoText),
      TonoEtiqueta.neutro => (AppColors.surfaceVariant, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(4)),
      child: Text(texto, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }
}

/// Botón de icono pequeño para las acciones de cada fila.
class AccionFila extends StatelessWidget {
  final IconData icono;
  final String ayuda;
  final VoidCallback? onPressed;
  final bool peligro;
  const AccionFila({super.key, required this.icono, required this.ayuda, this.onPressed, this.peligro = false});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: ayuda, // sin densidad compacta: 48 px, el mínimo cómodo para el dedo en tablet
      icon: Icon(icono, size: 19, color: peligro ? AppColors.errorText : AppColors.primary),
    );
  }
}

/// Columna de contenido de una pantalla: encabezado arriba y el cuerpo con
/// el margen del diseño (32 px en tablet).
class PantallaApolo extends StatelessWidget {
  final EncabezadoPantalla encabezado;
  final Widget cuerpo;
  final bool desplazable; // el cuerpo hace scroll completo (formularios)
  const PantallaApolo({super.key, required this.encabezado, required this.cuerpo, this.desplazable = false});

  @override
  Widget build(BuildContext context) {
    final margen = MediaQuery.sizeOf(context).width < 800 ? 16.0 : 32.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        encabezado,
        Expanded(
          child: desplazable
              ? SingleChildScrollView(padding: EdgeInsets.all(margen), child: cuerpo)
              : Padding(padding: EdgeInsets.all(margen), child: cuerpo),
        ),
      ],
    );
  }
}
