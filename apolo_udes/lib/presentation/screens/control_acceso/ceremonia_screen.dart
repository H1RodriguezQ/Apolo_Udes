import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../navegacion.dart';
import '../../widgets/common/apolo_ui.dart';
import '../../widgets/common/grafico_barras.dart';
import '../../widgets/common/tarjeta.dart';
import 'control_acceso_screen.dart';

/// "Acceso a la ceremonia" (opción A del lienzo): en una sola pantalla el
/// lector de códigos a la izquierda y, a la derecha, lo que el administrador
/// vigila mientras la gente entra. Las cifras salen de las lecturas de hoy
/// que todas las tablets guardan en `validaciones`.
class CeremoniaScreen extends StatelessWidget {
  const CeremoniaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final lecturas = provider.lecturasDelDia;
    final validas = lecturas.where((l) => l.valida).toList();
    final aforo = provider.aforoDisponible;
    final ocupacion = aforo == 0 ? 0.0 : validas.length / aforo;

    // Ritmo de los últimos 10 minutos, total y por entrada.
    final hace10 = DateTime.now().subtract(const Duration(minutes: 10));
    final recientes = validas.where((l) => l.hora.isAfter(hace10)).toList();
    final puntos = {for (final l in validas) l.punto}.toList()..sort();
    final ritmo = recientes.length / 10;

    // Directivos: los códigos de directivo empiezan por "DIR-".
    final directivosConfirmados = provider.directivosConfirmados;
    final directivosAdentro = validas.where((l) => l.codigo.startsWith('DIR-')).length;

    final ancho = MediaQuery.sizeOf(context).width;
    final dosColumnas = ancho >= 1150;

    final cifras = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // El aviso solo sale cuando hay algo que avisar.
        if (ocupacion >= 0.9)
          _Aviso(
            titulo: 'Auditorio casi lleno',
            texto: 'Se llegó al ${(ocupacion * 100).round()} % de las sillas.',
            tono: TonoEtiqueta.error,
          )
        else if (ocupacion >= 0.75)
          const _Aviso(titulo: 'Atención', texto: 'El auditorio pasó el 75 % de ocupación.', tono: TonoEtiqueta.aviso),
        if (ocupacion >= 0.75) const SizedBox(height: 16),
        _filaCifras(ancho, [
          _TarjetaOcupacion(adentro: validas.length, aforo: aforo),
          Tarjeta(
            titulo: 'Ritmo de entrada',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NumeroGrande(numero: ritmo.toStringAsFixed(1), texto: 'por min'),
                const SizedBox(height: 8),
                if (puntos.isEmpty)
                  Text('Últimos 10 minutos.', style: AppTextStyles.bodySmall)
                else
                  Text(
                    [
                      'Últimos 10 min.',
                      for (final p in puntos)
                        '$p: ${(recientes.where((l) => l.punto == p).length / 10).toStringAsFixed(1)}',
                    ].join(' · '),
                    style: AppTextStyles.bodySmall,
                  ),
              ],
            ),
          ),
          Tarjeta(
            titulo: 'Directivos',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NumeroGrande(numero: '$directivosAdentro', texto: 'de $directivosConfirmados adentro'),
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => provider.setSelectedIndex(Nav.directivos),
                  child: const Text('Ver directivos', style: TextStyle(decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _TarjetaIngresos(validas: validas, puntos: puntos),
        const SizedBox(height: 16),
        _TarjetaLecturas(lecturas: lecturas),
      ],
    );

    // El lector es el mismo widget que usa el operador, en forma de panel.
    const lector = ControlAccesoScreen(enPanel: true);

    return PantallaApolo(
      desplazable: true,
      encabezado: EncabezadoPantalla(
        titulo: 'Acceso a la ceremonia',
        segundaLinea: 'Hoy, ${DateFormat("d 'de' MMMM", 'es_CO').format(DateTime.now())} · ${lecturas.length} lecturas en total',
        mostrarConexion: true,
        acciones: const [_SelectorPunto()],
      ),
      cuerpo: dosColumnas
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 450, child: lector),
                const SizedBox(width: 20),
                Expanded(child: cifras),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [lector, const SizedBox(height: 20), cifras],
            ),
    );
  }

  // Las tres tarjetas de cifras en fila y del mismo alto; en pantallas
  // angostas, una debajo de la otra.
  Widget _filaCifras(double ancho, List<Widget> tarjetas) {
    if (ancho < 700) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final t in tarjetas) ...[t, const SizedBox(height: 12)],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tarjetas.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            Expanded(child: tarjetas[i]),
          ],
        ],
      ),
    );
  }
}

/// "Leo en: Entrada 1 / 2". El operador ya tiene su entrada asignada; el
/// administrador escoge aquí en cuál está para que sus lecturas queden
/// guardadas con esa entrada.
class _SelectorPunto extends StatelessWidget {
  const _SelectorPunto();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    const opciones = AppProvider.puntosDeEntrada;
    if (!opciones.contains(provider.miPunto)) {
      return Text(provider.miPunto, style: AppTextStyles.label);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Leo en', style: AppTextStyles.label.copyWith(fontSize: 14)),
        const SizedBox(width: 8),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderFuerte),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: provider.miPunto,
              dropdownColor: AppColors.surface,
              style: AppTextStyles.body.copyWith(fontSize: 15),
              items: [
                for (final p in opciones) DropdownMenuItem(value: p, child: Text(p)),
              ],
              onChanged: (p) {
                if (p != null) provider.elegirPunto(p);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Número grande con su explicación al lado ("1.4 por minuto").
class _NumeroGrande extends StatelessWidget {
  final String numero;
  final String texto;
  const _NumeroGrande({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(numero, style: AppTextStyles.mono(size: 28, peso: FontWeight.w500)),
        const SizedBox(width: 8),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(texto, style: AppTextStyles.label.copyWith(fontSize: 14)),
          ),
        ),
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  final String titulo;
  final String texto;
  final TonoEtiqueta tono;
  const _Aviso({required this.titulo, required this.texto, required this.tono});

  @override
  Widget build(BuildContext context) {
    final (fondo, color, icono) = switch (tono) {
      TonoEtiqueta.error => (AppColors.errorLight, AppColors.errorText, Icons.error_outline),
      TonoEtiqueta.aviso => (AppColors.warningLight, AppColors.warningText, Icons.warning_amber_rounded),
      _ => (AppColors.successLight, AppColors.successText, Icons.check_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 12),
          Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: TextStyle(color: color, fontSize: 14))),
        ],
      ),
    );
  }
}

class _TarjetaOcupacion extends StatelessWidget {
  final int adentro;
  final int aforo;
  const _TarjetaOcupacion({required this.adentro, required this.aforo});

  @override
  Widget build(BuildContext context) {
    final f = aforo == 0 ? 0.0 : (adentro / aforo).clamp(0.0, 1.0);
    final color = f >= 0.9 ? AppColors.error : f >= 0.75 ? AppColors.warning : AppColors.success;
    return Tarjeta(
      titulo: 'Ocupación',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$adentro', style: AppTextStyles.mono(size: 28, peso: FontWeight.w500)),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 6),
                child: Text('/  $aforo', style: AppTextStyles.mono(size: 16, color: AppColors.textSecondary)),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${(f * 100).round()} %', style: AppTextStyles.mono(size: 15, peso: FontWeight.w500, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Barra con marcas en el 75 % (aviso) y el 90 % (tope).
          // Sin LayoutBuilder: la tarjeta va dentro de un IntrinsicHeight
          // (fila de cifras) y LayoutBuilder no puede medirse ahí.
          SizedBox(
            height: 14,
            child: Stack(
              children: [
                Positioned.fill(child: Container(color: AppColors.pista)),
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: f.clamp(0.0, 1.0),
                    child: Container(color: color),
                  ),
                ),
                for (final m in [0.75, 0.9])
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment(m * 2 - 1, 0),
                      child: Container(width: 2, color: AppColors.errorText),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('${(aforo - adentro).clamp(0, aforo)} sillas libres', style: AppTextStyles.bodySmall),
          Text('Aviso 75 % · tope 90 %', style: AppTextStyles.bodySmall.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Ingresos válidos cada 5 minutos. Cada barra se divide por entrada y
/// lleva encima el total de personas que entraron en esos 5 minutos.
class _TarjetaIngresos extends StatelessWidget {
  final List<LecturaDia> validas;
  final List<String> puntos;
  const _TarjetaIngresos({required this.validas, required this.puntos});

  @override
  Widget build(BuildContext context) {
    final colores = [AppColors.isDark ? const Color(0xFF5F97E2) : AppColors.serie1, AppColors.serie2];
    if (validas.isEmpty) {
      return Tarjeta(
        titulo: 'Ingresos cada 5 minutos',
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text('Todavía no ha entrado nadie hoy.\nCuando empiecen a leer códigos, aquí se verá cuánta gente entra cada 5 minutos.',
                textAlign: TextAlign.center, style: AppTextStyles.label.copyWith(height: 1.6)),
          ),
        ),
      );
    }

    // Se agrupan las lecturas en bloques de 5 minutos (7:00, 7:05, 7:10...).
    DateTime bloque(DateTime h) => DateTime(h.year, h.month, h.day, h.hour, h.minute - h.minute % 5);
    var desde = bloque(validas.map((l) => l.hora).reduce((a, b) => a.isBefore(b) ? a : b));
    final hasta = bloque(DateTime.now());
    // Máximo 18 barras (hora y media): si la ceremonia va más larga, se muestran las últimas.
    if (hasta.difference(desde).inMinutes > 17 * 5) desde = hasta.subtract(const Duration(minutes: 17 * 5));
    final bloques = <DateTime>[];
    for (var t = desde; !t.isAfter(hasta); t = t.add(const Duration(minutes: 5))) {
      bloques.add(t);
    }

    // valores[i][k] = personas que entraron en el bloque i por la entrada k.
    final valores = [for (final _ in bloques) List<int>.filled(puntos.length, 0)];
    for (final l in validas) {
      final i = bloques.indexOf(bloque(l.hora));
      if (i >= 0) valores[i][puntos.indexOf(l.punto)]++;
    }
    final totales = [for (final v in valores) v.fold<int>(0, (a, b) => a + b)];

    // Hora pico: el bloque con más entradas.
    var pico = 0;
    for (var i = 1; i < totales.length; i++) {
      if (totales[i] > totales[pico]) pico = i;
    }
    String rango(int i) =>
        '${DateFormat('H:mm').format(bloques[i])} a ${DateFormat('H:mm').format(bloques[i].add(const Duration(minutes: 5)))}';

    return Tarjeta(
      titulo: 'Ingresos cada 5 minutos',
      accion: Wrap(
        spacing: 14,
        children: [
          for (var k = 0; k < puntos.length; k++) Leyenda(color: colores[k % 2], texto: puntos[k]),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GraficoBarras(
            valores: valores,
            // Con muchas barras, la hora solo se escribe una sí y otra no
            // (la última, la de ahora, siempre se escribe).
            etiquetas: [
              for (var i = 0; i < bloques.length; i++)
                bloques.length > 12 && i.isOdd && i != bloques.length - 1
                    ? ''
                    : DateFormat('H:mm').format(bloques[i]),
            ],
            colores: colores,
            alto: 140,
            resaltada: bloques.length - 1,
            detalle: (i) => [
              rango(i),
              for (var k = 0; k < puntos.length; k++) '${puntos[k]}: ${valores[i][k]}',
            ].join('\n'),
          ),
          const SizedBox(height: 12),
          Text(
            'Hora pico: de ${rango(pico)}, con ${totales[pico]} personas. '
            'La última barra son los 5 minutos que van corriendo.',
            style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Últimas lecturas de las dos entradas, buenas y malas, con el total de
/// rechazadas arriba.
class _TarjetaLecturas extends StatelessWidget {
  final List<LecturaDia> lecturas;
  const _TarjetaLecturas({required this.lecturas});

  @override
  Widget build(BuildContext context) {
    final rechazadas = lecturas.where((l) => !l.valida).length;
    return Tarjeta(
      titulo: 'Últimas lecturas (las dos entradas)',
      accion: Text('$rechazadas rechazada${rechazadas == 1 ? '' : 's'} hoy', style: AppTextStyles.label),
      lineaBajoTitulo: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lecturas.isEmpty)
            Padding(padding: const EdgeInsets.all(24), child: Text('Todavía no hay lecturas hoy.', style: AppTextStyles.label)),
          for (final l in lecturas.take(6))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
              child: Row(
                children: [
                  Text(DateFormat('HH:mm').format(l.hora), style: AppTextStyles.mono(size: 14)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CeldaTexto(l.nombre.isEmpty ? 'Sin identificar' : l.nombre,
                        debajo: '${l.punto} · ${l.operador}'),
                  ),
                  l.valida
                      ? const Etiqueta('Válido', tono: TonoEtiqueta.ok)
                      : l.resultado == 'usado'
                          ? const Etiqueta('Ya usado', tono: TonoEtiqueta.aviso)
                          : const Etiqueta('No válido', tono: TonoEtiqueta.error),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
