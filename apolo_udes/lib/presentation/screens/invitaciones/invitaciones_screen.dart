import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/email_service.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';

class InvitacionesScreen extends StatefulWidget {
  const InvitacionesScreen({super.key});

  @override
  State<InvitacionesScreen> createState() => _InvitacionesScreenState();
}

class _InvitacionesScreenState extends State<InvitacionesScreen> {
  final Set<String> _enviando = {};

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final invitaciones = provider.invitaciones;
    final isAdmin = provider.isAdmin;

    final confirmadas =
        invitaciones.where((i) => i.estado == EstadoInvitacion.confirmada).length;
    final rechazadas =
        invitaciones.where((i) => i.estado == EstadoInvitacion.rechazada).length;

    return Padding(
      padding: const EdgeInsets.all(28),
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
              ElevatedButton.icon(
                onPressed: () {
                  provider.enviarRecordatorios();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recordatorios enviados exitosamente'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Enviar recordatorios'),
              ),
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
                value:
                    '${invitaciones.where((i) => i.estado == EstadoInvitacion.pendiente).length}',
                color: AppColors.warning,
                icon: Icons.schedule_rounded,
              ),
              const SizedBox(width: 12),
              _MiniMetric(
                label: 'Enviadas',
                value:
                    '${invitaciones.where((i) => i.estado == EstadoInvitacion.enviada).length}',
                color: AppColors.info,
                icon: Icons.send_rounded,
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
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceVariant,
                              ),
                              children: [
                                'Invitado',
                                'Graduando',
                                'Tipo',
                                'Estado',
                                'Fecha Envío',
                                'Acción',
                              ]
                                  .map(
                                    (h) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      child: Text(
                                        h,
                                        style: AppTextStyles.label.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            ...invitaciones.asMap().entries.map((entry) {
                              final i = entry.key;
                              final inv = entry.value;
                              final estaEnviando = _enviando.contains(inv.id);

                              return TableRow(
                                decoration: BoxDecoration(
                                  color: i.isEven
                                      ? Colors.white
                                      : const Color(0xFFFAFBFC),
                                  border: const Border(
                                    bottom:
                                        BorderSide(color: AppColors.divider),
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        UserAvatar(name: inv.invitado, size: 30),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            inv.invitado,
                                            style: AppTextStyles.body,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _cell(inv.graduandoNombre),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: inv.tipo == TipoInvitacion.principal
                                            ? AppColors.primaryLight.withOpacity(0.1)
                                            : AppColors.pending.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        inv.tipo == TipoInvitacion.principal
                                            ? 'Principal'
                                            : 'Secundaria',
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    child: StatusBadge.fromEstadoInvitacion(inv.estado),
                                  ),
                                  _cell(
                                    inv.fechaEnvio != null
                                        ? DateFormat('dd/MM/yyyy').format(inv.fechaEnvio!)
                                        : '—',
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: estaEnviando
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primaryLight,
                                            ),
                                          )
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.send_rounded,
                                              size: 18,
                                            ),
                                            color: AppColors.primaryLight,
                                            tooltip: 'Enviar invitación por correo',
                                            onPressed: () =>
                                                _enviarInvitacion(context, inv),
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

  Future<void> _borrarTodas(BuildContext context, AppProvider provider) async {
    final cantidad = provider.invitaciones.length;
    final confirm = await showConfirmDialog(
      context,
      title: 'Borrar todas las invitaciones',
      content:
          '¿Está seguro de eliminar las $cantidad invitaciones? Esta acción quedará registrada en la auditoría.',
      confirmLabel: 'Borrar todas',
      isDangerous: true,
    );
    if (confirm == true && context.mounted) {
      provider.limpiarInvitaciones();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $cantidad invitaciones eliminadas'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _enviarInvitacion(BuildContext context, Invitacion inv) async {
    final provider = context.read<AppProvider>();

    final graduando = provider.graduandos.firstWhere(
      (g) => g.id == inv.graduandoId,
      orElse: () => provider.graduandos.first,
    );

    final correoDestino = await _pedirCorreo(context, inv.invitado);
    if (correoDestino == null || correoDestino.isEmpty) return;

    setState(() => _enviando.add(inv.id));

    try {
      final qrBase64 = await _generarQrBase64(inv.codigoQr ?? inv.id);

      final exito = await EmailService.enviarInvitacion(
        graduando: graduando,
        nombreInvitado: inv.invitado,
        correoInvitado: correoDestino,
        codigoQr: inv.codigoQr ?? inv.id,
        qrBase64: qrBase64,
        fechaCeremonia:
            DateFormat("EEEE d 'de' MMMM 'de' yyyy", 'es_CO')
                .format(DateTime.now().add(const Duration(days: 30))),
        invitadoId: inv.id, // ← botones Asistiré / No asistiré
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exito
                ? '✅ Invitación enviada a $correoDestino'
                : '❌ No se pudo enviar. Verifica las credenciales de correo.',
          ),
          backgroundColor: exito ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando.remove(inv.id));
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Future<String> _generarQrBase64(String data) async {
    final qrPainter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      color: const Color(0xFF0F2347),
      emptyColor: Colors.white,
    );

    final imageSize = const Size(200, 200);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    qrPainter.paint(canvas, imageSize);
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 200);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    return base64Encode(bytes);
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

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(label, style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}