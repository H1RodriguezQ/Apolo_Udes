import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/tarjeta.dart';
import '../../widgets/common/apolo_ui.dart';
import '../../widgets/common/grafico_barras.dart';
import '../../navegacion.dart';

/// Pantalla de Inicio (rediseño). Responde lo que el administrador necesita
/// saber antes del grado: cuándo y dónde es la ceremonia, cómo van las
/// invitaciones, qué requiere atención y qué se hizo hace poco.
///
/// Índices del menú del administrador (ver home_screen.dart) a los que
/// llevan los enlaces de "Requiere atención".
const _irGraduandos = Nav.graduandos;
const _irCorreos = Nav.recordatorio;
const _irBitacora = Nav.bitacora;
const _irAjustes = Nav.ajustes;

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final ancho = MediaQuery.sizeOf(context).width;
    final dosColumnas = ancho >= 1100;

    final izquierda = [
      const _TarjetaEvento(),
      const SizedBox(height: 20),
      _TarjetaAvance(provider: provider),
      const SizedBox(height: 20),
      _TarjetaAtencion(provider: provider),
    ];
    final derecha = [
      _TarjetaPorDia(invitaciones: provider.invitaciones),
      const SizedBox(height: 20),
      provider.isAdmin ? const _TarjetaBitacora() : _TarjetaUltimasLecturas(registros: provider.registrosAcceso),
    ];

    return PantallaApolo(
      desplazable: true,
      encabezado: EncabezadoPantalla(
        titulo: 'Inicio',
        detalle: DateFormat("EEEE d 'de' MMMM", 'es_CO').format(DateTime.now()),
      ),
      cuerpo: dosColumnas
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: Column(children: izquierda)),
                const SizedBox(width: 24),
                Expanded(flex: 2, child: Column(children: derecha)),
              ],
            )
          : Column(children: [...izquierda, const SizedBox(height: 20), ...derecha]),
    );
  }
}

// ── Próxima ceremonia ──────────────────────────────────────────────────────

class _TarjetaEvento extends StatelessWidget {
  const _TarjetaEvento();

  @override
  Widget build(BuildContext context) {
    final esAdmin = context.watch<AppProvider>().isAdmin;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('configuracion').doc('evento').snapshots(),
      builder: (context, snap) {
        final datos = snap.data?.data() ?? {};
        final cuando = datos['fechaCeremonia'] is Timestamp ? (datos['fechaCeremonia'] as Timestamp).toDate() : null;
        final fecha = cuando == null ? null : DateFormat("EEEE d 'de' MMMM", 'es_CO').format(cuando);
        // La hora solo si se configuró (una fecha sin hora queda a las 00:00).
        final hora = cuando == null || (cuando.hour == 0 && cuando.minute == 0)
            ? null
            : DateFormat('h:mm a', 'es_CO').format(cuando);
        final lugar = (datos['lugarCeremonia'] ?? datos['lugar'] ?? '') as String;
        final aforo = datos['aforoDisponible'];

        final columnaFecha = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DatoEtiquetado(
              etiqueta: 'Próxima ceremonia',
              valor: fecha == null ? 'Fecha por confirmar' : _mayuscula(fecha),
              nota: hora,
            ),
            if (fecha == null && esAdmin)
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => context.read<AppProvider>().setSelectedIndex(_irAjustes),
                child: const Text('Configurar fecha'),
              ),
          ],
        );
        final columnaLugar = DatoEtiquetado(etiqueta: 'Lugar', valor: lugar.isEmpty ? 'Por definir' : lugar);
        final columnaAforo = DatoEtiquetado(
          etiqueta: 'Sillas del auditorio',
          valor: aforo == null ? '—' : '$aforo',
          nota: '2 invitados por graduando',
          mono: true,
        );

        return Tarjeta(
          // Ancho: los tres datos en una fila y el lugar con más espacio (antes
          // tenía 220 px fijos, se partía en 4 líneas y dejaba un hueco al lado).
          child: LayoutBuilder(
            builder: (context, caja) => caja.maxWidth >= 480
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: columnaFecha),
                      const SizedBox(width: 24),
                      Expanded(flex: 4, child: columnaLugar),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: columnaAforo),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      columnaFecha,
                      const SizedBox(height: 16),
                      columnaLugar,
                      const SizedBox(height: 16),
                      columnaAforo
                    ],
                  ),
          ),
        );
      },
    );
  }

  String _mayuscula(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

// ── Avance de las invitaciones ──────────────────────────────────────────────

class _TarjetaAvance extends StatelessWidget {
  final AppProvider provider;
  const _TarjetaAvance({required this.provider});

  @override
  Widget build(BuildContext context) {
    final graduandos = provider.graduandos.length;
    final conInvitados = provider.invitaciones.map((i) => i.graduandoId).toSet().length;
    final vivas = provider.invitaciones.where((i) => i.estado != EstadoInvitacion.anulada).toList();
    final cupos = graduandos * 2;
    final confirmadas = vivas.where((i) => i.estado == EstadoInvitacion.confirmada).length;

    return Tarjeta(
      titulo: 'Avance de las invitaciones',
      child: Column(
        children: [
          BarraAvance(nombre: 'Graduandos con invitados', valor: conInvitados, total: graduandos),
          BarraAvance(nombre: 'Cupos de invitado ocupados', valor: vivas.length, total: cupos),
          BarraAvance(nombre: 'Asistencias confirmadas', valor: confirmadas, total: vivas.length),
        ],
      ),
    );
  }
}

// ── Requiere atención ──────────────────────────────────────────────────────

class _TarjetaAtencion extends StatelessWidget {
  final AppProvider provider;
  const _TarjetaAtencion({required this.provider});

  @override
  Widget build(BuildContext context) {
    final conInvitados = provider.invitaciones.map((i) => i.graduandoId).toSet();
    final sinInvitados = provider.graduandos.where((g) => !conInvitados.contains(g.id)).length;
    final correosConError = provider.graduandos.where((g) => g.correoRegistro == 'error').length +
        provider.directivos.where((d) => d.correoInvitacion == 'error').length;
    final sinConfirmar = provider.invitaciones
        .where((i) => i.estado == EstadoInvitacion.enviada || i.estado == EstadoInvitacion.pendiente)
        .length;

    final filas = [
      (
        sinInvitados,
        'Graduandos que no han registrado invitados',
        'Ver graduandos',
        _irGraduandos,
        AppColors.warningLight,
        AppColors.warningText
      ),
      (
        correosConError,
        'Correos que no se pudieron enviar',
        'Revisar',
        _irGraduandos,
        AppColors.errorLight,
        AppColors.errorText
      ),
      (
        sinConfirmar,
        'Invitados sin confirmar asistencia',
        'Enviar recordatorio',
        _irCorreos,
        AppColors.infoLight,
        AppColors.infoText
      ),
    ];

    return Tarjeta(
      titulo: 'Requiere atención',
      lineaBajoTitulo: true,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final f in filas)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    // En 0 no hay nada que atender: color neutro en vez de alarma.
                    decoration: BoxDecoration(color: f.$1 > 0 ? f.$5 : AppColors.pista, borderRadius: BorderRadius.circular(4)),
                    child: Text('${f.$1}', style: AppTextStyles.mono(size: 15, peso: FontWeight.w500, color: f.$1 > 0 ? f.$6 : AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text(f.$2, style: AppTextStyles.body.copyWith(fontSize: 15))),
                  if (provider.isAdmin && f.$1 > 0)
                    TextButton(
                      onPressed: () => provider.setSelectedIndex(f.$4),
                      child: Text(f.$3, style: const TextStyle(decoration: TextDecoration.underline)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Invitados registrados por día (últimos 7 días) ──────────────────────────

class _TarjetaPorDia extends StatelessWidget {
  final List<Invitacion> invitaciones;
  const _TarjetaPorDia({required this.invitaciones});

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);

    // conteo[6] es hoy, conteo[5] ayer, y así hacia atrás.
    final conteo = List<int>.filled(7, 0);
    for (final inv in invitaciones) {
      final f = inv.fechaEnvio;
      if (f == null) continue;
      final hace = inicioHoy.difference(DateTime(f.year, f.month, f.day)).inDays;
      if (hace >= 0 && hace < 7) conteo[6 - hace]++;
    }
    final dias = [for (var i = 0; i < 7; i++) inicioHoy.subtract(Duration(days: 6 - i))];
    final total = conteo.fold<int>(0, (a, b) => a + b);

    // Día con más registros, para decirlo en palabras debajo del gráfico.
    var mejor = 0;
    for (var i = 1; i < 7; i++) {
      if (conteo[i] > conteo[mejor]) mejor = i;
    }
    String nombreDia(int i) => i == 6
        ? 'hoy'
        : i == 5
            ? 'ayer'
            : DateFormat("EEEE d", 'es_CO').format(dias[i]);

    return Tarjeta(
      titulo: 'Invitados registrados por día',
      accion: Text('Últimos 7 días', style: AppTextStyles.label),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GraficoBarras(
            valores: [
              for (final c in conteo) [c]
            ],
            etiquetas: [
              for (var i = 0; i < 7; i++)
                i == 6 ? 'hoy' : DateFormat('E d', 'es_CO').format(dias[i]).replaceAll('.', ''),
            ],
            colores: [AppColors.isDark ? const Color(0xFF5F97E2) : AppColors.serie1],
            alto: 120,
            resaltada: 6,
            textoVacio: 'Nadie registró invitados esta semana.',
            detalle: (i) => '${conteo[i]} invitado${conteo[i] == 1 ? '' : 's'} el ${nombreDia(i)}',
          ),
          const SizedBox(height: 12),
          Text(
            total == 0
                ? 'Cuando los graduandos registren invitados, aquí se verá cuántos hubo cada día.'
                : '$total en la semana. El día con más registros fue ${nombreDia(mejor)} (${conteo[mejor]}).',
            style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Bitácora (solo administrador: las reglas no dejan que el operador la lea) ─

class _TarjetaBitacora extends StatelessWidget {
  const _TarjetaBitacora();

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      titulo: 'Bitácora',
      lineaBajoTitulo: true,
      padding: EdgeInsets.zero,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('auditoria').orderBy('fecha', descending: true).limit(5).snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Todavía no hay movimientos.', style: AppTextStyles.label),
                ),
              for (final d in docs) _FilaBitacora(datos: d.data()),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.read<AppProvider>().setSelectedIndex(_irBitacora),
                    child: const Text('Ver toda la bitácora', style: TextStyle(decoration: TextDecoration.underline)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilaBitacora extends StatelessWidget {
  final Map<String, dynamic> datos;
  const _FilaBitacora({required this.datos});

  @override
  Widget build(BuildContext context) {
    final fecha = datos['fecha'] is Timestamp ? (datos['fecha'] as Timestamp).toDate() : null;
    final hora = fecha == null ? '' : DateFormat('HH:mm').format(fecha);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${datos['accion'] ?? ''}', style: AppTextStyles.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(hora, style: AppTextStyles.mono(size: 12, color: AppColors.textSecondary)),
              Flexible(
                child: Text(' · ${datos['autorCorreo'] ?? ''}',
                    style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Para el operador: sus últimas lecturas en lugar de la bitácora ──────────

class _TarjetaUltimasLecturas extends StatelessWidget {
  final List<RegistroAcceso> registros;
  const _TarjetaUltimasLecturas({required this.registros});

  @override
  Widget build(BuildContext context) {
    final ultimos = registros.take(6).toList();
    return Tarjeta(
      titulo: 'Últimas lecturas',
      lineaBajoTitulo: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ultimos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Aún no se ha leído ningún código en este turno.', style: AppTextStyles.label),
            ),
          for (final r in ultimos)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
              child: Row(
                children: [
                  Text(DateFormat('HH:mm').format(r.horaAcceso), style: AppTextStyles.mono(size: 14)),
                  const SizedBox(width: 16),
                  Expanded(child: Text(r.nombre.isEmpty ? 'Sin identificar' : r.nombre, style: AppTextStyles.body)),
                  _Etiqueta(valido: r.valido),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final bool valido;
  const _Etiqueta({required this.valido});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: valido ? AppColors.successLight : AppColors.errorLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        valido ? 'Válido' : 'No válido',
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: valido ? AppColors.successText : AppColors.errorText),
      ),
    );
  }
}
