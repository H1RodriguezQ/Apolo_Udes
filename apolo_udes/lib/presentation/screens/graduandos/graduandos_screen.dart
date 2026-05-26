import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/models.dart';
import '../../../data/services/excel_service.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';

class GraduandosScreen extends StatefulWidget {
  const GraduandosScreen({super.key});

  @override
  State<GraduandosScreen> createState() => _GraduandosScreenState();
}

class _GraduandosScreenState extends State<GraduandosScreen> {
  String _searchQuery = '';
  bool _importando = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final graduandos = provider.graduandos
        .where(
          (g) =>
              g.nombreCompleto.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              g.documento.contains(_searchQuery) ||
              g.codigoEstudiantil.contains(_searchQuery),
        )
        .toList();

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Graduandos', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text(
                    '${provider.totalGraduandos} estudiantes registrados',
                    style: AppTextStyles.label,
                  ),
                ],
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _importando ? null : _descargarPlantilla,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Plantilla'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _importando ? null : _importarExcel,
                icon: _importando
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(_importando ? 'Importando...' : 'Subir Excel'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _showAddDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Agregar'),
              ),
              const SizedBox(width: 10),
              if (provider.graduandos.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _importando ? null : _borrarTodo,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                  label: const Text('Borrar lista'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                ),
            ],
          ),

          const SizedBox(height: 24),

          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre, documento o código...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: Card(
              child: graduandos.isEmpty
                  ? const EmptyState(
                      icon: Icons.school_outlined,
                      title: 'No hay graduandos',
                      subtitle: 'Sube un Excel o agrega manualmente',
                    )
                  : _GraduandosTable(graduandos: graduandos),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _importarExcel() async {
    setState(() => _importando = true);
    final result = await ExcelService.importarGraduandos();
    if (!mounted) return;
    setState(() => _importando = false);

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: AppColors.error),
      );
      return;
    }

    if (result.graduandos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontraron registros válidos en el archivo'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final duplicados = await context.read<AppProvider>().importarGraduandos(result.graduandos);
    final agregados = result.graduandos.length - duplicados;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => _ResultadoImportDialog(
        agregados: agregados,
        duplicados: duplicados,
        errores: result.errores,
      ),
    );
  }

  Future<void> _descargarPlantilla() async {
    final ok = await ExcelService.generarYCompartirPlantilla();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Plantilla generada.' : 'No se pudo generar la plantilla'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _borrarTodo() async {
    final cantidad = context.read<AppProvider>().graduandos.length;
    final confirm = await showConfirmDialog(
      context,
      title: 'Borrar todos los graduandos',
      content: '¿Está seguro de eliminar los $cantidad graduandos registrados?',
      confirmLabel: 'Borrar todo',
      isDangerous: true,
    );
    if (confirm == true && mounted) {
      await context.read<AppProvider>().limpiarGraduandos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se eliminaron $cantidad graduandos'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AgregarGraduandoDialog(),
    );
  }
}

// ── Tabla ──
class _GraduandosTable extends StatelessWidget {
  final List<Graduando> graduandos;
  const _GraduandosTable({required this.graduandos});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SingleChildScrollView(
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(3),
            4: FlexColumnWidth(2),
            5: FlexColumnWidth(1.5),
            6: FlexColumnWidth(1.5),
            7: FlexColumnWidth(2.5),
          },
          children: [
            TableRow(
              decoration: const BoxDecoration(color: AppColors.surfaceVariant),
              children: ['Graduando', 'Documento', 'Código', 'Programa', 'Facultad', 'Hora', 'Estado', 'Acciones']
                  .map((h) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Text(h, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ))
                  .toList(),
            ),
            ...graduandos.asMap().entries.map((entry) {
              final i = entry.key;
              final g = entry.value;
              return TableRow(
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : const Color(0xFFFAFBFC),
                  border: const Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        UserAvatar(name: g.nombreCompleto, size: 32),
                        const SizedBox(width: 10),
                        Expanded(child: Text(g.nombreCompleto, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500))),
                      ],
                    ),
                  ),
                  _cell(g.documento),
                  _cell(g.codigoEstudiantil),
                  _cell(g.programa),
                  _cell(_facultadCorta(g.facultad)),
                  _cell(g.horaCeremonia),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: StatusBadge.fromEstadoGraduando(g.estado),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 18),
                          color: AppColors.primaryLight,
                          tooltip: 'Editar',
                          onPressed: () => showDialog(context: context, builder: (_) => _AgregarGraduandoDialog(graduando: g)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          color: AppColors.error,
                          tooltip: 'Eliminar',
                          onPressed: () async {
                            final confirm = await showConfirmDialog(
                              context,
                              title: 'Eliminar graduando',
                              content: '¿Está seguro de eliminar a ${g.nombreCompleto}?',
                              confirmLabel: 'Eliminar',
                              isDangerous: true,
                            );
                            if (confirm == true && context.mounted) {
                              context.read<AppProvider>().eliminarGraduando(g.id);
                            }
                          },
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
    );
  }

  String _facultadCorta(String f) {
    if (f.contains('Salud')) return 'C. Salud';
    if (f.contains('Económ')) return 'C. Económicas';
    if (f.contains('Ingenier')) return 'Ingenierías';
    if (f.contains('Jurídic')) return 'C. Jurídicas';
    if (f.contains('Natural')) return 'C. Naturales';
    return f;
  }

  Widget _cell(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(text, style: AppTextStyles.body),
      );
}

// ── Dialog importación ──
class _ResultadoImportDialog extends StatelessWidget {
  final int agregados;
  final int duplicados;
  final List<String> errores;

  const _ResultadoImportDialog({required this.agregados, required this.duplicados, required this.errores});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.cloud_done_rounded, color: AppColors.success, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Text('Importación completada', style: AppTextStyles.h3)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _statBox('Agregados', '$agregados', AppColors.success, Icons.check_circle_rounded),
                  if (duplicados > 0) ...[const SizedBox(width: 12), _statBox('Duplicados', '$duplicados', AppColors.warning, Icons.warning_rounded)],
                  if (errores.isNotEmpty) ...[const SizedBox(width: 12), _statBox('Errores', '${errores.length}', AppColors.error, Icons.error_rounded)],
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Continuar')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Dialog Agregar/Editar ──
class _AgregarGraduandoDialog extends StatefulWidget {
  final Graduando? graduando;
  const _AgregarGraduandoDialog({this.graduando});

  @override
  State<_AgregarGraduandoDialog> createState() => _AgregarGraduandoDialogState();
}

class _AgregarGraduandoDialogState extends State<_AgregarGraduandoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codigoCtrl;
  late final TextEditingController _documentoCtrl;
  late final TextEditingController _nombresCtrl;
  late final TextEditingController _apellidosCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _correoCtrl;
  String? _facultad;
  String? _programa;
  bool _guardando = false;
  bool _cargandoHora = false;
  String? _horaAsignada; // hora cargada desde Firestore

  bool get isEditing => widget.graduando != null;

  List<String> get _programasFiltrados {
    if (_facultad == null) return [];
    return AppConstants.programasPorFacultad[_facultad] ?? [];
  }

  @override
  void initState() {
    super.initState();
    final g = widget.graduando;
    _codigoCtrl = TextEditingController(text: g?.codigoEstudiantil ?? '');
    _documentoCtrl = TextEditingController(text: g?.documento ?? '');
    _nombresCtrl = TextEditingController(text: g?.nombres ?? '');
    _apellidosCtrl = TextEditingController(text: g?.apellidos ?? '');
    _telefonoCtrl = TextEditingController(text: g?.telefono ?? '');
    _correoCtrl = TextEditingController(text: g?.correo ?? '');
    _facultad = g?.facultad;
    _programa = g?.programa;
    _horaAsignada = g?.horaCeremonia;

    // Si es edición, carga la hora de la facultad
    if (_facultad != null) _cargarHoraFacultad(_facultad!);
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _documentoCtrl.dispose();
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  // ── Carga la hora configurada para la facultad desde Firestore ──
  Future<void> _cargarHoraFacultad(String facultad) async {
    setState(() => _cargandoHora = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('evento')
          .get();

      if (doc.exists) {
        final horas = Map<String, String>.from(
          doc.data()?['horasPorFacultad'] ?? {},
        );
        setState(() => _horaAsignada = horas[facultad] ?? _horaAsignada);
      }
    } catch (e) {
      debugPrint('Error cargando hora: $e');
    } finally {
      setState(() => _cargandoHora = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_programa == null || _facultad == null) return;

    setState(() => _guardando = true);

    final hora = _horaAsignada ?? '08:00 AM';
    final provider = context.read<AppProvider>();

    if (isEditing) {
      await provider.editarGraduando(
        widget.graduando!.copyWith(
          codigoEstudiantil: _codigoCtrl.text.trim(),
          documento: _documentoCtrl.text.trim(),
          nombres: _nombresCtrl.text.trim(),
          apellidos: _apellidosCtrl.text.trim(),
          programa: _programa!,
          facultad: _facultad!,
          telefono: _telefonoCtrl.text.trim(),
          correo: _correoCtrl.text.trim(),
          horaCeremonia: hora,
        ),
      );
    } else {
      await provider.agregarGraduando(
        Graduando(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          codigoEstudiantil: _codigoCtrl.text.trim(),
          documento: _documentoCtrl.text.trim(),
          nombres: _nombresCtrl.text.trim(),
          apellidos: _apellidosCtrl.text.trim(),
          programa: _programa!,
          facultad: _facultad!,
          telefono: _telefonoCtrl.text.trim(),
          correo: _correoCtrl.text.trim(),
          horaCeremonia: hora,
          estado: EstadoGraduando.activo,
        ),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(isEditing ? 'Editar graduando' : 'Agregar graduando', style: AppTextStyles.h2),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _FormField(label: 'Código Estudiantil', controller: _codigoCtrl, hint: '2019115023')),
                            const SizedBox(width: 16),
                            Expanded(child: _FormField(label: 'Documento', controller: _documentoCtrl, hint: '1098765432')),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _FormField(label: 'Nombres', controller: _nombresCtrl, hint: 'Valentina')),
                            const SizedBox(width: 16),
                            Expanded(child: _FormField(label: 'Apellidos', controller: _apellidosCtrl, hint: 'Ramírez Ortiz')),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Facultad
                        _fieldLabel('Facultad'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _facultad,
                          isExpanded: true,
                          decoration: const InputDecoration(hintText: 'Selecciona la facultad'),
                          items: AppConstants.facultades
                              .map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _facultad = v;
                              _programa = null;
                              _horaAsignada = null;
                            });
                            if (v != null) _cargarHoraFacultad(v);
                          },
                          validator: (v) => v == null ? 'Selecciona una facultad' : null,
                        ),
                        const SizedBox(height: 16),

                        // Programa
                        _fieldLabel('Programa Académico'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _programa,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: _facultad == null ? 'Primero selecciona una facultad' : 'Selecciona el programa',
                          ),
                          items: _programasFiltrados
                              .map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: _facultad == null ? null : (v) => setState(() => _programa = v),
                          validator: (v) => v == null ? 'Selecciona un programa' : null,
                        ),
                        const SizedBox(height: 16),

                        // Hora asignada automáticamente
                        if (_facultad != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primaryLight.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 18, color: AppColors.primaryLight),
                                const SizedBox(width: 10),
                                _cargandoHora
                                    ? const SizedBox(
                                        width: 16, height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                                      )
                                    : Expanded(
                                        child: Text(
                                          _horaAsignada != null
                                              ? 'Hora asignada: $_horaAsignada (configurada para $_facultad)'
                                              : 'Hora no configurada para esta facultad',
                                          style: const TextStyle(fontSize: 13, color: AppColors.primaryLight),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        Row(
                          children: [
                            Expanded(child: _FormField(label: 'Teléfono', controller: _telefonoCtrl, hint: '3001234567')),
                            const SizedBox(width: 16),
                            Expanded(child: _FormField(label: 'Correo Institucional', controller: _correoCtrl, hint: 'correo@udes.edu.co')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _guardando ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _submit,
                      child: _guardando
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEditing ? 'Guardar cambios' : 'Agregar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Align(
        alignment: Alignment.centerLeft,
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      );
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _FormField({required this.label, required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
        ),
      ],
    );
  }
}