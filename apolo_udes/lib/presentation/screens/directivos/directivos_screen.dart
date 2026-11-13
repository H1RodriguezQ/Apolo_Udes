import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/models.dart';
import '../../../data/services/usuarios_service.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';
import '../../widgets/common/apolo_ui.dart';

// ── Validaciones del formulario de directivos ──

final _dirRegexNombre =
    RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ][A-Za-zÁÉÍÓÚÜÑáéíóúüñ .'\-]{1,79}$");
final _dirRegexCargo =
    RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ][A-Za-zÁÉÍÓÚÜÑáéíóúüñ .,'()/\-]{1,59}$");
final _dirRegexCorreo = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');
// Celular colombiano (3XXXXXXXXX) o fijo con indicativo nuevo (60XXXXXXXX).
final _dirRegexTelefono = RegExp(r'^(3\d{9}|60\d{8})$');

String? _validarNombreDirectivo(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Requerido';
  if (!_dirRegexNombre.hasMatch(t)) {
    return 'Solo letras, espacios, punto, guion o apostrofo';
  }
  if (t.replaceAll(RegExp(r"[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]"), '').length < 3) {
    return 'Nombre demasiado corto';
  }
  if (t.contains('  ')) return 'Hay espacios dobles';
  return null;
}

String? _validarCargo(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Requerido';
  if (!_dirRegexCargo.hasMatch(t)) return 'Solo letras y signos basicos';
  return null;
}

String? _validarCorreoDirectivo(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Requerido';
  if (t.length > 254 || !_dirRegexCorreo.hasMatch(t) || t.contains('..')) {
    return 'Correo no válido';
  }
  return null;
}

String? _validarTelefono(String? v) {
  final t = (v ?? '').replaceAll(RegExp(r'[\s\-]'), '');
  if (t.isEmpty) return null; // opcional
  if (!_dirRegexTelefono.hasMatch(t)) {
    return 'Celular de 10 digitos (3...) o fijo (60...)';
  }
  return null;
}

String _estadoAFirestore(EstadoDirectivo e) {
  switch (e) {
    case EstadoDirectivo.confirmado:
      return 'confirmado';
    case EstadoDirectivo.rechazado:
      return 'rechazado';
    case EstadoDirectivo.pendiente:
      return 'pendiente';
  }
}

// ── Bitacora ──

void _auditarDirectivo(BuildContext context, String accion) {
  final autor = context.read<AppProvider>().usuarioActual;
  if (autor == null) return;
  UsuariosService.auditar(autor, accion, tipo: 'directivo');
}

void _mostrarError(ScaffoldMessengerState messenger, String texto) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    backgroundColor: AppColors.error,
    duration: const Duration(seconds: 10),
    content: Text(texto),
  ));
}

void _mostrarExito(ScaffoldMessengerState messenger, String texto) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    backgroundColor: AppColors.success,
    content: Text(texto),
  ));
}

Future<void> _eliminarDirectivo(BuildContext context, Directivo d) async {
  final provider = context.read<AppProvider>();
  final messenger = ScaffoldMessenger.of(context);

  final confirm = await showConfirmDialog(
    context,
    title: 'Eliminar directivo',
    content:
        '¿Eliminar a ${d.nombre}? Su código QR dejará de ser válido. La acción queda registrada en la bitácora.',
    confirmLabel: 'Eliminar',
    isDangerous: true,
  );
  if (confirm != true) return;

  // Se borra primero en Firestore y se espera la respuesta: si falla,
  // el error se muestra en pantalla en lugar de perderse en la consola.
  try {
    await FirebaseFirestore.instance.collection('directivos').doc(d.id).delete();
  } catch (e) {
    _mostrarError(messenger, 'No fue posible eliminar: $e');
    return;
  }

  // Solo si Firestore confirmo: se actualiza la lista y la bitacora.
  await provider.eliminarDirectivo(d.id);
  final autor = provider.usuarioActual;
  if (autor != null) {
    UsuariosService.auditar(autor, 'Eliminó directivo ${d.nombre} (${d.cargo})',
        tipo: 'directivo');
  }
  _mostrarExito(messenger, '${d.nombre} fue eliminado');
}

class DirectivosScreen extends StatelessWidget {
  const DirectivosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final directivos = [...provider.directivos]..sort((a, b) => a.nombre.compareTo(b.nombre));
    final esAdmin = provider.isAdmin;
    final ancho = MediaQuery.sizeOf(context).width;

    final tabla = TablaApolo(
      vacio: 'Todavía no hay directivos invitados.',
      columnas: const [
        ColumnaTabla('Directivo', flex: 5),
        ColumnaTabla('Facultad', flex: 3),
        ColumnaTabla('Invitación', flex: 2),
        ColumnaTabla('Respuesta', flex: 2),
        ColumnaTabla('Acciones', flex: 3, derecha: true),
      ],
      filas: [
        for (final d in directivos)
          [
            CeldaTexto(d.nombre, debajo: d.cargo, fuerte: true),
            CeldaTexto(d.facultad ?? 'General'),
            switch (d.correoInvitacion) {
              'enviado' => const Etiqueta('Enviada', tono: TonoEtiqueta.ok),
              'pendiente' => const Etiqueta('En cola', tono: TonoEtiqueta.aviso),
              'error' => const Etiqueta('Con error', tono: TonoEtiqueta.error),
              _ => const Etiqueta('Sin enviar'),
            },
            switch (d.estado) {
              EstadoDirectivo.confirmado => const Etiqueta('Asistirá', tono: TonoEtiqueta.ok),
              EstadoDirectivo.rechazado => const Etiqueta('No asistirá', tono: TonoEtiqueta.error),
              EstadoDirectivo.pendiente => const Etiqueta('Sin respuesta', tono: TonoEtiqueta.aviso),
            },
            if (esAdmin)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AccionFila(icono: Icons.mail_outline, ayuda: 'Enviar invitación por correo', onPressed: () => _enviarInvitacionEmail(context, d)),
                  AccionFila(
                    icono: Icons.edit_outlined,
                    ayuda: 'Editar',
                    onPressed: () => showDialog(context: context, barrierDismissible: false, builder: (_) => _DirectivoDialog(directivo: d)),
                  ),
                  AccionFila(icono: Icons.delete_outline, ayuda: 'Eliminar', peligro: true, onPressed: () => _eliminarDirectivo(context, d)),
                ],
              )
            else
              const SizedBox.shrink(),
          ],
      ],
    );

    return PantallaApolo(
      encabezado: EncabezadoPantalla(
        titulo: 'Directivos',
        detalle: '${directivos.length} invitados a la mesa principal',
        acciones: [
          if (esAdmin && directivos.isNotEmpty)
            BotonSecundario(texto: 'Borrar todos', peligro: true, onPressed: () => _limpiarTodo(context, provider)),
          if (esAdmin && ancho < 1100)
            ElevatedButton(onPressed: () => _showAddDialog(context), child: const Text('Agregar directivo')),
          if (!esAdmin) const _SoloLectura(),
        ],
      ),
      // En tablet el formulario va fijo a la derecha, como en el lienzo; en
      // pantallas angostas se abre con el botón "Agregar directivo".
      cuerpo: esAdmin && ancho >= 1100
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: tabla),
                const SizedBox(width: 20),
                const SizedBox(width: 330, child: SingleChildScrollView(child: _DirectivoDialog(enPanel: true))),
              ],
            )
          : tabla,
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
    final messenger = ScaffoldMessenger.of(context);
    final lista = List<Directivo>.from(provider.directivos);
    final cantidad = lista.length;

    final confirm = await showConfirmDialog(
      context,
      title: 'Limpiar directivos',
      content:
          '¿Eliminar los $cantidad directivos? Sus códigos QR dejarán de ser válidos. La acción queda registrada en la bitácora.',
      confirmLabel: 'Eliminar todo',
      isDangerous: true,
    );
    if (confirm != true) return;

    // Borrado en un solo lote atomico: o se borran todos o ninguno.
    try {
      final db = FirebaseFirestore.instance;
      final lote = db.batch();
      for (final d in lista) {
        lote.delete(db.collection('directivos').doc(d.id));
      }
      await lote.commit();
    } catch (e) {
      _mostrarError(messenger, 'No fue posible limpiar: $e');
      return;
    }

    await provider.limpiarDirectivos();
    final autor = provider.usuarioActual;
    if (autor != null) {
      UsuariosService.auditar(
          autor, 'Eliminó todos los directivos ($cantidad registros)',
          tipo: 'directivo');
    }
    _mostrarExito(messenger, 'Se eliminaron $cantidad directivos');
  }
}

class _SoloLectura extends StatelessWidget {
  const _SoloLectura();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.visibility_outlined, size: 16, color: AppColors.warning),
        SizedBox(width: 6),
        Text('Solo lectura',
            style: TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );
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
    if (exito) _auditarDirectivo(context, 'Envió invitación a directivo ${d.nombre}');
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: exito ? AppColors.success : AppColors.error,
        content: Text(exito
            ? '✅ Invitación enviada exitosamente a ${d.correo}'
            : '❌ Falló el envío del correo electrónico.'),
      ),
    );
  }
}

// Lista para móvil
class _DirectivoDialog extends StatefulWidget {
  final Directivo? directivo;
  /// true = se dibuja como la tarjeta "Agregar directivo" al lado de la
  /// tabla (sin ventana); al guardar se limpia para agregar el siguiente.
  final bool enPanel;
  const _DirectivoDialog({this.directivo, this.enPanel = false});

  @override
  State<_DirectivoDialog> createState() => _DirectivoDialogState();
}

class _DirectivoDialogState extends State<_DirectivoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl, _cargoCtrl, _correoCtrl, _telCtrl;
  String? _facultad;
  EstadoDirectivo _estado = EstadoDirectivo.pendiente;
  bool _guardando = false;

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // ID aleatorio de Firestore (~120 bits): no se puede adivinar, a
    // diferencia de la fecha en milisegundos que se usaba antes.
    final id = widget.directivo?.id ??
        FirebaseFirestore.instance.collection('directivos').doc().id;

    final directivo = Directivo(
      id: id,
      nombre: _nombreCtrl.text.trim(),
      cargo: _cargoCtrl.text.trim(),
      correo: _correoCtrl.text.trim().toLowerCase(),
      facultad: _facultad,
      telefono: _telCtrl.text.replaceAll(RegExp(r'[\s\-]'), ''),
      estado: _estado,
      fechaConfirmacion: widget.directivo?.fechaConfirmacion,
      codigoQr: widget.directivo?.codigoQr,
    );

    setState(() => _guardando = true);

    if (isEditing) {
      await provider.editarDirectivo(directivo);
      // El metodo original no guarda el estado; se guarda aqui.
      try {
        await FirebaseFirestore.instance
            .collection('directivos')
            .doc(id)
            .update({'confirmacion': _estadoAFirestore(_estado)});
      } catch (e) {
        if (mounted) setState(() => _guardando = false);
        _mostrarError(messenger, 'Se guardaron los datos, pero no el estado: $e');
        return;
      }
      final autor = provider.usuarioActual;
      if (autor != null) {
        UsuariosService.auditar(autor,
            'Editó directivo ${directivo.nombre} (${directivo.cargo})',
            tipo: 'directivo');
      }
      navigator.pop();
      _mostrarExito(messenger, 'Directivo actualizado');
    } else {
      await provider.agregarDirectivo(directivo);
      final autor = provider.usuarioActual;
      if (autor != null) {
        UsuariosService.auditar(autor,
            'Agregó directivo ${directivo.nombre} (${directivo.cargo})',
            tipo: 'directivo');
      }
      if (widget.enPanel) {
        for (final c in [_nombreCtrl, _cargoCtrl, _correoCtrl, _telCtrl]) {
          c.clear();
        }
        setState(() {
          _guardando = false;
          _facultad = null;
        });
      } else {
        navigator.pop();
      }
      _mostrarExito(messenger, 'Directivo agregado: la invitación sale por correo en unos minutos');
    }
  }

  @override
  Widget build(BuildContext context) {
    final formulario = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
                child: Text(
                    isEditing ? 'Editar directivo' : 'Agregar directivo',
                    style: widget.enPanel ? AppTextStyles.h4.copyWith(fontSize: 17) : AppTextStyles.h2)),
            if (!widget.enPanel)
              IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _guardando ? null : () => Navigator.pop(context))
          ]),
          const SizedBox(height: 16),
          _fieldLabel('Nombre completo'),
          const SizedBox(height: 6),
          TextFormField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              decoration: const InputDecoration(hintText: 'Dr. Juan Pérez', counterText: ''),
              validator: _validarNombreDirectivo),
          const SizedBox(height: 12),
          _fieldLabel('Cargo'),
          const SizedBox(height: 6),
          TextFormField(
              controller: _cargoCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 60,
              decoration: const InputDecoration(hintText: 'Rector / Decano', counterText: ''),
              validator: _validarCargo),
          const SizedBox(height: 12),
          _fieldLabel('Correo'),
          const SizedBox(height: 6),
          TextFormField(
              controller: _correoCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'correo@udes.edu.co'),
              validator: _validarCorreoDirectivo),
          if (!widget.enPanel) ...[
            const SizedBox(height: 12),
            _fieldLabel('Teléfono (opcional)'),
            const SizedBox(height: 6),
            TextFormField(
                controller: _telCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 12,
                decoration: const InputDecoration(hintText: '3001234567', counterText: ''),
                validator: _validarTelefono),
          ],
          const SizedBox(height: 12),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Facultad', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            TextSpan(text: ' (define la hora)', style: AppTextStyles.label),
          ])),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _facultad,
            isExpanded: true,
            dropdownColor: AppColors.surface,
            decoration: const InputDecoration(hintText: 'General (todas)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('General (todas)')),
              ...AppConstants.facultades.map((f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (v) => setState(() => _facultad = v),
          ),
          if (isEditing) ...[
            const SizedBox(height: 12),
            _fieldLabel('Respuesta'),
            const SizedBox(height: 6),
            DropdownButtonFormField<EstadoDirectivo>(
              initialValue: _estado,
              dropdownColor: AppColors.surface,
              items: EstadoDirectivo.values.map((e) => DropdownMenuItem(value: e, child: Text(_estadoLabel(e)))).toList(),
              onChanged: (v) => setState(() => _estado = v!),
              decoration: const InputDecoration(),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _guardando ? null : _submit,
              child: _guardando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEditing ? 'Guardar cambios' : 'Guardar y enviar invitación'),
            ),
          ),
          if (!isEditing) ...[
            const SizedBox(height: 12),
            Text('Recibe un correo con su código QR y un enlace para responder si asiste. El envío sale en máximo 5 minutos.',
                style: AppTextStyles.bodySmall.copyWith(height: 1.5)),
          ],
        ],
      ),
    );

    if (widget.enPanel) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: formulario,
      );
    }
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
        child: Padding(padding: const EdgeInsets.all(24), child: SingleChildScrollView(child: formulario)),
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
      style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary));
}