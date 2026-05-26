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

    final admins = usuarios.where((u) => u.rol == RolUsuario.administrador).length;
    final operadores = usuarios.where((u) => u.rol == RolUsuario.operador).length;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Usuarios',
            subtitle: 'Personal con acceso al sistema',
            action: ElevatedButton.icon(
              onPressed: () => _showUserDialog(context),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Nuevo usuario'),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _RoleCard(
                label: 'Administradores',
                count: admins,
                description: RolUsuario.administrador.description,
                color: AppColors.primaryLight,
                icon: Icons.admin_panel_settings_rounded,
              ),
              const SizedBox(width: 16),
              _RoleCard(
                label: 'Operadores',
                count: operadores,
                description: RolUsuario.operador.description,
                color: AppColors.success,
                icon: Icons.manage_accounts_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Card(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(3),
                      2: FlexColumnWidth(2),
                      3: FlexColumnWidth(1.5),
                      4: FlexColumnWidth(2),
                      5: FlexColumnWidth(2.5), // ← más ancha para los botones
                    },
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceVariant,
                        ),
                        children: [
                          'Usuario',
                          'Correo',
                          'Rol',
                          'Estado',
                          'Último acceso',
                          'Acciones',
                        ]
                            .map(
                              (h) => Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
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
                      ...usuarios.asMap().entries.map((entry) {
                        final i = entry.key;
                        final u = entry.value;
                        return TableRow(
                          decoration: BoxDecoration(
                            color: i.isEven
                                ? Colors.white
                                : const Color(0xFFFAFBFC),
                            border: const Border(
                              bottom: BorderSide(color: AppColors.divider),
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  UserAvatar(name: u.nombre, size: 34),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      u.nombre,
                                      style: AppTextStyles.body.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _cell(u.correo),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: _RoleBadge(rol: u.rol),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: u.estado == EstadoUsuario.activo
                                          ? AppColors.success
                                          : AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Text(
                                    u.estado == EstadoUsuario.activo
                                        ? 'Activo'
                                        : 'Inactivo',
                                    style: AppTextStyles.body,
                                  ),
                                ],
                              ),
                            ),
                            _cell(
                              DateFormat('dd/MM/yyyy HH:mm')
                                  .format(u.ultimoAcceso),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded,
                                        size: 18),
                                    color: AppColors.primaryLight,
                                    tooltip: 'Editar',
                                    onPressed: () =>
                                        _showUserDialog(context, usuario: u),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18),
                                    color: AppColors.error,
                                    tooltip: 'Eliminar',
                                    onPressed: () async {
                                      final confirm = await showConfirmDialog(
                                        context,
                                        title: 'Eliminar usuario',
                                        content:
                                            '¿Está seguro de eliminar a ${u.nombre}?',
                                        confirmLabel: 'Eliminar',
                                        isDangerous: true,
                                      );
                                      if (confirm == true && context.mounted) {
                                        context
                                            .read<AppProvider>()
                                            .eliminarUsuario(u.id);
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
              ),
            ),
          ),
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

  void _showUserDialog(BuildContext context, {Usuario? usuario}) {
    showDialog(
      context: context,
      builder: (_) => _UsuarioDialog(usuario: usuario),
    );
  }
}

// ── Badge de rol ──
class _RoleBadge extends StatelessWidget {
  final RolUsuario rol;

  const _RoleBadge({required this.rol});

  @override
  Widget build(BuildContext context) {
    final isAdmin = rol == RolUsuario.administrador;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.primaryLight.withOpacity(0.1)
            : AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        rol.label,
        style: TextStyle(
          color: isAdmin ? AppColors.primaryLight : AppColors.success,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Tarjeta de rol ──
class _RoleCard extends StatelessWidget {
  final String label;
  final int count;
  final String description;
  final Color color;
  final IconData icon;

  const _RoleCard({
    required this.label,
    required this.count,
    required this.description,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: AppTextStyles.h4),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog crear/editar usuario ──
class _UsuarioDialog extends StatefulWidget {
  final Usuario? usuario;

  const _UsuarioDialog({this.usuario});

  @override
  State<_UsuarioDialog> createState() => _UsuarioDialogState();
}

class _UsuarioDialogState extends State<_UsuarioDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _correoCtrl;
  late final TextEditingController _passwordCtrl;
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
      provider.editarUsuario(
        widget.usuario!.copyWith(
          nombre: _nombreCtrl.text.trim(),
          correo: _correoCtrl.text.trim(),
          rol: _rol,
          estado: _estado,
          // Si ingresó nueva contraseña la actualiza, si no la deja igual
          password: _passwordCtrl.text.isNotEmpty
              ? _passwordCtrl.text
              : widget.usuario!.password,
        ),
      );
    } else {
      provider.agregarUsuario(
        Usuario(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nombre: _nombreCtrl.text.trim(),
          correo: _correoCtrl.text.trim(),
          rol: _rol,
          estado: _estado,
          ultimoAcceso: DateTime.now(),
          password: _passwordCtrl.text,
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isEditing ? 'Editar usuario' : 'Nuevo usuario',
                      style: AppTextStyles.h2,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Nombre
                _fieldLabel('Nombre completo'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(hintText: 'Dr. Juan Pérez'),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 16),

                // Correo
                _fieldLabel('Correo institucional'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _correoCtrl,
                  decoration: const InputDecoration(
                    hintText: 'correo@udes.edu.co',
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 16),

                // Contraseña
                _fieldLabel(isEditing
                    ? 'Nueva contraseña (dejar vacío para no cambiar)'
                    : 'Contraseña'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (!isEditing && (v == null || v.isEmpty)) {
                      return 'La contraseña es requerida';
                    }
                    if (v != null && v.isNotEmpty && v.length < 6) {
                      return 'Mínimo 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Rol
                _fieldLabel('Rol'),
                const SizedBox(height: 6),
                DropdownButtonFormField<RolUsuario>(
                  value: _rol,
                  items: RolUsuario.values
                      .map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(r.label),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _rol = v!),
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 16),

                // Estado
                _fieldLabel('Estado'),
                const SizedBox(height: 6),
                DropdownButtonFormField<EstadoUsuario>(
                  value: _estado,
                  items: EstadoUsuario.values
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                              e == EstadoUsuario.activo ? 'Activo' : 'Inactivo'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _estado = v!),
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        child: Text(
                            isEditing ? 'Guardar cambios' : 'Crear usuario'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }
}