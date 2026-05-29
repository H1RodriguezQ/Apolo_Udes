import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';

class UsuariosScreen extends StatelessWidget {
  const UsuariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final usuarios = provider.usuarios;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;
    final admins = usuarios.where((u) => u.rol == RolUsuario.administrador).length;
    final operadores = usuarios.where((u) => u.rol == RolUsuario.operador).length;

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
              onPressed: () => _showUserDialog(context),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: Text(isMobile ? 'Nuevo' : 'Nuevo usuario'),
            ),
          ]),
          const SizedBox(height: 16),
          if (isMobile)
            Column(children: [
              _RoleCard(
                  label: 'Administradores',
                  count: admins,
                  description: RolUsuario.administrador.description,
                  color: AppColors.primaryLight,
                  icon: Icons.admin_panel_settings_rounded),
              const SizedBox(height: 8),
              _RoleCard(
                  label: 'Operadores',
                  count: operadores,
                  description: RolUsuario.operador.description,
                  color: AppColors.success,
                  icon: Icons.manage_accounts_rounded),
            ])
          else
            Row(children: [
              _RoleCard(
                  label: 'Administradores',
                  count: admins,
                  description: RolUsuario.administrador.description,
                  color: AppColors.primaryLight,
                  icon: Icons.admin_panel_settings_rounded),
              const SizedBox(width: 12),
              _RoleCard(
                  label: 'Operadores',
                  count: operadores,
                  description: RolUsuario.operador.description,
                  color: AppColors.success,
                  icon: Icons.manage_accounts_rounded),
            ]),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isMobile
                    ? _UsuariosList(
                        usuarios: usuarios,
                        onEdit: (u) => _showUserDialog(context, usuario: u),
                        onDelete: (u) => _deleteUser(context, provider, u))
                    : _UsuariosTable(
                        usuarios: usuarios,
                        onEdit: (u) => _showUserDialog(context, usuario: u),
                        onDelete: (u) => _deleteUser(context, provider, u)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(
      BuildContext context, AppProvider provider, Usuario u) async {
    final confirm = await showConfirmDialog(context,
        title: 'Eliminar usuario',
        content: '¿Eliminar a ${u.nombre}?',
        confirmLabel: 'Eliminar',
        isDangerous: true);
    if (confirm == true && context.mounted) provider.eliminarUsuario(u.id);
  }

  void _showUserDialog(BuildContext context, {Usuario? usuario}) {
    showDialog(context: context, builder: (_) => _UsuarioDialog(usuario: usuario));
  }
}

class _UsuariosList extends StatelessWidget {
  final List<Usuario> usuarios;
  final Function(Usuario) onEdit, onDelete;
  const _UsuariosList(
      {required this.usuarios, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: usuarios.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final u = usuarios[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.divider)),
          child: Row(children: [
            UserAvatar(name: u.nombre, size: 40),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(u.nombre,
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(u.correo,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _RoleBadge(rol: u.rol),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: u.estado == EstadoUsuario.activo
                                      ? AppColors.success
                                      : AppColors.error,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(
                              u.estado == EstadoUsuario.activo
                                  ? 'Activo'
                                  : 'Inactivo',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ],
                  ),
                ])),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  color: AppColors.primaryLight,
                  onPressed: () => onEdit(u),
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero),
              IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  color: AppColors.error,
                  onPressed: () => onDelete(u),
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero),
            ]),
          ]),
        );
      },
    );
  }
}

class _UsuariosTable extends StatelessWidget {
  final List<Usuario> usuarios;
  final Function(Usuario) onEdit, onDelete;
  const _UsuariosTable(
      {required this.usuarios, required this.onEdit, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - 80),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
              4: FlexColumnWidth(2.5),
              5: FlexColumnWidth(1.5)
            },
            children: [
              TableRow(
                decoration:
                    const BoxDecoration(color: AppColors.surfaceVariant),
                children: ['Usuario', 'Correo', 'Rol', 'Estado', 'Último acceso', 'Acciones']
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
                return TableRow(
                  decoration: BoxDecoration(
                      color: i.isEven ? Colors.white : const Color(0xFFFAFBFC),
                      border: const Border(
                          bottom: BorderSide(color: AppColors.divider))),
                  children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(children: [
                          UserAvatar(name: u.nombre, size: 32),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(u.nombre,
                                  style: AppTextStyles.body
                                      .copyWith(fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis))
                        ])),
                    _cell(u.correo),
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: _RoleBadge(rol: u.rol)),
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                  color: u.estado == EstadoUsuario.activo
                                      ? AppColors.success
                                      : AppColors.error,
                                  shape: BoxShape.circle)),
                          Flexible(
                            child: Text(
                                u.estado == EstadoUsuario.activo
                                    ? 'Activo'
                                    : 'Inactivo',
                                style: AppTextStyles.body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ])),
                    _cell(DateFormat('dd/MM/yyyy\nHH:mm').format(u.ultimoAcceso)),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              color: AppColors.primaryLight,
                              onPressed: () => onEdit(u),
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero),
                          IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18),
                              color: AppColors.error,
                              onPressed: () => onDelete(u),
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              padding: EdgeInsets.zero),
                        ])),
                  ],
                );
              }),
            ],
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
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Text(label,
                        style: AppTextStyles.h4,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('$count',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 13))),
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

class _UsuarioDialog extends StatefulWidget {
  final Usuario? usuario;
  const _UsuarioDialog({this.usuario});
  @override
  State<_UsuarioDialog> createState() => _UsuarioDialogState();
}

class _UsuarioDialogState extends State<_UsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl, _correoCtrl, _passwordCtrl;
  late RolUsuario _rol;
  late EstadoUsuario _estado;
  bool _obscurePassword = true;
  bool get isEditing => widget.usuario != null;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    _nombreCtrl = TextEditingController(text: u?.nombre ?? '');
    _correoCtrl = TextEditingController(text: u?.correo ?? '');
    _passwordCtrl = TextEditingController();
    _rol = u?.rol ?? RolUsuario.operador;
    _estado = u?.estado ?? EstadoUsuario.activo;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();
    if (isEditing) {
      provider.editarUsuario(widget.usuario!.copyWith(
          nombre: _nombreCtrl.text.trim(),
          correo: _correoCtrl.text.trim(),
          rol: _rol,
          estado: _estado,
          password: _passwordCtrl.text.isNotEmpty
              ? _passwordCtrl.text
              : widget.usuario!.password));
    } else {
      provider.agregarUsuario(Usuario(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nombre: _nombreCtrl.text.trim(),
          correo: _correoCtrl.text.trim(),
          rol: _rol,
          estado: _estado,
          ultimoAcceso: DateTime.now(),
          password: _passwordCtrl.text));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
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
                              isEditing ? 'Editar usuario' : 'Nuevo usuario',
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
                    _fieldLabel('Correo institucional'),
                    const SizedBox(height: 6),
                    TextFormField(
                        controller: _correoCtrl,
                        decoration: const InputDecoration(
                            hintText: 'correo@udes.edu.co'),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Requerido' : null),
                    const SizedBox(height: 12),
                    _fieldLabel(isEditing
                        ? 'Nueva contraseña (opcional)'
                        : 'Contraseña'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                          hintText: '••••••••',
                          suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(() =>
                                  _obscurePassword = !_obscurePassword))),
                      validator: (v) {
                        if (!isEditing && (v == null || v.isEmpty))
                          return 'Requerida';
                        if (v != null && v.isNotEmpty && v.length < 6)
                          return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _fieldLabel('Rol'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<RolUsuario>(
                        value: _rol,
                        items: RolUsuario.values
                            .map((r) => DropdownMenuItem(
                                value: r, child: Text(r.label)))
                            .toList(),
                        onChanged: (v) => setState(() => _rol = v!),
                        decoration: const InputDecoration()),
                    const SizedBox(height: 12),
                    _fieldLabel('Estado'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<EstadoUsuario>(
                        value: _estado,
                        items: EstadoUsuario.values
                            .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e == EstadoUsuario.activo
                                    ? 'Activo'
                                    : 'Inactivo')))
                            .toList(),
                        onChanged: (v) => setState(() => _estado = v!),
                        decoration: const InputDecoration()),
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
                              child: Text(
                                  isEditing ? 'Guardar' : 'Crear usuario'))),
                    ]),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) => Text(label,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary));
}