import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../data/models/models.dart';
import '../../widgets/common/widgets.dart';

class DirectivosScreen extends StatefulWidget {
  const DirectivosScreen({super.key});
  @override
  State<DirectivosScreen> createState() => _DirectivosScreenState();
}

class _DirectivosScreenState extends State<DirectivosScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl, _cargoCtrl, _correoCtrl, _facultadCtrl, _telefonoCtrl;
  late String _estadoSeleccionado;
  Directivo? _directivoEnEdicion;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController();
    _cargoCtrl = TextEditingController();
    _correoCtrl = TextEditingController();
    _facultadCtrl = TextEditingController();
    _telefonoCtrl = TextEditingController();
    _estadoSeleccionado = EstadoDirectivo.pendiente.name;
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _cargoCtrl, _correoCtrl, _facultadCtrl, _telefonoCtrl]) c.dispose();
    super.dispose();
  }

  void _limpiarFormulario() {
    for (final c in [_nombreCtrl, _cargoCtrl, _correoCtrl, _facultadCtrl, _telefonoCtrl]) c.clear();
    _estadoSeleccionado = EstadoDirectivo.pendiente.name;
    _directivoEnEdicion = null;
  }

  void _mostrarDialogoAgregar() {
    _limpiarFormulario();
    _abrirDialogo();
  }

  void _mostrarDialogoEditar(Directivo d) {
    _nombreCtrl.text = d.nombre;
    _cargoCtrl.text = d.cargo;
    _correoCtrl.text = d.correo;
    _facultadCtrl.text = d.facultad ?? '';
    _telefonoCtrl.text = d.telefono ?? '';
    _estadoSeleccionado = d.estado.name;
    _directivoEnEdicion = d;
    _abrirDialogo(titulo: 'Editar Directivo');
  }

  void _abrirDialogo({String titulo = 'Agregar Directivo'}) {
    showDialog(
      context: context,
      builder: (context) => _DialogoDirectivo(
        formKey: _formKey,
        nombreCtrl: _nombreCtrl, cargoCtrl: _cargoCtrl, correoCtrl: _correoCtrl,
        facultadCtrl: _facultadCtrl, telefonoCtrl: _telefonoCtrl,
        estadoSeleccionado: _estadoSeleccionado,
        onEstadoChanged: (v) => setState(() => _estadoSeleccionado = v),
        titulo: titulo,
        onGuardar: () {
          if (_formKey.currentState!.validate()) {
            if (_directivoEnEdicion != null) {
              context.read<AppProvider>().editarDirectivo(_directivoEnEdicion!.copyWith(
                nombre: _nombreCtrl.text, cargo: _cargoCtrl.text, correo: _correoCtrl.text,
                facultad: _facultadCtrl.text.isEmpty ? null : _facultadCtrl.text,
                telefono: _telefonoCtrl.text.isEmpty ? null : _telefonoCtrl.text,
                estado: EstadoDirectivo.values.firstWhere((e) => e.name == _estadoSeleccionado),
              ));
            } else {
              context.read<AppProvider>().agregarDirectivo(Directivo(
                id: 'DIR${DateTime.now().millisecondsSinceEpoch}',
                nombre: _nombreCtrl.text, cargo: _cargoCtrl.text, correo: _correoCtrl.text,
                facultad: _facultadCtrl.text.isEmpty ? null : _facultadCtrl.text,
                telefono: _telefonoCtrl.text.isEmpty ? null : _telefonoCtrl.text,
                estado: EstadoDirectivo.values.firstWhere((e) => e.name == _estadoSeleccionado),
                fechaConfirmacion: null,
              ));
            }
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('✅ Directivo ${_directivoEnEdicion != null ? 'actualizado' : 'agregado'}'), backgroundColor: AppColors.success),
            );
            _limpiarFormulario();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final directivos = provider.directivos;
    final isAdmin = provider.isAdmin;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Directivos', style: AppTextStyles.h1),
                  SizedBox(height: 4),
                  Text('Gestión de directivos y autoridades UDES', style: AppTextStyles.label),
                ])),
                if (!isMobile && isAdmin) ...[
                  ElevatedButton.icon(onPressed: _mostrarDialogoAgregar, icon: const Icon(Icons.add_rounded), label: const Text('Agregar Directivo'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white)),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(onPressed: () => _confirmarLimpiar(context, provider), icon: const Icon(Icons.delete_sweep_rounded), label: const Text('Limpiar'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white)),
                ],
                if (isMobile && isAdmin)
                  ElevatedButton.icon(onPressed: _mostrarDialogoAgregar, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Agregar'), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, foregroundColor: Colors.white)),
              ]),
              if (isMobile && isAdmin) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmarLimpiar(context, provider),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: AppColors.error),
                    label: const Text('Limpiar todos', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // Tabla / Lista
          Card(
            child: directivos.isEmpty
                ? const EmptyState(icon: Icons.people_outline_rounded, title: 'Sin directivos', subtitle: 'Agrega directivos para enviarles invitaciones')
                : isMobile
                    ? _DirectivosList(directivos: directivos, isAdmin: isAdmin, onEdit: _mostrarDialogoEditar, onDelete: (d) => _confirmarEliminar(context, provider, d))
                    : _DirectivosTable(directivos: directivos, isAdmin: isAdmin, onEdit: _mostrarDialogoEditar, onDelete: (d) => _confirmarEliminar(context, provider, d)),
          ),

          const SizedBox(height: 20),

          // Métricas
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: isMobile ? 10 : 16,
            mainAxisSpacing: isMobile ? 10 : 16,
            childAspectRatio: isMobile ? 1.1 : 1.4,
            children: [
              MetricCard(title: 'Total', value: directivos.length.toString(), icon: Icons.people_outline_rounded, color: AppColors.primaryLight),
              MetricCard(title: 'Confirmados', value: directivos.where((d) => d.estado == EstadoDirectivo.confirmado).length.toString(), icon: Icons.check_circle_rounded, color: AppColors.success),
              MetricCard(title: 'Pendientes', value: directivos.where((d) => d.estado == EstadoDirectivo.pendiente).length.toString(), icon: Icons.schedule_rounded, color: AppColors.warning),
              MetricCard(title: 'Rechazados', value: directivos.where((d) => d.estado == EstadoDirectivo.rechazado).length.toString(), icon: Icons.cancel_rounded, color: AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarLimpiar(BuildContext context, AppProvider provider) async {
    final confirm = await showConfirmDialog(context, title: 'Limpiar Directivos', content: '¿Eliminar todos los directivos?', confirmLabel: 'Eliminar todo', isDangerous: true);
    if (confirm == true && context.mounted) {
      provider.limpiarDirectivos();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Directivos eliminados'), backgroundColor: AppColors.success));
    }
  }

  Future<void> _confirmarEliminar(BuildContext context, AppProvider provider, Directivo d) async {
    final confirm = await showConfirmDialog(context, title: 'Eliminar Directivo', content: '¿Eliminar a ${d.nombre}?', confirmLabel: 'Eliminar', isDangerous: true);
    if (confirm == true && context.mounted) {
      provider.eliminarDirectivo(d.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Directivo eliminado')));
    }
  }
}

class _DirectivosList extends StatelessWidget {
  final List<Directivo> directivos;
  final bool isAdmin;
  final Function(Directivo) onEdit, onDelete;
  const _DirectivosList({required this.directivos, required this.isAdmin, required this.onEdit, required this.onDelete});

  Color _estadoColor(EstadoDirectivo e) {
    switch (e) {
      case EstadoDirectivo.confirmado: return AppColors.success;
      case EstadoDirectivo.pendiente: return AppColors.warning;
      case EstadoDirectivo.rechazado: return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: directivos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final d = directivos[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.primaryLight.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_rounded, color: AppColors.primaryLight, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.nombre, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
              Text(d.cargo, style: AppTextStyles.bodySmall),
              Text(d.correo, style: AppTextStyles.caption),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _estadoColor(d.estado).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: _estadoColor(d.estado))),
                child: Text(d.estado.label, style: TextStyle(color: _estadoColor(d.estado), fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ])),
            if (isAdmin) Column(children: [
              IconButton(icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.warning), onPressed: () => onEdit(d), constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero),
              IconButton(icon: const Icon(Icons.delete_rounded, size: 16, color: AppColors.error), onPressed: () => onDelete(d), constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero),
            ]),
          ]),
        );
      },
    );
  }
}

class _DirectivosTable extends StatelessWidget {
  final List<Directivo> directivos;
  final bool isAdmin;
  final Function(Directivo) onEdit, onDelete;
  const _DirectivosTable({required this.directivos, required this.isAdmin, required this.onEdit, required this.onDelete});

  Color _estadoColor(EstadoDirectivo e) {
    switch (e) {
      case EstadoDirectivo.confirmado: return AppColors.success;
      case EstadoDirectivo.pendiente: return AppColors.warning;
      case EstadoDirectivo.rechazado: return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('Nombre')),
          DataColumn(label: Text('Cargo')),
          DataColumn(label: Text('Correo')),
          DataColumn(label: Text('Facultad')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: directivos.map((d) => DataRow(cells: [
          DataCell(Text(d.nombre)),
          DataCell(Text(d.cargo)),
          DataCell(Text(d.correo, maxLines: 1, overflow: TextOverflow.ellipsis)),
          DataCell(Text(d.facultad ?? '---')),
          DataCell(Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _estadoColor(d.estado).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: _estadoColor(d.estado))),
            child: Text(d.estado.label, style: TextStyle(color: _estadoColor(d.estado), fontSize: 12, fontWeight: FontWeight.w600)),
          )),
          DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
            if (isAdmin) IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.warning), onPressed: () => onEdit(d), tooltip: 'Editar'),
            if (isAdmin) IconButton(icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.error), onPressed: () => onDelete(d), tooltip: 'Eliminar'),
          ])),
        ])).toList(),
      ),
    );
  }
}

class _DialogoDirectivo extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nombreCtrl, cargoCtrl, correoCtrl, facultadCtrl, telefonoCtrl;
  final String estadoSeleccionado, titulo;
  final Function(String) onEstadoChanged;
  final VoidCallback onGuardar;

  const _DialogoDirectivo({
    required this.formKey, required this.nombreCtrl, required this.cargoCtrl,
    required this.correoCtrl, required this.facultadCtrl, required this.telefonoCtrl,
    required this.estadoSeleccionado, required this.onEstadoChanged,
    required this.onGuardar, this.titulo = 'Agregar Directivo',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(titulo),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre completo'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 10),
            TextFormField(controller: cargoCtrl, decoration: const InputDecoration(labelText: 'Cargo'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 10),
            TextFormField(controller: correoCtrl, decoration: const InputDecoration(labelText: 'Correo'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
            const SizedBox(height: 10),
            TextFormField(controller: facultadCtrl, decoration: const InputDecoration(labelText: 'Facultad (opcional)')),
            const SizedBox(height: 10),
            TextFormField(controller: telefonoCtrl, decoration: const InputDecoration(labelText: 'Teléfono (opcional)')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: estadoSeleccionado,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: EstadoDirectivo.values.map((e) => DropdownMenuItem(value: e.name, child: Text(e.label))).toList(),
              onChanged: (v) => onEstadoChanged(v!),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: onGuardar, child: const Text('Guardar')),
      ],
    );
  }
}