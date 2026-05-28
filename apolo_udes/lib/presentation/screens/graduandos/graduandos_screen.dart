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
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    // Filtrado en tiempo real de graduandos según la barra de búsqueda
    final graduandos = provider.graduandos
        .where((g) =>
            g.nombreCompleto.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            g.documento.contains(_searchQuery) ||
            g.codigoEstudiantil.contains(_searchQuery))
        .toList();

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la pantalla con botones responsivos
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Graduandos', style: AppTextStyles.h1),
                        Text('${provider.totalGraduandos} estudiantes registrados', style: AppTextStyles.label),
                      ],
                    ),
                  ),
                  if (!isMobile) ..._buildButtons(context, provider, isMobile),
                ],
              ),
              if (isMobile) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildButtons(context, provider, isMobile),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          
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
                  : isMobile
                      ? _GraduandosList(graduandos: graduandos)
                      : _GraduandosTable(graduandos: graduandos),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildButtons(BuildContext context, AppProvider provider, bool isMobile) {
    return [
      OutlinedButton.icon(
        onPressed: _importando ? null : _descargarPlantilla,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Plantilla'),
      ),
      ElevatedButton.icon(
        onPressed: _importando ? null : _importarExcel,
        icon: _importando
            ? const SizedBox(
                width: 16, 
                height: 16, 
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.upload_file_rounded, size: 18),
        label: Text(_importando ? 'Importando...' : 'Subir Excel'),
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
      ),
      ElevatedButton.icon(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Agregar'),
      ),
      if (provider.graduandos.isNotEmpty)
        ElevatedButton.icon(
          onPressed: _importando ? null : _borrarTodo,
          icon: const Icon(Icons.delete_sweep_rounded, size: 18),
          label: const Text('Borrar'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
        ),
    ];
  }

  Future<void> _importarExcel() async {
    setState(() => _importando = true);
    
    // Leemos el excel asíncronamente
    final result = await ExcelService.importarGraduandos();
    
    if (!mounted) return;
    
    if (!result.success) {
      setState(() => _importando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: AppColors.error),
      );
      return;
    }
    
    if (result.graduandos.isEmpty) {
      setState(() => _importando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron registros válidos en el Excel'), backgroundColor: AppColors.warning),
      );
      return;
    }

    // Informamos a la UI que empiece la importación en la base de datos local y Firebase
    final provider = context.read<AppProvider>();
    
    // Disparamos la importación. 
    // Internamente, el Provider guardará todo e iniciará el ciclo de envío asíncrono.
    final duplicados = await provider.importarGraduandos(result.graduandos);
    final agregados = result.graduandos.length - duplicados;
    
    if (!mounted) return;
    setState(() => _importando = false);
    
    // Mostramos feedback de éxito de inmediato sin que el usuario espere a que terminen de enviarse todos los emails de la red
    showDialog(
      context: context, 
      builder: (_) => _ResultadoImportDialog(
        agregados: agregados, 
        duplicados: duplicados, 
        errores: result.errores,
      ),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sincronizando y enviando correos en segundo plano...'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _descargarPlantilla() async {
    final ok = await ExcelService.generarYCompartirPlantilla();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Plantilla generada.' : 'No se pudo generar la plantilla'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  Future<void> _borrarTodo() async {
    final cantidad = context.read<AppProvider>().graduandos.length;
    final confirm = await showConfirmDialog(
      context, 
      title: 'Borrar todos los graduandos', 
      content: '¿Está seguro de eliminar los $cantidad graduandos?', 
      confirmLabel: 'Borrar todo', 
      isDangerous: true,
    );
    if (confirm == true && mounted) {
      await context.read<AppProvider>().limpiarGraduandos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se eliminaron $cantidad graduandos'), backgroundColor: AppColors.success),
      );
    }
  }

  void _showAddDialog(BuildContext context) {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const _AgregarGraduandoDialog());
  }
}

class _GraduandosList extends StatelessWidget {
  final List<Graduando> graduandos;
  const _GraduandosList({required this.graduandos});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: graduandos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final g = graduandos[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              UserAvatar(name: g.nombreCompleto, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.nombreCompleto, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                    Text(g.programa, style: AppTextStyles.bodySmall),
                    Text('Doc: ${g.documento} | ${g.horaCeremonia}', style: AppTextStyles.caption),
                  ],
                ),
              ),
              Column(
                children: [
                  StatusBadge.fromEstadoGraduando(g.estado),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        color: AppColors.primaryLight,
                        onPressed: () => showDialog(context: context, builder: (_) => _AgregarGraduandoDialog(graduando: g)),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        color: AppColors.error,
                        onPressed: () async {
                          final confirm = await showConfirmDialog(
                            context, 
                            title: 'Eliminar graduando', 
                            content: '¿Eliminar a ${g.nombreCompleto}?', 
                            confirmLabel: 'Eliminar', 
                            isDangerous: true,
                          );
                          if (confirm == true && context.mounted) {
                            context.read<AppProvider>().eliminarGraduando(g.id);
                          }
                        },
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
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
                          onPressed: () => showDialog(context: context, builder: (_) => _AgregarGraduandoDialog(graduando: g)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          color: AppColors.error,
                          onPressed: () async {
                            final confirm = await showConfirmDialog(
                              context, 
                              title: 'Eliminar graduando', 
                              content: '¿Eliminar a ${g.nombreCompleto}?', 
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
    return f.length > 12 ? '${f.substring(0, 12)}...' : f;
  }

  Widget _cell(String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(text, style: AppTextStyles.body),
      );
}

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
                    width: 48, 
                    height: 48, 
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
                  if (duplicados > 0) ...[
                    const SizedBox(width: 12), 
                    _statBox('Duplicados', '$duplicados', AppColors.warning, Icons.warning_rounded),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, 
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('Continuar'),
                ),
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
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08), 
          borderRadius: BorderRadius.circular(10), 
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
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

class _AgregarGraduandoDialog extends StatefulWidget {
  final Graduando? graduando;
  const _AgregarGraduandoDialog({this.graduando});
  @override
  State<_AgregarGraduandoDialog> createState() => _AgregarGraduandoDialogState();
}

class _AgregarGraduandoDialogState extends State<_AgregarGraduandoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codigoCtrl, _documentoCtrl, _nombresCtrl, _apellidosCtrl, _telefonoCtrl, _correoCtrl;
  String? _facultad, _programa;
  bool _guardando = false, _cargandoHora = false;
  String? _horaAsignada;

  bool get isEditing => widget.graduando != null;
  List<String> get _programasFiltrados => _facultad == null ? [] : AppConstants.programasPorFacultad[_facultad] ?? [];

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
    _facultad = _normalizarFacultad(g?.facultad);
    _programa = _facultad != null ? g?.programa : null;
    _programa = g?.programa;
    _horaAsignada = _normalizarHora(g?.horaCeremonia);
    if (_facultad != null) _cargarHoraFacultad(_facultad!);
  }

  String? _normalizarHora(String? hora) {
    if (hora == null || hora.isEmpty) return null;
    if ((hora.contains('AM') || hora.contains('PM')) &&
        AppConstants.horasCeremonia.contains(hora)) {
      return hora;
    }
    return null;
  }

  String? _normalizarFacultad(String? facultad) {
    if (facultad == null || facultad.isEmpty) return null;
    if (AppConstants.facultades.contains(facultad)) return facultad;
    return null;
  }

  @override
  void dispose() {
    for (final c in [_codigoCtrl, _documentoCtrl, _nombresCtrl, _apellidosCtrl, _telefonoCtrl, _correoCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarHoraFacultad(String facultad) async {
    setState(() => _cargandoHora = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('evento').get();
      if (doc.exists) {
        final horas = Map<String, String>.from(doc.data()?['horasPorFacultad'] ?? {});
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
      await provider.editarGraduando(widget.graduando!.copyWith(
        codigoEstudiantil: _codigoCtrl.text.trim(), 
        documento: _documentoCtrl.text.trim(),
        nombres: _nombresCtrl.text.trim(), 
        apellidos: _apellidosCtrl.text.trim(),
        programa: _programa!, 
        facultad: _facultad!, 
        telefono: _telefonoCtrl.text.trim(),
        correo: _correoCtrl.text.trim(), 
        horaCeremonia: hora,
      ));
    } else {
      await provider.agregarGraduando(Graduando(
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
      ));
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
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _FormField(label: 'Código', controller: _codigoCtrl, hint: '2019115023')),
                            const SizedBox(width: 12),
                            Expanded(child: _FormField(label: 'Documento', controller: _documentoCtrl, hint: '1098765432')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _FormField(label: 'Nombres', controller: _nombresCtrl, hint: 'Valentina')),
                            const SizedBox(width: 12),
                            Expanded(child: _FormField(label: 'Apellidos', controller: _apellidosCtrl, hint: 'Ramírez')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        Align(
                          alignment: Alignment.centerLeft, 
                          child: const Text('Facultad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _facultad,
                          isExpanded: true,
                          decoration: const InputDecoration(hintText: 'Selecciona la facultad'),
                          items: AppConstants.facultades.map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis))).toList(),
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
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft, 
                          child: const Text('Programa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _programa,
                          isExpanded: true,
                          decoration: InputDecoration(hintText: _facultad == null ? 'Primero selecciona facultad' : 'Selecciona el programa'),
                          items: _programasFiltrados.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: _facultad == null ? null : (v) => setState(() => _programa = v),
                          validator: (v) => v == null ? 'Selecciona un programa' : null,
                        ),
                        if (_facultad != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.05), 
                              borderRadius: BorderRadius.circular(8), 
                              border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 16, color: AppColors.primaryLight),
                                const SizedBox(width: 8),
                                _cargandoHora
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight))
                                    : Expanded(child: Text(_horaAsignada != null ? 'Hora: $_horaAsignada' : 'Sin hora configurada', style: const TextStyle(fontSize: 12, color: AppColors.primaryLight))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _FormField(label: 'Teléfono', controller: _telefonoCtrl, hint: '3001234567')),
                            const SizedBox(width: 12),
                            Expanded(child: _FormField(label: 'Correo', controller: _correoCtrl, hint: 'correo@udes.edu.co')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
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
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEditing ? 'Guardar' : 'Agregar'),
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
}

class _FormField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
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
          validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
        ),
      ],
    );
  }
}