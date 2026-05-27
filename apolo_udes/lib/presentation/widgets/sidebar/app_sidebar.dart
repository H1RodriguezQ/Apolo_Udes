import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../core/constants/app_constants.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  static const List<_SidebarItem> _allItems = [
    _SidebarItem(label: 'Dashboard', icon: Icons.dashboard_rounded, adminOnly: false),
    _SidebarItem(label: 'Graduandos', icon: Icons.school_rounded, adminOnly: false),
    _SidebarItem(label: 'Invitaciones', icon: Icons.mail_rounded, adminOnly: false),
    _SidebarItem(label: 'Confirmación', icon: Icons.check_circle_rounded, adminOnly: false),
    _SidebarItem(label: 'Control de Acceso', icon: Icons.qr_code_scanner_rounded, adminOnly: false),
    _SidebarItem(label: 'Notificaciones', icon: Icons.notifications_rounded, adminOnly: false),
    _SidebarItem(label: 'Usuarios', icon: Icons.people_rounded, adminOnly: true),
    _SidebarItem(label: 'Directivos', icon: Icons.person_outline_rounded, adminOnly: false),
    _SidebarItem(label: 'Configuración', icon: Icons.settings_rounded, adminOnly: true),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final selectedIndex = provider.selectedIndex;
    final isAdmin = provider.isAdmin;
    final usuario = provider.usuarioActual;

    final items = _allItems
        .where((item) => !item.adminOnly || isAdmin)
        .toList();

    return Container(
      width: 240,
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          // ── Header / Logo ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF1E3A5F), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Apolo UDES',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Sistema de Grado',
                            style: TextStyle(
                              color: AppColors.sidebarText,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'ACCESO RESTRINGIDO',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Navigation items con scroll ──
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder: (context, i) => _SidebarNavItem(
                item: items[i],
                isSelected: selectedIndex == i,
                onTap: () => provider.setSelectedIndex(i),
              ),
            ),
          ),

          // ── Footer con usuario real ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF1E3A5F), width: 1),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isAdmin ? AppColors.primaryLight : AppColors.success,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : Icons.badge_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAdmin ? 'Administrador' : 'Operador',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            usuario?.correo ?? '',
                            style: const TextStyle(
                              color: AppColors.sidebarText,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.read<AppProvider>().logout(),
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.sidebarText,
                        size: 16,
                      ),
                      tooltip: 'Cerrar sesión',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  AppConstants.appVersion,
                  style: const TextStyle(
                    color: Color(0xFF4A6785),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final String label;
  final IconData icon;
  final bool adminOnly;

  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.adminOnly,
  });
}

class _SidebarNavItem extends StatelessWidget {
  final _SidebarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.sidebarActive : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: isSelected ? Colors.white : AppColors.sidebarText,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.sidebarText,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}