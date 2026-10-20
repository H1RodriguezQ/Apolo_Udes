import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';

class InvitacionesScreen extends StatefulWidget {
  const InvitacionesScreen({super.key});

  @override
  State<InvitacionesScreen> createState() => _InvitacionesScreenState();
}

class _InvitacionesScreenState extends State<InvitacionesScreen> {
  final Set<String> _enviando = {};
  bool _enviandoRecordatorios = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final invitaciones = provider.invitaciones;
    final isAdmin = provider.isAdmin;

    final confirmadas =
        invitaciones.where((i) => i.estado == EstadoInvitacion.confirmada).length;
    final rechazadas =
        invitaciones.where((i) => i.estado == EstadoInvitacion.rechazada).length;

    final isMobile = MediaQuery.of(context).size.width < 600;
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  title: 'Invitaciones',
                  subtitle: '${invitaciones.length} invitaciones registradas',
                ),
              ),
              if (isAdmin && invitaciones.isNotEmpty) ...[
                ElevatedButton.icon(
                  onPressed: () => _borrarTodas(context, provider),
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: const Text('Borrar todas'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // Solo el administrador pide correos: los envía el servidor y
              // las reglas de Firestore no aceptan peticiones de otros roles.
              if (isAdmin && invitaciones.isNotEmpty) ...[
                ElevatedButton.icon(
                  onPressed: _enviandoRecordatorios ? null : () => _enviarRecordatorios(context, provider),
                  icon: _enviandoRecordatorios
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_enviandoRecordatorios ? 'Enviando...' : 'Enviar recordatorios'),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              _MiniMetric(
                label: 'Confirmadas',
                value: '$confirmadas',
                color: AppColors.success,
                icon: Icons.check_circle_rounded,
              ),
              const SizedBox(width: 12),
              _MiniMetric(
                label: 'Rechazadas',
                value: '$rechazadas',
                color: AppColors.error,
                icon: Icons.cancel_rounded,
              ),
              const SizedBox(width: 12),
              _MiniMetric(
                label: 'Pendientes',
                value: '${invitaciones.where((i) => i.estado == EstadoInvitacion.pendiente).length}',
                color: AppColors.warning,
                icon: Icons.schedule_rounded,
              ),
              const SizedBox(width: 12),
              _MiniMetric(
                label: 'Enviadas',
                value: '${invitaciones.where((i) => i.estado == EstadoInvitacion.enviada).length}',
                color: AppColors.info,
                icon: Icons.send_rounded,
              ),
              const SizedBox(width: 12),
              // Las anuladas se cuentan aparte de las rechazadas: las anula
              // la universidad (y su cupo quedó libre), las rechaza el invitado.
              _MiniMetric(
                label: 'Anuladas',
                value: '${invitaciones.where((i) => i.estado == EstadoInvitacion.anulada).length}',
                color: AppColors.textSecondary,
                icon: Icons.block_rounded,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Expanded(
            child: Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: invitaciones.isEmpty
                    ? const EmptyState(
                        icon: Icons.mail_outline_rounded,
                        title: 'Sin invitaciones',
                        subtitle: 'Las invitaciones aparecerán aquí',
                      )
                    : isMobile
                        ? _InvitacionesList(
                            invitaciones: invitaciones,
                            enviando: _enviando,
                            onEnviar: (inv) => _enviarInvitacion(context, inv),
                            onAnular: (inv) => _anularInvitado(context, inv),
                            puedeEnviar: isAdmin,
                          )
                        : SingleChildScrollView(
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2.5),
                            1: FlexColumnWidth(2.5),
                            2: FlexColumnWidth(1.5),
                            3: FlexColumnWidth(1.5),
                            4: FlexColumnWidth(1.5),
                            5: FlexColumnWidth(1.2),
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(color: AppColors.surfaceVariant),
                              children: ['Invitado', 'Graduando', 'Tipo', 'Estado', 'Fecha Envío', 'Acción']
                                  .map((h) => Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                        child: Text(h, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                      ))
                                  .toList(),
                            ),
                            ...invitaciones.asMap().entries.map((entry) {
                              final i = entry.key;
                              final inv = entry.value;
                              final estaEnviando = _enviando.contains(inv.id);

                              return TableRow(
                                decoration: BoxDecoration(
                                  color: i.isEven ? Colors.white : const Color(0xFFFAFBFC),
                                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        UserAvatar(name: inv.invitado, size: 30),
                                        const SizedBox(width: 10),
                                        Expanded(child: Text(inv.invitado, style: AppTextStyles.body)),
                                      ],
                                    ),
                                  ),
                                  _cell(inv.graduandoNombre),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: inv.tipo == TipoInvitacion.principal
                                            ? AppColors.primaryLight.withValues(alpha: 0.1)
                                            : AppColors.pending.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        inv.tipo == TipoInvitacion.principal ? 'Principal' : 'Secundaria',
                                        style: TextStyle(
                                          color: inv.tipo == TipoInvitacion.principal
                                              ? AppColors.primaryLight
                                              : AppColors.pending,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: StatusBadge.fromEstadoInvitacion(inv.estado),
                                  ),
                                  _cell(inv.fechaEnvio != null
                                      ? DateFormat('dd/MM/yyyy').format(inv.fechaEnvio!)
                                      : '—'),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: !isAdmin || inv.estado == EstadoInvitacion.anulada
                                        // Reenviar y anular son acciones de
                                        // administrador; un anulado ya no
                                        // recibe ningún correo.
                                        ? const SizedBox.shrink()
                                        : estaEnviando
                                            ? const SizedBox(
                                                width: 20, height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                                              )
                                            : Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.send_rounded, size: 18),
                                                    color: AppColors.primaryLight,
                                                    tooltip: 'Enviar invitación por correo',
                                                    onPressed: () => _enviarInvitacion(context, inv),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.block_rounded, size: 18),
                                                    color: AppColors.error,
                                                    tooltip: 'Anular invitado y liberar su cupo',
                                                    onPressed: () => _anularInvitado(context, inv),
                                                  ),
                                                ],
                                              ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _enviarRecordatorios(BuildContext context, AppProvider provider) async {
    setState(() => _enviandoRecordatorios = true);
    try {
      await provider.enviarRecordatorios();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // El servidor es quien manda los correos: aquí solo se pidió.
          content: Text('✅ Recordatorio en cola. El servidor lo enviará en unos minutos.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _enviandoRecordatorios = false);
    }
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

  Widget _cell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text, style: AppTextStyles.body),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MiniMetric({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
                  Text(label, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitacionesList extends StatelessWidget {
  final List<Invitacion> invitaciones;
  final Set<String> enviando;
  final Function(Invitacion) onEnviar;

  /// Anular también es una acción de administrador: libera cupos y deja
  /// registro en la bitácora.
  final Function(Invitacion) onAnular;

  /// Solo el administrador puede pedirle al servidor que reenvíe un correo.
  final bool puedeEnviar;

  const _InvitacionesList({
    required this.invitaciones,
    required this.enviando,
    required this.onEnviar,
    required this.onAnular,
    required this.puedeEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: invitaciones.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final inv = invitaciones[i];
        final estaEnviando = enviando.contains(inv.id);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              UserAvatar(name: inv.invitado, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.invitado, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                    if (inv.graduandoNombre.isNotEmpty)
                      Text(inv.graduandoNombre, style: AppTextStyles.bodySmall),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: inv.tipo == TipoInvitacion.principal
                              ? AppColors.primaryLight.withValues(alpha: 0.1)
                              : AppColors.pending.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          inv.tipo == TipoInvitacion.principal ? 'Principal' : 'Secundaria',
                          style: TextStyle(color: inv.tipo == TipoInvitacion.principal ? AppColors.primaryLight : AppColors.pending, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      StatusBadge.fromEstadoInvitacion(inv.estado),
                    ]),
                  ],
                ),
              ),
              if (!puedeEnviar || inv.estado == EstadoInvitacion.anulada)
                const SizedBox.shrink()
              else if (estaEnviando)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight))
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.send_rounded, size: 18),
                      color: AppColors.primaryLight,
                      tooltip: 'Enviar invitación por correo',
                      onPressed: () => onEnviar(inv),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: const Icon(Icons.block_rounded, size: 18),
                      color: AppColors.error,
                      tooltip: 'Anular invitado y liberar su cupo',
                      onPressed: () => onAnular(inv),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
