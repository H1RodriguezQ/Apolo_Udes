import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';
import '../../widgets/common/apolo_ui.dart';
import '../../navegacion.dart';

class InvitacionesScreen extends StatefulWidget {
  const InvitacionesScreen({super.key});

  @override
  State<InvitacionesScreen> createState() => _InvitacionesScreenState();
}

class _InvitacionesScreenState extends State<InvitacionesScreen> {
  final Set<String> _enviando = {};

  String _filtro = 'todos';
  String _busqueda = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final invitaciones = provider.invitaciones;
    final isAdmin = provider.isAdmin;

    // La cédula está en la lista de confirmaciones (mismo id de documento).
    final cedulas = {for (final c in provider.confirmaciones) c.id: c.documento};
    final graduandos = invitaciones.map((i) => i.graduandoId).toSet().length;

    bool sinConfirmar(Invitacion i) =>
        i.estado == EstadoInvitacion.enviada || i.estado == EstadoInvitacion.pendiente;
    final cuenta = {
      'todos': invitaciones.where((i) => i.estado != EstadoInvitacion.anulada).length,
      'confirmaron': invitaciones.where((i) => i.estado == EstadoInvitacion.confirmada).length,
      'sin': invitaciones.where(sinConfirmar).length,
      'no': invitaciones.where((i) => i.estado == EstadoInvitacion.rechazada).length,
      'anulados': invitaciones.where((i) => i.estado == EstadoInvitacion.anulada).length,
    };

    final q = _busqueda.trim().toLowerCase();
    final filtradas = invitaciones.where((i) {
      final pasa = switch (_filtro) {
        'confirmaron' => i.estado == EstadoInvitacion.confirmada,
        'sin' => sinConfirmar(i),
        'no' => i.estado == EstadoInvitacion.rechazada,
        'anulados' => i.estado == EstadoInvitacion.anulada,
        _ => i.estado != EstadoInvitacion.anulada,
      };
      if (!pasa) return false;
      if (q.isEmpty) return true;
      return i.invitado.toLowerCase().contains(q) ||
          i.graduandoNombre.toLowerCase().contains(q) ||
          (cedulas[i.id] ?? '').contains(q);
    }).toList();

    return PantallaApolo(
      encabezado: EncabezadoPantalla(
        titulo: 'Invitados',
        detalle: '${cuenta['todos']} registrados por $graduandos graduandos',
        acciones: [
          if (isAdmin && invitaciones.isNotEmpty)
            BotonSecundario(texto: 'Borrar todas', peligro: true, onPressed: () => _borrarTodas(context, provider)),
          if (isAdmin)
            BotonSecundario(
              texto: 'Enviar recordatorio',
              onPressed: () => provider.setSelectedIndex(Nav.recordatorio),
            ),
        ],
      ),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: FiltroSegmentado<String>(
                    valor: _filtro,
                    onChanged: (v) => setState(() => _filtro = v),
                    opciones: [
                      ('todos', 'Todos', cuenta['todos']),
                      ('confirmaron', 'Confirmaron', cuenta['confirmaron']),
                      ('sin', 'Sin confirmar', cuenta['sin']),
                      ('no', 'No asistirán', cuenta['no']),
                      ('anulados', 'Anulados', cuenta['anulados']),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 260,
                child: CampoConEtiqueta(
                  etiqueta: 'Buscar',
                  campo: CampoBusqueda(
                    hint: 'Invitado, cédula o graduando',
                    onChanged: (v) => setState(() => _busqueda = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TablaApolo(
              vacio: 'No hay invitados con ese filtro.',
              columnas: const [
                ColumnaTabla('Invitado', flex: 4),
                ColumnaTabla('Graduando', flex: 4),
                ColumnaTabla('Registrado', flex: 2),
                ColumnaTabla('Asistencia', flex: 2),
                ColumnaTabla('Acciones', flex: 2, derecha: true),
              ],
              filas: [
                for (final inv in filtradas)
                  [
                    CeldaTexto(inv.invitado,
                        debajo: [
                          if ((cedulas[inv.id] ?? '').isNotEmpty) 'C.C. ${cedulas[inv.id]}',
                          inv.tipo == TipoInvitacion.secundaria ? 'Segundo cupo' : 'Primer cupo',
                        ].join(' · '),
                        fuerte: true),
                    CeldaTexto(inv.graduandoNombre),
                    CeldaTexto(inv.fechaEnvio == null ? '' : DateFormat('dd/MM/yyyy').format(inv.fechaEnvio!), mono: true),
                    switch (inv.estado) {
                      EstadoInvitacion.confirmada => const Etiqueta('Confirmó', tono: TonoEtiqueta.ok),
                      EstadoInvitacion.rechazada => const Etiqueta('No asistirá', tono: TonoEtiqueta.error),
                      EstadoInvitacion.anulada => const Etiqueta('Anulado'),
                      _ => const Etiqueta('Sin confirmar', tono: TonoEtiqueta.aviso),
                    },
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isAdmin && inv.estado != EstadoInvitacion.anulada)
                          _enviando.contains(inv.id)
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                              : AccionFila(
                                  icono: Icons.mail_outline,
                                  ayuda: 'Reenviar la invitación',
                                  onPressed: () => _enviarInvitacion(context, inv),
                                ),
                        if (isAdmin && inv.estado != EstadoInvitacion.anulada)
                          AccionFila(
                            icono: Icons.block_rounded,
                            ayuda: 'Anular invitado',
                            peligro: true,
                            onPressed: () => _anularInvitado(context, inv),
                          ),
                      ],
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _borrarTodas(BuildContext context, AppProvider provider) async {
    final cantidad = provider.invitaciones.length;
    final confirm = await showConfirmDialog(
      context,
      title: 'Borrar todas las invitaciones',
      content: '¿Está seguro de eliminar las $cantidad invitaciones? Esta acción quedará registrada en la auditoría.',
      confirmLabel: 'Borrar todas',
      isDangerous: true,
    );
    if (confirm == true && context.mounted) {
      provider.limpiarInvitaciones();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ $cantidad invitaciones eliminadas'), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _enviarInvitacion(BuildContext context, Invitacion inv) async {
    final provider = context.read<AppProvider>();

    // Se puede corregir el correo antes de pedir el reenvío: si el invitado
    // escribió mal su dirección, así se arregla sin borrar la invitación.
    final correoDestino = await _pedirCorreo(context, inv.invitado);
    if (correoDestino == null || correoDestino.isEmpty) return;

    setState(() => _enviando.add(inv.id));

    try {
      await provider.solicitarReenvioInvitacion(
        invitadoId: inv.id,
        nombre: inv.invitado,
        correo: correoDestino,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // El envío lo hace el servidor de correos (Apps Script), no la app.
          content: Text('✅ Solicitud enviada: el servidor reenviará la invitación en unos minutos.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _enviando.remove(inv.id));
    }
  }

  /// Pide confirmación y anula el invitado. La operación completa (anular +
  /// liberar cupo + renumerar) es UNA transacción en el servicio: o pasa todo
  /// o no pasa nada, para que no quede un cupo ocupado a medias.
  Future<void> _anularInvitado(BuildContext context, Invitacion inv) async {
    // Se captura antes del `await` para no usar el contexto después de un
    // salto asíncrono.
    final provider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final motivo = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular invitado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se anulará a ${inv.invitado} y su cupo quedará libre para '
              'otra persona.',
            ),
            const SizedBox(height: 8),
            const Text(
              'El registro NO se borra: se conserva como "anulado" con su '
              'motivo para dejar constancia, y ya no podrá volver a '
              'registrarse con este enlace.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivo,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Cambio de invitado, error de registro…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Anular'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;
    try {
      final ocupados =
          await provider.anularInvitado(inv, motivo: motivo.text.trim());
      messenger.showSnackBar(
        SnackBar(
          content: Text('Invitado anulado. Cupos ocupados: $ocupados'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo anular: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      motivo.dispose();
    }
  }

  Future<String?> _pedirCorreo(BuildContext context, String nombre) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Correo de $nombre'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'correo@ejemplo.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Enviar')),
        ],
      ),
    );
  }

}

