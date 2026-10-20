import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/usuarios_service.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';

// ── Validaciones del formulario ──

final _regexNombre =
    RegExp(r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ][A-Za-zÁÉÍÓÚÜÑáéíóúüñ .'\-]{1,79}$");
final _regexCorreo = RegExp(
    r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');
final _regexPunto = RegExp(r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9 \-]{2,40}$');

String? _validarNombre(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Requerido';
  if (!_regexNombre.hasMatch(t)) {
    return 'Solo letras, espacios, punto, guion o apostrofo';
  }
  if (t.replaceAll(RegExp(r"[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]"), '').length < 3) {
    return 'Nombre demasiado corto';
  }
  if (t.contains('  ')) return 'Hay espacios dobles';
  return null;
}

String? _validarCorreo(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Requerido';
  if (t.length > 254 || !_regexCorreo.hasMatch(t) || t.contains('..')) {
    return 'Correo no valido';
  }
  return null;
}

String? _validarPunto(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return 'Requerido para operadores';
  if (!_regexPunto.hasMatch(t)) return 'Solo letras, numeros y espacios';
  return null;
}

Usuario? _usuarioDesdeDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final d = doc.data();
  final estado = d['estado'] as String? ?? 'activo';
  if (estado == 'eliminado') return null;
  final correo = d['correo'] as String? ?? '';
  final nombre = (d['nombre'] as String?)?.trim() ?? '';
  return Usuario(
    id: doc.id,
    nombre: nombre.isNotEmpty ? nombre : correo.split('@').first,
    correo: correo,
    password: '',
    rol: d['rol'] == 'admin' ? RolUsuario.administrador : RolUsuario.operador,
    estado: estado == 'activo' ? EstadoUsuario.activo : EstadoUsuario.inactivo,
    ultimoAcceso: DateTime.now(),
    puntoValidacion: d['puntoValidacion'] as String?,
  );
}

class UsuariosScreen extends StatelessWidget {
  const UsuariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final actual = provider.usuarioActual;
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
                child: SectionHeader(
                    title: 'Usuarios',
                    subtitle: 'Personal con acceso al sistema')),
            ElevatedButton.icon(
              onPressed: () => _abrirDialogo(context),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: Text(isMobile ? 'Nuevo' : 'Nuevo usuario'),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                      child: Text('No fue posible cargar los usuarios: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final usuarios = snap.data!.docs
                    .map(_usuarioDesdeDoc)
                    .whereType<Usuario>()
                    .toList()
                  ..sort((a, b) =>
                      a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));

                final admins =
                    usuarios.where((u) => u.rol == RolUsuario.administrador).length;
                final operadores =
                    usuarios.where((u) => u.rol == RolUsuario.operador).length;

                final tarjetas = [
                  _RoleCard(
                      label: 'Administradores',
                      count: admins,
                      description: RolUsuario.administrador.description,
                      color: AppColors.primaryLight,
                      icon: Icons.admin_panel_settings_rounded),
                  _RoleCard(
                      label: 'Operadores',
                      count: operadores,
                      description: RolUsuario.operador.description,
                      color: AppColors.success,
                      icon: Icons.manage_accounts_rounded),
                ];

                return Column(children: [
                  if (isMobile)
                    Column(children: [
                      tarjetas[0],
                      const SizedBox(height: 8),
                      tarjetas[1],
                    ])
                  else
                    Row(children: [
                      tarjetas[0],
                      const SizedBox(width: 12),
                      tarjetas[1],
                    ]),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: usuarios.isEmpty
                            ? const EmptyState(
                                icon: Icons.people_outline_rounded,
                                title: 'Sin usuarios',
                                subtitle: 'Agrega el primer usuario del sistema')
                            : isMobile
                                ? _UsuariosList(usuarios: usuarios, actualId: actual?.id)
                                : _UsuariosTable(usuarios: usuarios, actualId: actual?.id),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Acciones compartidas ──

void _abrirDialogo(BuildContext context, {Usuario? usuario}) {
  showDialog(
      context: context,
      builder: (_) => _UsuarioDialog(usuario: usuario));
}

Future<void> _eliminar(BuildContext context, Usuario u) async {
  final autor = context.read<AppProvider>().usuarioActual;
  final messenger = ScaffoldMessenger.of(context);

  if (autor == null) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Sesion no valida. Vuelve a iniciar sesion.')));
    return;
  }

  final confirm = await showConfirmDialog(context,
      title: 'Eliminar usuario',
      content:
          '¿Eliminar a ${u.nombre}? Perderá el acceso de inmediato. La acción queda registrada en la bitácora.',
      confirmLabel: 'Eliminar',
      isDangerous: true);
  if (confirm != true) return;

  messenger.showSnackBar(SnackBar(
      content: Text('Eliminando a ${u.nombre}...'),
      duration: const Duration(seconds: 2)));

  try {
    await UsuariosService.eliminar(usuario: u, autor: autor);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.success,
        content: Text('${u.nombre} fue eliminado')));
  } on AuthException catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.error, content: Text(e.mensaje)));
  } catch (e) {
    debugPrint('Error eliminando usuario ${u.id}: $e');
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 10),
        content: Text('No fue posible eliminar: $e')));
  }
}

Future<void> _reenviar(BuildContext context, Usuario u) async {
  final autor = context.read<AppProvider>().usuarioActual;
  if (autor == null) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await UsuariosService.reenviarActivacion(usuario: u, autor: autor);
    messenger.showSnackBar(
        SnackBar(content: Text('Correo de contraseña enviado a ${u.correo}')));
  } catch (e) {
    debugPrint('Error reenviando correo a ${u.correo}: $e');
    messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 10),
        content: Text('No fue posible enviar el correo: $e')));
  }
}

class _Acciones extends StatelessWidget {
  final Usuario usuario;
  final bool esPropio;
  final double size;
  const _Acciones({required this.usuario, required this.esPropio, this.size = 18});

  @override
  Widget build(BuildContext context) {
    const c = BoxConstraints(minWidth: 32, minHeight: 32);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
          tooltip: 'Editar',
          icon: Icon(Icons.edit_rounded, size: size),
          color: AppColors.primaryLight,
          onPressed: () => _abrirDialogo(context, usuario: usuario),
          constraints: c,
          padding: EdgeInsets.zero),
      IconButton(
          tooltip: 'Reenviar correo de contraseña',
          icon: Icon(Icons.mark_email_unread_rounded, size: size),
          color: AppColors.info,
          onPressed: () => _reenviar(context, usuario),
          constraints: c,
          padding: EdgeInsets.zero),
      if (!esPropio)
        IconButton(
            tooltip: 'Eliminar',
            icon: Icon(Icons.delete_outline_rounded, size: size),
            color: AppColors.error,
            onPressed: () => _eliminar(context, usuario),
            constraints: c,
            padding: EdgeInsets.zero),
    ]);
  }
}

class _EstadoPunto extends StatelessWidget {
  final EstadoUsuario estado;
  const _EstadoPunto({required this.estado});
  @override
  Widget build(BuildContext context) {
    final activo = estado == EstadoUsuario.activo;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
              color: activo ? AppColors.success : AppColors.error,
              shape: BoxShape.circle)),
      Text(activo ? 'Activo' : 'Inactivo', style: AppTextStyles.body),
    ]);
  }
}

// ── Lista (móvil) ──

class _UsuariosList extends StatelessWidget {
  final List<Usuario> usuarios;
  final String? actualId;
  const _UsuariosList({required this.usuarios, required this.actualId});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: usuarios.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final u = usuarios[i];
        final esPropio = u.id == actualId;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.surface, // antes: Colors.white fijo
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider)),
          child: Row(children: [
            UserAvatar(name: u.nombre, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(esPropio ? '${u.nombre} (tú)' : u.nombre,
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(u.correo,
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (u.puntoValidacion != null && u.puntoValidacion!.isNotEmpty)
                      Text('Punto: ${u.puntoValidacion}', style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [_RoleBadge(rol: u.rol), _EstadoPunto(estado: u.estado)],
                    ),
                  ]),
            ),
            _Acciones(usuario: u, esPropio: esPropio, size: 16),
          ]),
        );
      },
    );
  }
}

// ── Tabla (escritorio / tablet) ──

class _UsuariosTable extends StatelessWidget {
  final List<Usuario> usuarios;
  final String? actualId;
  const _UsuariosTable({required this.usuarios, required this.actualId});

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder da el ancho REAL disponible (ya sin el sidebar).
    // Antes se usaba el ancho de toda la ventana y la columna
    // "Acciones" quedaba escondida a la derecha.
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: c.maxWidth),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(3),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(1.6),
                5: FlexColumnWidth(1.8),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: AppColors.surfaceVariant),
                  children: ['Usuario', 'Correo', 'Rol', 'Punto', 'Estado', 'Acciones']
                      .map((h) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Text(h,
                              style: AppTextStyles.label.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary))))
                      .toList(),
                ),
                ...usuarios.asMap().entries.map((entry) {
                  final i = entry.key;
                  final u = entry.value;
                  final esPropio = u.id == actualId;
                  return TableRow(
                    decoration: BoxDecoration(
                        // antes: Colors.white / 0xFFFAFBFC fijos
                        color: i.isEven
                            ? AppColors.surface
                            : AppColors.surfaceVariant.withValues(alpha: 0.35),
                        border: Border(
                            bottom: BorderSide(color: AppColors.divider))),
                    children: [
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(children: [
                            UserAvatar(name: u.nombre, size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(
                                    esPropio ? '${u.nombre} (tú)' : u.nombre,
                                    style: AppTextStyles.body
                                        .copyWith(fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                          ])),
                      _cell(u.correo),
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Align(
                              alignment: Alignment.centerLeft,
                              child: _RoleBadge(rol: u.rol))),
                      _cell(u.puntoValidacion ?? '—'),
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: _EstadoPunto(estado: u.estado)),
                      Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: _Acciones(usuario: u, esPropio: esPropio)),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(text,
          style: AppTextStyles.body, maxLines: 2, overflow: TextOverflow.ellipsis));
}

class _RoleBadge extends StatelessWidget {
  final RolUsuario rol;
  const _RoleBadge({required this.rol});
  @override
  Widget build(BuildContext context) {
    final isAdmin = rol == RolUsuario.administrador;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: isAdmin
              ? AppColors.primaryLight.withValues(alpha: 0.1)
              : AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(rol.label,
          style: TextStyle(
              color: isAdmin ? AppColors.primaryLight : AppColors.success,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String label, description;
  final int count;
  final Color color;
  final IconData icon;
  const _RoleCard(
      {required this.label,
      required this.count,
      required this.description,
      required this.color,
      required this.icon});
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(label,
                    style: AppTextStyles.h4,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('$count',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w700, fontSize: 13))),
          ]),
          Text(description,
              style: AppTextStyles.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
    return isMobile ? card : Expanded(child: card);
  }
}

// ── Diálogo crear / editar ──

class _UsuarioDialog extends StatefulWidget {
  final Usuario? usuario;
  const _UsuarioDialog({this.usuario});
  @override
  State<_UsuarioDialog> createState() => _UsuarioDialogState();
}

class _UsuarioDialogState extends State<_UsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl, _correoCtrl, _puntoCtrl;
  late RolUsuario _rol;
  late EstadoUsuario _estado;
  bool _guardando = false;
  String? _error;

  bool get _editando => widget.usuario != null;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nombreCtrl = TextEditingController(text: u?.nombre ?? '');
    _correoCtrl = TextEditingController(text: u?.correo ?? '');
    _puntoCtrl = TextEditingController(text: u?.puntoValidacion ?? '');
    _rol = u?.rol ?? RolUsuario.operador;
    _estado = u?.estado ?? EstadoUsuario.activo;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _puntoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final autor = context.read<AppProvider>().usuarioActual;
    if (autor == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _guardando = true);

    try {
      String mensaje;
      if (_editando) {
        await UsuariosService.editar(
          usuario: widget.usuario!,
          nombre: _nombreCtrl.text,
          rol: _rol,
          puntoValidacion: _puntoCtrl.text,
          estado: _estado,
          autor: autor,
        );
        mensaje = 'Usuario actualizado';
      } else {
        final reactivado = await UsuariosService.crear(
          nombre: _nombreCtrl.text,
          correo: _correoCtrl.text,
          rol: _rol,
          puntoValidacion: _puntoCtrl.text,
          autor: autor,
        );
        mensaje = reactivado
            ? 'Usuario reactivado. Se envió el correo para crear su contraseña.'
            : 'Usuario creado. Se envió el correo para crear su contraseña.';
      }
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(mensaje)));
    } on AuthException catch (e) {
      setState(() => _error = e.mensaje);
    } catch (e) {
      debugPrint('Error guardando usuario: $e');
      setState(() => _error = 'No fue posible guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actualId = context.read<AppProvider>().usuarioActual?.id;
    final esPropio = _editando && widget.usuario!.id == actualId;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
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
                        child: Text(_editando ? 'Editar usuario' : 'Nuevo usuario',
                            style: AppTextStyles.h2)),
                    IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _guardando ? null : () => Navigator.pop(context)),
                  ]),
                  const SizedBox(height: 16),
                  _label('Nombre completo'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nombreCtrl,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 80,
                    decoration: const InputDecoration(
                        hintText: 'Juan Pérez', counterText: ''),
                    validator: _validarNombre,
                  ),
                  const SizedBox(height: 12),
                  _label('Correo'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _correoCtrl,
                    enabled: !_editando,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                        hintText: 'correo@udes.edu.co',
                        helperText: _editando ? 'El correo no se puede cambiar' : null),
                    validator: _editando ? null : _validarCorreo,
                  ),
                  const SizedBox(height: 12),
                  _label('Rol'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<RolUsuario>(
                    initialValue: _rol,
                    items: RolUsuario.values
                        .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                        .toList(),
                    onChanged: esPropio ? null : (v) => setState(() => _rol = v!),
                    decoration: InputDecoration(
                        helperText: esPropio ? 'No puedes cambiar tu propio rol' : null),
                  ),
                  if (_rol == RolUsuario.operador) ...[
                    const SizedBox(height: 12),
                    _label('Punto de validación'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _puntoCtrl,
                      maxLength: 40,
                      decoration: const InputDecoration(
                          hintText: 'Entrada Principal', counterText: ''),
                      validator: _validarPunto,
                    ),
                  ],
                  if (_editando) ...[
                    const SizedBox(height: 12),
                    _label('Estado'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<EstadoUsuario>(
                      initialValue: _estado,
                      items: EstadoUsuario.values
                          .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e == EstadoUsuario.activo ? 'Activo' : 'Inactivo')))
                          .toList(),
                      onChanged: esPropio ? null : (v) => setState(() => _estado = v!),
                    ),
                  ],
                  if (!_editando) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.infoLight,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.mail_outline_rounded,
                                color: AppColors.info, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Se enviará un correo a esta dirección para que el usuario cree su propia contraseña. Nadie más la conocerá.',
                                style: TextStyle(color: AppColors.info, fontSize: 12),
                              ),
                            ),
                          ]),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton(
                            onPressed: _guardando ? null : () => Navigator.pop(context),
                            child: const Text('Cancelar'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _guardando ? null : _guardar,
                        child: _guardando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(_editando ? 'Guardar' : 'Crear usuario'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary));
}