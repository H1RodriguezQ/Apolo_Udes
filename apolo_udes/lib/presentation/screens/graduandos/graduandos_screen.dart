import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/validators/validadores_graduando.dart';
import '../../../data/models/models.dart';
import '../../../data/services/excel_service.dart';
import '../../../data/services/firestore_service.dart';
import '../../../data/services/usuarios_service.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';
import '../../widgets/common/apolo_ui.dart';

// Las reglas de validación (código UDES, documento, nombres, teléfono y
// correo) están en core/validators/validadores_graduando.dart y las comparten
// este formulario y la importación desde Excel.

// ── Eliminar graduando ──
// Una sola función para la lista (celular) y la tabla (escritorio). Al
// eliminar, sus invitados quedan ANULADOS: su QR deja de dar acceso, pero el
// registro se conserva. La acción queda en la bitácora.

Future<void> _eliminarGraduando(BuildContext context, Graduando g) async {
  final provider = context.read<AppProvider>();
  final autor = provider.usuarioActual;
  final messenger = ScaffoldMessenger.of(context);

  final confirm = await showConfirmDialog(
    context,
    title: 'Eliminar graduando',
    content: '¿Eliminar a ${g.nombreCompleto}? Sus invitados quedarán anulados y '
        'sus códigos QR dejarán de ser válidos. La acción queda registrada en la bitácora.',
    confirmLabel: 'Eliminar',
    isDangerous: true,
  );
  if (confirm != true) return;

  try {
    final anulados = await provider.eliminarGraduando(g.id);
    if (autor != null) {
      UsuariosService.auditar(
        autor,
        _recortar('Eliminó graduando ${g.nombreCompleto} (doc. ${g.documento}); '
            '$anulados invitado(s) anulado(s)', 200),
        tipo: 'graduando',
      );
    }
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text(anulados == 0
          ? '${g.nombreCompleto} fue eliminado'
          : '${g.nombreCompleto} fue eliminado y $anulados invitado(s) quedaron anulados'),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.error,
      duration: const Duration(seconds: 8),
      content: Text('No fue posible eliminar: $e'),
    ));
  }
}

// ── Reenvío del correo con el enlace de registro ──

/// Devuelve `correoRegistro` a 'pendiente' para que el servidor vuelva a
/// mandar el enlace al graduando. La app NO envía correos: solo repone la
/// petición en la cola y quien la procesa (Apps Script, cada 5 minutos)
/// escribe el resultado real en ese mismo campo.
Future<void> _reenviarEnlaceRegistro(BuildContext context, Graduando g) async {
  final provider = context.read<AppProvider>();
  final messenger = ScaffoldMessenger.of(context);

  final confirm = await showConfirmDialog(
    context,
    title: 'Reenviar enlace de registro',
    content: 'Se volverá a poner en cola el correo con el enlace de registro '
        'de ${g.nombreCompleto}. El servidor lo enviará en los próximos '
        'minutos.',
    confirmLabel: 'Reenviar',
  );
  if (confirm != true) return;

  final ok = await provider.reenviarCorreoRegistro(g.id, g.nombreCompleto);
  messenger.showSnackBar(SnackBar(
    backgroundColor: ok ? AppColors.success : AppColors.error,
    content: Text(ok
        ? 'Reenvío en cola: el servidor lo mandará en los próximos minutos.'
        : 'No fue posible reponer el correo en la cola.'),
  ));
}

// ── Invitado adicional (RF-11a) ──

String _recortar(String texto, int max) =>
    texto.length <= max ? texto : '${texto.substring(0, max - 1)}…';

Future<void> _autorizarExtra(BuildContext context, Graduando g) async {
  final autor = context.read<AppProvider>().usuarioActual;
  final messenger = ScaffoldMessenger.of(context);
  if (autor == null) return;

  final motivo = await showDialog<String>(
    context: context,
    builder: (_) => _MotivoExtraDialog(graduando: g),
  );
  if (motivo == null) return;

  try {
    await FirestoreService.autorizarInvitadoExtra(
      graduandoId: g.id,
      motivo: motivo,
      autorCorreo: autor.correo,
    );
    // La bitácora limita la acción a 200 caracteres.
    UsuariosService.auditar(
      autor,
      _recortar('Autorizo invitado adicional a ${g.nombreCompleto}. Motivo: $motivo', 200),
      tipo: 'graduando',
    );
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.success,
      content: Text('${g.nombreCompleto} ahora puede registrar ${FirestoreService.invitadosBase + 1} invitados'),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.error,
      duration: const Duration(seconds: 8),
      content: Text('No fue posible autorizar. ¿El graduando está sincronizado con Firestore? ($e)'),
    ));
  }
}

Future<void> _revocarExtra(BuildContext context, Graduando g) async {
  final autor = context.read<AppProvider>().usuarioActual;
  final messenger = ScaffoldMessenger.of(context);
  if (autor == null) return;

  final confirm = await showConfirmDialog(
    context,
    title: 'Revocar invitado adicional',
    content:
        '${g.nombreCompleto} volverá a tener ${FirestoreService.invitadosBase} invitados. La acción queda registrada en la bitácora.',
    confirmLabel: 'Revocar',
    isDangerous: true,
  );
  if (confirm != true) return;

  try {
    final ok = await FirestoreService.revocarInvitadoExtra(g.id);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        backgroundColor: AppColors.warning,
        duration: Duration(seconds: 8),
        content: Text(
            'El graduando ya registró su invitado adicional. Elimina ese invitado antes de revocar.'),
      ));
      return;
    }
    UsuariosService.auditar(
      autor,
      _recortar('Revoco invitado adicional de ${g.nombreCompleto}', 200),
      tipo: 'graduando',
    );
    messenger.showSnackBar(const SnackBar(
      backgroundColor: AppColors.success,
      content: Text('Invitado adicional revocado'),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.error,
      content: Text('No fue posible revocar: $e'),
    ));
  }
}

class _MotivoExtraDialog extends StatefulWidget {
  final Graduando graduando;
  const _MotivoExtraDialog({required this.graduando});

  @override
  State<_MotivoExtraDialog> createState() => _MotivoExtraDialogState();
}

class _MotivoExtraDialogState extends State<_MotivoExtraDialog> {
  final _formKey = GlobalKey<FormState>();
  final _motivoCtrl = TextEditingController();

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Autorizar invitado adicional', style: AppTextStyles.h3),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.graduando.nombreCompleto} podrá registrar '
                '${FirestoreService.invitadosBase + 1} invitados en lugar de '
                '${FirestoreService.invitadosBase}.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _motivoCtrl,
                autofocus: true,
                maxLength: 100,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  hintText: 'Ej: acompañante por discapacidad',
                ),
                validator: (v) => (v?.trim().length ?? 0) < 5
                    ? 'Describe el motivo (mínimo 5 caracteres)'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _motivoCtrl.text.trim());
            }
          },
          child: const Text('Autorizar'),
        ),
      ],
    );
  }
}

class GraduandosScreen extends StatefulWidget {
  const GraduandosScreen({super.key});
  @override
  State<GraduandosScreen> createState() => _GraduandosScreenState();
}

class _GraduandosScreenState extends State<GraduandosScreen> {
  String _searchQuery = '';
  bool _importando = false;

  // Una sola suscripción para saber qué graduandos tienen el extra.
  late final Stream<Set<String>> _conExtra =
      FirestoreService.escucharGraduandosConExtra();

  // Filtros del diseño: facultad y estado del correo de registro.
  String _facultad = 'Todas';
  String _correo = 'Todos';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final q = _searchQuery.trim().toLowerCase();
    final facultades = {for (final g in provider.graduandos) g.facultad}.where((f) => f.isNotEmpty).toList()..sort();

    final graduandos = provider.graduandos.where((g) {
      if (q.isNotEmpty &&
          !(g.nombreCompleto.toLowerCase().contains(q) || g.documento.contains(q) || g.codigoEstudiantil.contains(q))) {
        return false;
      }
      if (_facultad != 'Todas' && g.facultad != _facultad) return false;
      if (_correo != 'Todos' && (g.correoRegistro ?? 'sin dato') != _correo) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.nombreCompleto.compareTo(b.nombreCompleto));

    // Invitados registrados por cada graduando (sin contar los anulados).
    final porGraduando = <String, int>{};
    for (final i in provider.invitaciones) {
      if (i.estado == EstadoInvitacion.anulada) continue;
      porGraduando[i.graduandoId] = (porGraduando[i.graduandoId] ?? 0) + 1;
    }

    return PantallaApolo(
      encabezado: EncabezadoPantalla(
        titulo: 'Graduandos',
        detalle: '${provider.totalGraduandos} registrados',
        acciones: [
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (v) => v == 'plantilla' ? _descargarPlantilla() : _borrarTodo(),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'plantilla', child: Text('Descargar plantilla de Excel')),
              if (provider.graduandos.isNotEmpty)
                PopupMenuItem(value: 'borrar', child: Text('Borrar todos', style: TextStyle(color: AppColors.errorText))),
            ],
            child: const IgnorePointer(child: BotonSecundario(texto: 'Más', icono: Icons.more_horiz_rounded, onPressed: _nada)),
          ),
          BotonSecundario(
            texto: _importando ? 'Importando…' : 'Importar Excel',
            onPressed: _importando ? null : _importarExcel,
          ),
          ElevatedButton(
            onPressed: () => _showAddDialog(context),
            child: const Text('Agregar graduando'),
          ),
        ],
      ),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilaAdaptable(
            children: [
              Expanded(
                flex: 5,
                child: CampoConEtiqueta(
                  etiqueta: 'Buscar',
                  campo: CampoBusqueda(
                    hint: 'Nombre, cédula o código',
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CampoConEtiqueta(
                  etiqueta: 'Facultad',
                  campo: _Desplegable(
                    valor: _facultad,
                    opciones: ['Todas', ...facultades],
                    onChanged: (v) => setState(() => _facultad = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CampoConEtiqueta(
                  etiqueta: 'Correo de registro',
                  campo: _Desplegable(
                    valor: _correo,
                    opciones: const ['Todos', 'enviado', 'pendiente', 'error'],
                    etiquetas: const {'enviado': 'Enviado', 'pendiente': 'En cola', 'error': 'Con error'},
                    onChanged: (v) => setState(() => _correo = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<Set<String>>(
              stream: _conExtra,
              builder: (context, snap) {
                final conExtra = snap.data ?? const <String>{};
                return _GraduandosTable(
                  graduandos: graduandos,
                  conExtra: conExtra,
                  invitados: porGraduando,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static void _nada() {}

  Future<void> _importarExcel() async {
    setState(() => _importando = true);
    
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

    final provider = context.read<AppProvider>();
    final duplicados = await provider.importarGraduandos(result.graduandos);
    final agregados = result.graduandos.length - duplicados;
    
    if (!mounted) return;
    setState(() => _importando = false);
    
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
    final provider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final cantidad = provider.graduandos.length;
    final confirm = await showConfirmDialog(
      context,
      title: 'Borrar todos los graduandos',
      content: '¿Está seguro de eliminar los $cantidad graduandos? Todos los '
          'invitados quedarán anulados y sus códigos QR dejarán de ser válidos. '
          'La acción queda registrada en la bitácora.',
      confirmLabel: 'Borrar todo',
      isDangerous: true,
    );
    if (confirm != true) return;

    setState(() => _importando = true); // bloquea los botones mientras borra
    try {
      await provider.limpiarGraduandos();
      final autor = provider.usuarioActual;
      if (autor != null) {
        UsuariosService.auditar(
          autor,
          'Eliminó todos los graduandos ($cantidad) y anuló sus invitados',
          tipo: 'graduando',
        );
      }
      messenger.showSnackBar(SnackBar(
        content: Text('Se eliminaron $cantidad graduandos y se anularon sus invitados'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('No fue posible borrar: $e'),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 8),
      ));
    } finally {
      if (mounted) setState(() => _importando = false);
    }
  }

  void _showAddDialog(BuildContext context) {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const _AgregarGraduandoDialog());
  }
}

class _GraduandosTable extends StatelessWidget {
  final List<Graduando> graduandos;
  final Set<String> conExtra;
  final Map<String, int> invitados;
  const _GraduandosTable({required this.graduandos, required this.conExtra, required this.invitados});

  @override
  Widget build(BuildContext context) {
    final esAdmin = context.watch<AppProvider>().isAdmin;
    return TablaApolo(
      vacio: 'No hay graduandos con ese filtro. Importe el Excel o agréguelos uno por uno.',
      columnas: const [
        ColumnaTabla('Graduando', flex: 5),
        ColumnaTabla('Cédula', flex: 2),
        ColumnaTabla('Código', flex: 2),
        ColumnaTabla('Invitados', flex: 2),
        ColumnaTabla('Correo', flex: 2),
        ColumnaTabla('Acciones', flex: 3, derecha: true),
      ],
      filas: [
        for (final g in graduandos)
          [
            CeldaTexto(g.nombreCompleto, debajo: g.programa, fuerte: true),
            CeldaTexto(g.documento, mono: true),
            CeldaTexto(g.codigoEstudiantil, mono: true),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${invitados[g.id] ?? 0} / ${conExtra.contains(g.id) ? 3 : 2}', style: AppTextStyles.mono(size: 14)),
                if (conExtra.contains(g.id)) ...[const SizedBox(width: 8), const Etiqueta('+1', tono: TonoEtiqueta.info)],
              ],
            ),
            switch (g.correoRegistro) {
              'enviado' => const Etiqueta('Enviado', tono: TonoEtiqueta.ok),
              'pendiente' => const Etiqueta('En cola', tono: TonoEtiqueta.aviso),
              'error' => const Etiqueta('Con error', tono: TonoEtiqueta.error),
              _ => const Etiqueta('Sin dato'),
            },
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AccionFila(
                  icono: Icons.edit_outlined,
                  ayuda: 'Editar',
                  onPressed: () => showDialog(context: context, builder: (_) => _AgregarGraduandoDialog(graduando: g)),
                ),
                if (esAdmin)
                  AccionFila(
                    icono: Icons.mail_outline,
                    ayuda: 'Reenviar el correo con el enlace de registro',
                    onPressed: () => _reenviarEnlaceRegistro(context, g),
                  ),
                if (esAdmin)
                  AccionFila(
                    icono: conExtra.contains(g.id) ? Icons.person_remove_outlined : Icons.person_add_alt_outlined,
                    ayuda: conExtra.contains(g.id) ? 'Revocar invitado adicional' : 'Autorizar invitado adicional',
                    onPressed: () => conExtra.contains(g.id) ? _revocarExtra(context, g) : _autorizarExtra(context, g),
                  ),
                AccionFila(
                  icono: Icons.delete_outline,
                  ayuda: 'Eliminar',
                  peligro: true,
                  onPressed: () => _eliminarGraduando(context, g),
                ),
              ],
            ),
          ],
      ],
    );
  }
}

/// Lista desplegable del diseño (Todas / Ingenierías / ...).
class _Desplegable extends StatelessWidget {
  final String valor;
  final List<String> opciones;
  final Map<String, String> etiquetas;
  final ValueChanged<String> onChanged;
  const _Desplegable({required this.valor, required this.opciones, required this.onChanged, this.etiquetas = const {}});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: valor,
      isExpanded: true,
      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 13)),
      dropdownColor: AppColors.surface,
      items: [
        for (final o in opciones)
          DropdownMenuItem(value: o, child: Text(etiquetas[o] ?? o, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }
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
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
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
                  Expanded(child: Text('Importación completada', style: AppTextStyles.h3)),
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
                  if (errores.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    _statBox('Rechazados', '${errores.length}', AppColors.error, Icons.block_rounded),
                  ],
                ],
              ),
              // Filas rechazadas y el motivo, para que se puedan corregir en
              // el Excel y volver a importar.
              if (errores.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Filas rechazadas', style: AppTextStyles.h4),
                const SizedBox(height: 8),
                Flexible(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: errores
                            .map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text('• $e',
                                      style: TextStyle(color: AppColors.errorText, fontSize: 12)),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ],
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
            Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
    // El programa solo se precarga si pertenece a la facultad: si no, el
    // menú desplegable no lo encuentra y el formulario falla al abrirse.
    // (Antes se asignaba dos veces y la segunda anulaba esta comprobación.)
    final programas = _facultad == null
        ? const <String>[]
        : AppConstants.programasPorFacultad[_facultad] ?? const <String>[];
    _programa = programas.contains(g?.programa) ? g?.programa : null;
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
    // Cada setState verifica que el diálogo siga abierto: si el usuario lo
    // cierra mientras se consulta Firestore, no se actualiza nada.
    if (mounted) setState(() => _cargandoHora = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion').doc('evento').get();
      if (!mounted) return;
      if (doc.exists) {
        final horas = Map<String, String>.from(doc.data()?['horasPorFacultad'] ?? {});
        setState(() => _horaAsignada = horas[facultad] ?? _horaAsignada);
      }
    } catch (e) { 
      debugPrint('Error cargando hora: $e'); 
    } finally { 
      if (mounted) setState(() => _cargandoHora = false); 
    }
  }

  String? _error; // duplicados o fallo al guardar

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (_programa == null || _facultad == null) return;

    final provider = context.read<AppProvider>();
    final codigo = _codigoCtrl.text.trim();
    final documento = _documentoCtrl.text.trim();
    final nombres = limpiarEspacios(_nombresCtrl.text);
    final apellidos = limpiarEspacios(_apellidosCtrl.text);
    final telefono = _telefonoCtrl.text.trim();
    final correo = _correoCtrl.text.trim().toLowerCase();

    // No se permiten dos graduandos con el mismo documento o código.
    final idActual = widget.graduando?.id;
    final otros = provider.graduandos.where((g) => g.id != idActual);
    if (otros.any((g) => g.documento == documento)) {
      setState(() => _error = 'Ya existe un graduando con el documento $documento');
      return;
    }
    if (otros.any((g) => g.codigoEstudiantil == codigo)) {
      setState(() => _error = 'Ya existe un graduando con el código $codigo');
      return;
    }

    setState(() => _guardando = true);
    final hora = _horaAsignada ?? '08:00 AM';

    try {
      if (isEditing) {
        await provider.editarGraduando(widget.graduando!.copyWith(
          codigoEstudiantil: codigo,
          documento: documento,
          nombres: nombres,
          apellidos: apellidos,
          programa: _programa!,
          facultad: _facultad!,
          telefono: telefono,
          correo: correo,
          horaCeremonia: hora,
        ));
      } else {
        await provider.agregarGraduando(Graduando(
          // ID aleatorio de Firestore: el enlace público de registro de
          // invitados usa este ID, así que no debe poder adivinarse
          // (antes era la hora en milisegundos).
          id: FirebaseFirestore.instance.collection('graduandos').doc().id,
          codigoEstudiantil: codigo,
          documento: documento,
          nombres: nombres,
          apellidos: apellidos,
          programa: _programa!,
          facultad: _facultad!,
          telefono: telefono,
          correo: correo,
          horaCeremonia: hora, 
          estado: EstadoGraduando.activo,
        ));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Antes, si fallaba, el botón quedaba cargando para siempre.
      if (mounted) setState(() => _error = 'No fue posible guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
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
                            Expanded(child: _FormField(
                              label: 'Código', controller: _codigoCtrl, hint: '01 + año + 7 dígitos',
                              keyboardType: TextInputType.number, maxLength: largoCodigoUdes,
                              inputFormatters: [filtroSoloNumeros],
                              validator: validarCodigoUdes,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _FormField(
                              label: 'Documento', controller: _documentoCtrl, hint: 'Número de cédula',
                              keyboardType: TextInputType.number, maxLength: 12,
                              inputFormatters: [filtroSoloNumeros],
                              validator: validarDocumento,
                            )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _FormField(
                              label: 'Nombres', controller: _nombresCtrl, hint: 'Valentina',
                              maxLength: 50, textCapitalization: TextCapitalization.words,
                              inputFormatters: [filtroSoloLetras],
                              validator: validarNombrePersona,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _FormField(
                              label: 'Apellidos', controller: _apellidosCtrl, hint: 'Ramírez',
                              maxLength: 50, textCapitalization: TextCapitalization.words,
                              inputFormatters: [filtroSoloLetras],
                              validator: validarNombrePersona,
                            )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        Align(
                          alignment: Alignment.centerLeft, 
                          child: Text('Facultad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _facultad,
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
                          child: Text('Programa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _programa,
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
                                    : Expanded(child: Text(_horaAsignada != null ? 'Hora: $_horaAsignada' : 'Sin hora configurada', style: TextStyle(fontSize: 12, color: AppColors.primary))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _FormField(
                              label: 'Teléfono', controller: _telefonoCtrl, hint: '3XX XXX XXXX',
                              keyboardType: TextInputType.phone, maxLength: 10,
                              inputFormatters: [filtroSoloNumeros],
                              validator: validarTelefono,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _FormField(
                              label: 'Correo', controller: _correoCtrl, hint: 'correo@udes.edu.co',
                              keyboardType: TextInputType.emailAddress, maxLength: 254,
                              inputFormatters: [filtroSinEspacios],
                              validator: validarCorreo,
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_error!,
                      style: TextStyle(color: AppColors.errorText, fontSize: 13)),
                ),
              ],
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
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  const _FormField({
    required this.label,
    required this.controller,
    required this.hint,
    this.validator,
    this.inputFormatters,
    this.keyboardType,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          // counterText vacío: se respeta el límite sin mostrar el contador.
          decoration: InputDecoration(hintText: hint, counterText: ''),
          validator: validator ?? (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
        ),
      ],
    );
  }
}