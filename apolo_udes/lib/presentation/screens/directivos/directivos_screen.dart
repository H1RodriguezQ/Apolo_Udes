import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';

class DirectivosScreen extends StatelessWidget {
  const DirectivosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final directivos = provider.directivos;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    final confirmados =
        directivos.where((d) => d.estado == EstadoDirectivo.confirmado).length;
    final pendientes =
        directivos.where((d) => d.estado == EstadoDirectivo.pendiente).length;
    final rechazados =
        directivos.where((d) => d.estado == EstadoDirectivo.rechazado).length;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header responsive
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Directivos',
                  subtitle: 'Gestión de directivos y autoridades UDES',
                ),
                const SizedBox(height: 12),
                if (provider.isAdmin)
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddDialog(context),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Agregar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (directivos.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _limpiarTodo(context, provider),
                          icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                          label: const Text('Limpiar'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error),
                        ),
                      ),
                  ])
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.visibility_outlined,
                          size: 16, color: AppColors.warning),
                      SizedBox(width: 6),
                      Text('Solo lectura',
                          style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ],
            )
          else
            Row(
              children: [
                const Expanded(
                  child: SectionHeader(
                    title: 'Directivos',
                    subtitle: 'Gestión de directivos y autoridades UDES',
                  ),
                ),
                if (provider.isAdmin) ...[
                  ElevatedButton.icon(
                    onPressed: () => _showAddDialog(context),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar Directivo'),
                  ),
                  const SizedBox(width: 8),
                  if (directivos.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () => _limpiarTodo(context, provider),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('Limpiar'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error),
                    ),
                ] else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.visibility_outlined,
                          size: 16, color: AppColors.warning),
                      SizedBox(width: 6),
                      Text('Solo lectura',
                          style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
              ],
            ),
          const SizedBox(height: 20),

          // Tabla o lista
          Expanded(
            child: Card(
              child: directivos.isEmpty
                  ? const EmptyState(
                      icon: Icons.person_outline_rounded,
                      title: 'No hay directivos',
                      subtitle: 'Agrega directivos para gestionar invitaciones',
                    )
                  : isMobile
                      ? _DirectivosList(directivos: directivos)
                      : _DirectivosTable(directivos: directivos),
            ),
          ),

          const SizedBox(height: 16),

          // Métricas
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: isMobile ? 1.6 : 2.0,
            children: [
              _MetricCard(
                  title: 'Total',
                  value: directivos.length.toString(),
                  color: AppColors.primaryLight,
                  icon: Icons.group_outlined),
              _MetricCard(
                  title: 'Confirmados',
                  value: confirmados.toString(),
                  color: AppColors.success,
                  icon: Icons.check_circle_outline),
              _MetricCard(
                  title: 'Pendientes',
                  value: pendientes.toString(),
                  color: AppColors.warning,
                  icon: Icons.access_time_outlined),
              _MetricCard(
                  title: 'Rechazados',
                  value: rechazados.toString(),
                  color: AppColors.error,
                  icon: Icons.cancel_outlined),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DirectivoDialog(),
    );
  }

  Future<void> _limpiarTodo(BuildContext context, AppProvider provider) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Limpiar directivos',
      content: '¿Eliminar todos los directivos?',
      confirmLabel: 'Eliminar todo',
      isDangerous: true,
    );
    if (confirm == true && context.mounted) {
      provider.limpiarDirectivos();
    }
  }
}

// Envío asíncrono de correo individual
Future<void> _enviarInvitacionEmail(BuildContext context, Directivo d) async {
  final provider = context.read<AppProvider>();
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('Enviando invitación oficial a ${d.nombre}...')),
        ],
      ),
      duration: const Duration(days: 1),
    ),
  );

  final exito = await provider.enviarCorreoDirectivo(d);

  if (context.mounted) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: exito ? AppColors.success : AppColors.error,
        content: Text(
          exito 
              ? '✅ Invitación enviada exitosamente a ${d.correo}' 
              : '❌ Falló el envío del correo electrónico.'
        ),
      ),
    );
  }
}

// Lista para móvil
class _DirectivosList extends StatelessWidget {
  final List<Directivo> directivos;
  const _DirectivosList({required this.directivos});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<AppProvider>().isAdmin;
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: directivos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final d = directivos[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(name: d.nombre, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.nombre,
                            style: AppTextStyles.body
                                .copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(d.cargo,
                            style: AppTextStyles.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  _EstadoBadge(estado: d.estado),
                ],
              ),
              const SizedBox(height: 8),
              Text(d.correo,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (d.facultad != null) ...[
                const SizedBox(height: 4),
                Text(d.facultad!,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
              if (isAdmin) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.send_rounded, size: 18),
                      color: AppColors.success,
                      tooltip: 'Enviar invitación por correo',
                      onPressed: () => _enviarInvitacionEmail(context, d),
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      color: AppColors.primaryLight,
                      onPressed: () => showDialog(
                          context: context,
                          builder: (_) => _DirectivoDialog(directivo: d)),
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: AppColors.error,
                      onPressed: () => _confirmDelete(context, d),
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Directivo d) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Eliminar directivo',
      content: '¿Eliminar a ${d.nombre}?',
      confirmLabel: 'Eliminar',
      isDangerous: true,
    );
    if (confirm == true && context.mounted) {
      context.read<AppProvider>().eliminarDirectivo(d.id);
    }
  }
}

// Tabla para desktop optimizada contra Overflows
class _DirectivosTable extends StatelessWidget {
  final List<Directivo> directivos;
  const _DirectivosTable({required this.directivos});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<AppProvider>().isAdmin;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1100,
          child: Table(
          columnWidths: {
            0: const FlexColumnWidth(2.0), // Nombre ligeramente optimizado
            1: const FlexColumnWidth(1.8), // Cargo optimizado
            2: const FlexColumnWidth(3.2), // Espacio extra seguro para correos largos
            3: const FlexColumnWidth(2.5), // Facultad
            4: const FlexColumnWidth(1.5), // Estado Badge
            if (isAdmin) 5: const FlexColumnWidth(1.8), // Acciones expandido proporcionalmente
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: AppColors.surfaceVariant),
              children: [
                'Nombre',
                'Cargo',
                'Correo',
                'Facultad',
                'Estado',
                if (isAdmin) 'Acciones'
              ].map((h) => Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Text(h,
                      style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary))))
              .toList(),
            ),
            ...directivos.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value;
              return TableRow(
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : const Color(0xFFFAFBFC),
                  border:
                      const Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                children: [
                  _cell(d.nombre),
                  _cell(d.cargo),
                  _cell(d.correo),
                  _cell(d.facultad ?? '---'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: _EstadoBadge(estado: d.estado),
                  ),
                  if (isAdmin)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.send_rounded, size: 18),
                            color: AppColors.success,
                            tooltip: 'Enviar Correo',
                            onPressed: () => _enviarInvitacionEmail(context, d),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                           ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            color: AppColors.primaryLight,
                            onPressed: () => showDialog(
                                context: context,
                                builder: (_) => _DirectivoDialog(directivo: d)),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            color: AppColors.error,
                            onPressed: () async {
                              final confirm = await showConfirmDialog(
                                context,
                                title: 'Eliminar directivo',
                                content: '¿Eliminar a ${d.nombre}?',
                                confirmLabel: 'Eliminar',
                                isDangerous: true,
                              );
                              if (confirm == true && context.mounted) {
                                context
                                    .read<AppProvider>()
                                    .eliminarDirectivo(d.id);
                              }
                            },
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    ),
    );
  }

  Widget _cell(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text,
          style: AppTextStyles.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis));
}

class _EstadoBadge extends StatelessWidget {
  final EstadoDirectivo estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (estado) {
      case EstadoDirectivo.confirmado:
        color = AppColors.success;
        label = 'Confirmado';
        break;
      case EstadoDirectivo.rechazado:
        color = AppColors.error;
        label = 'Rechazado';
        break;
      case EstadoDirectivo.pendiente:
        color = AppColors.warning;
        label = 'Pendiente';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(76))),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title, value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ),
          Text(title,
              style: AppTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _DirectivoDialog extends StatefulWidget {
  final Directivo? directivo;
  const _DirectivoDialog({this.directivo});

  @override
  State<_DirectivoDialog> createState() => _DirectivoDialogState();
}

class _DirectivoDialogState extends State<_DirectivoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl, _cargoCtrl, _correoCtrl, _telCtrl;
  String? _facultad;
  EstadoDirectivo _estado = EstadoDirectivo.pendiente;

  bool get isEditing => widget.directivo != null;

  @override
  void initState() {
    super.initState();
    final d = widget.directivo;
    _nombreCtrl = TextEditingController(text: d?.nombre ?? '');
    _cargoCtrl = TextEditingController(text: d?.cargo ?? '');
    _correoCtrl = TextEditingController(text: d?.correo ?? '');
    _telCtrl = TextEditingController(text: d?.telefono ?? '');
    _facultad = d?.facultad;
    _estado = d?.estado ?? EstadoDirectivo.pendiente;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cargoCtrl.dispose();
    _correoCtrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();
    final directivo = Directivo(
      id: widget.directivo?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: _nombreCtrl.text.trim(),
      cargo: _cargoCtrl.text.trim(),
      correo: _correoCtrl.text.trim(),
      facultad: _facultad,
      telefono: _telCtrl.text.trim(),
      estado: _estado,
      fechaConfirmacion: widget.directivo?.fechaConfirmacion,
    );

    if (isEditing) {
      provider.editarDirectivo(directivo);
    } else {
      provider.agregarDirectivo(directivo);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              isEditing ? 'Editar directivo' : 'Nuevo directivo',
                              style: AppTextStyles.h2)),
                      IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context))
                    ]),
                    const SizedBox(height: 16),
                    _fieldLabel('Nombre completo'),
                    const SizedBox(height: 6),
                    TextFormField(
                        controller: _nombreCtrl,
                        decoration: const InputDecoration(
                            hintText: 'Dr. Juan Pérez'),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null),
                    const SizedBox(height: 12),
                    _fieldLabel('Cargo'),
                    const SizedBox(height: 6),
                    TextFormField(
                        controller: _cargoCtrl,
                        decoration:
                            const InputDecoration(hintText: 'Rector / Decano'),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null),
                    const SizedBox(height: 12),
                    _fieldLabel('Correo'),
                    const SizedBox(height: 6),
                    TextFormField(
                        controller: _correoCtrl,
                        decoration: const InputDecoration(
                            hintText: 'correo@udes.edu.co'),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null),
                    const SizedBox(height: 12),
                    _fieldLabel('Teléfono'),
                    const SizedBox(height: 6),
                    TextFormField(
                        controller: _telCtrl,
                        decoration:
                            const InputDecoration(hintText: '3001234567')),
                    const SizedBox(height: 12),
                    _fieldLabel('Facultad (opcional)'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _facultad,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          hintText: 'Selecciona facultad'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('Ninguna')),
                        ...AppConstants.facultades.map((f) => DropdownMenuItem(
                            value: f,
                            child: Text(f, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() => _facultad = v),
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('Estado'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<EstadoDirectivo>(
                      value: _estado,
                      items: EstadoDirectivo.values
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(_estadoLabel(e))))
                          .toList(),
                      onChanged: (v) => setState(() => _estado = v!),
                      decoration: const InputDecoration(),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: ElevatedButton(
                              onPressed: _submit,
                              child: Text(isEditing ? 'Guardar' : 'Crear'))),
                    ]),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  String _estadoLabel(EstadoDirectivo e) {
    switch (e) {
      case EstadoDirectivo.confirmado:
        return 'Confirmado';
      case EstadoDirectivo.rechazado:
        return 'Rechazado';
      case EstadoDirectivo.pendiente:
        return 'Pendiente';
    }
  }

  Widget _fieldLabel(String label) => Text(label,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary));
}