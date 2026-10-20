import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../common/selector_tema.dart';
import '../common/widgets.dart';

class AppSidebar extends StatelessWidget {
  /// true cuando el sidebar va dentro del Drawer (celular): siempre expandido
  /// y se cierra al elegir una opción.
  final bool enDrawer;
  const AppSidebar({super.key, this.enDrawer = false});

  /// Estado de colapso. Es estático para que no se pierda cuando la
  /// interfaz se reconstruye (por ejemplo, al cambiar de tema).
  static final ValueNotifier<bool> colapsado = ValueNotifier(false);

  static const double _anchoExpandido = 240;
  static const double _anchoColapsado = 76;

  static const List<_SidebarItem> _allItems = [
    _SidebarItem(
        label: 'Dashboard', icon: Icons.dashboard_rounded, adminOnly: false),
    _SidebarItem(
        label: 'Graduandos', icon: Icons.school_rounded, adminOnly: true),
    _SidebarItem(
        label: 'Invitaciones', icon: Icons.mail_rounded, adminOnly: false),
    _SidebarItem(
        label: 'Confirmación',
        icon: Icons.check_circle_rounded,
        adminOnly: false),
    _SidebarItem(
        label: 'Control de Acceso',
        icon: Icons.qr_code_scanner_rounded,
        adminOnly: false),
    _SidebarItem(
        label: 'Notificaciones',
        icon: Icons.notifications_rounded,
        adminOnly: false),
    _SidebarItem(
        label: 'Directivos',
        icon: Icons.person_outline_rounded,
        adminOnly: false),
    _SidebarItem(
        label: 'Usuarios', icon: Icons.people_rounded, adminOnly: true),
    _SidebarItem(
        label: 'Configuración', icon: Icons.settings_rounded, adminOnly: true),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final items =
        _allItems.where((item) => !item.adminOnly || provider.isAdmin).toList();

    // En el Drawer del celular: siempre expandido, sin animación de ancho.
    if (enDrawer) {
      return Container(
        color: AppColors.sidebarBg,
        child: _expandido(context, provider, items),
      );
    }

    // RepaintBoundary: la animación del sidebar no obliga a repintar
    // el resto de la pantalla.
    return RepaintBoundary(
      child: _SidebarAnimado(
        expandido: _expandido(context, provider, items),
        compacto: _compacto(context, provider, items),
      ),
    );
  }

  void _seleccionar(BuildContext context, AppProvider provider, int i) {
    provider.setSelectedIndex(i);
    if (enDrawer) Navigator.of(context).pop(); // cierra el drawer
  }

  // ════════════════════════════════════════════════════════════
  //  DISEÑO EXPANDIDO (el original)
  // ════════════════════════════════════════════════════════════
  Widget _expandido(
      BuildContext context, AppProvider provider, List<_SidebarItem> items) {
    final selectedIndex = provider.selectedIndex;
    final isAdmin = provider.isAdmin;
    final usuario = provider.usuarioActual;

    return Column(
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
                  const _Logo(size: 52),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apolo UDES',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Sistema de Grado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border:
                          Border.all(color: AppColors.accent.withOpacity(0.4)),
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
                  const Spacer(),
                  // Botón para contraer (no aplica dentro del drawer)
                  if (!enDrawer)
                    IconButton(
                      onPressed: () => colapsado.value = true,
                      icon: const Icon(Icons.menu_open_rounded,
                          color: AppColors.sidebarText, size: 20),
                      tooltip: 'Contraer menú',
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                ],
              ),
            ],
          ),
        ),

        // ── Navigation items ──
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (context, i) => _SidebarNavItem(
              item: items[i],
              isSelected: selectedIndex == i,
              compacto: false,
              onTap: () => _seleccionar(context, provider, i),
            ),
          ),
        ),

        // ── Footer ──
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF1E3A5F), width: 1),
            ),
          ),
          child: Column(
            children: [
              // Botón "Limpiar datos" solo para operador
              if (!isAdmin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _mostrarConfirmacionLimpiar(context),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                      label: const Text('Limpiar datos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  _AvatarRol(isAdmin: isAdmin),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAdmin ? 'Administrador' : 'Operador',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        Text(
                          usuario?.correo ?? '',
                          style: const TextStyle(
                              color: AppColors.sidebarText, fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const BotonTema(),
                  const _BotonCerrarJornada(),
                  _BotonSalir(),
                ],
              ),
              const SizedBox(height: 6),
              Text(AppConstants.appVersion,
                  style:
                      const TextStyle(color: Color(0xFF4A6785), fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  //  DISEÑO COMPACTO (solo íconos)
  // ════════════════════════════════════════════════════════════
  Widget _compacto(
      BuildContext context, AppProvider provider, List<_SidebarItem> items) {
    final selectedIndex = provider.selectedIndex;
    final isAdmin = provider.isAdmin;

    return Column(
      children: [
        // ── Header: logo + botón expandir ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF1E3A5F), width: 1),
            ),
          ),
          child: Column(
            children: [
              const Tooltip(
                message: 'Apolo UDES · Sistema de Grado',
                child: _Logo(size: 42),
              ),
              const SizedBox(height: 10),
              IconButton(
                onPressed: () => colapsado.value = false,
                icon: const Icon(Icons.menu_rounded,
                    color: AppColors.sidebarText, size: 20),
                tooltip: 'Expandir menú',
              ),
            ],
          ),
        ),

        // ── Navigation items ──
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (context, i) => _SidebarNavItem(
              item: items[i],
              isSelected: selectedIndex == i,
              compacto: true,
              onTap: () => _seleccionar(context, provider, i),
            ),
          ),
        ),

        // ── Footer ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF1E3A5F), width: 1),
            ),
          ),
          child: Column(
            children: [
              if (!isAdmin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IconButton(
                    onPressed: () => _mostrarConfirmacionLimpiar(context),
                    icon: const Icon(Icons.delete_sweep_rounded,
                        color: AppColors.error, size: 20),
                    tooltip: 'Limpiar datos',
                  ),
                ),
              Tooltip(
                message:
                    '${isAdmin ? 'Administrador' : 'Operador'}\n${provider.usuarioActual?.correo ?? ''}',
                child: _AvatarRol(isAdmin: isAdmin),
              ),
              const SizedBox(height: 8),
              const BotonTema(),
              const SizedBox(height: 4),
              const _BotonCerrarJornada(),
              _BotonSalir(),
            ],
          ),
        ),
      ],
    );
  }

  void _mostrarConfirmacionLimpiar(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Limpiar datos de ceremonia?'),
        content: const Text(
          'Esta acción eliminará todos los registros de validación y confirmaciones de esta ceremonia. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implementar lógica de limpieza
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Datos de ceremonia limpios')),
              );
            },
            child: const Text('Limpiar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Animación del ancho del sidebar ──
//
// Por qué es fluida:
// 1. El contenido expandido se dibuja SIEMPRE a 240 px dentro de un
//    OverflowBox y solo se recorta (ClipRect). Así, en cada frame, Flutter
//    no vuelve a calcular el layout de los textos, íconos ni del footer:
//    solo cambia el ancho del recorte.
// 2. Los dos diseños (expandido / compacto) se construyen una sola vez y se
//    reutilizan en cada frame; el AnimatedBuilder no los reconstruye.
// 3. El diseño compacto solo aparece cuando la animación de cerrar terminó.
class _SidebarAnimado extends StatefulWidget {
  final Widget expandido;
  final Widget compacto;
  const _SidebarAnimado({required this.expandido, required this.compacto});

  @override
  State<_SidebarAnimado> createState() => _SidebarAnimadoState();
}

class _SidebarAnimadoState extends State<_SidebarAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: AppSidebar.colapsado.value ? 0 : 1, // 1 = expandido
  );

  late final Animation<double> _curva = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    AppSidebar.colapsado.addListener(_alCambiar);
  }

  void _alCambiar() {
    if (AppSidebar.colapsado.value) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    AppSidebar.colapsado.removeListener(_alCambiar);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curva,
      builder: (context, _) {
        final ancho = lerpDouble(AppSidebar._anchoColapsado,
            AppSidebar._anchoExpandido, _curva.value)!;
        final mostrarCompacto = _controller.isDismissed;

        return Container(
          width: ancho,
          color: AppColors.sidebarBg,
          child: ClipRect(
            child: mostrarCompacto
                ? widget.compacto
                : OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: AppSidebar._anchoExpandido,
                    maxWidth: AppSidebar._anchoExpandido,
                    child: widget.expandido,
                  ),
          ),
        );
      },
    );
  }
}

// ── Piezas reutilizadas por ambos diseños ──

class _Logo extends StatelessWidget {
  final double size;
  const _Logo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/udes_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _AvatarRol extends StatelessWidget {
  final bool isAdmin;
  const _AvatarRol({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isAdmin ? AppColors.primaryLight : AppColors.success,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Icon(
        isAdmin ? Icons.admin_panel_settings_rounded : Icons.badge_rounded,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}

// Cierra la jornada: a diferencia de "Cerrar sesión", deja constancia en la
// bitácora de cuántos accesos se validaron hoy y de quién dio por terminado
// el día, para que el siguiente turno entre con su propio usuario.
class _BotonCerrarJornada extends StatelessWidget {
  const _BotonCerrarJornada();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _cerrarJornada(context),
      icon: const Icon(Icons.event_busy_rounded,
          color: AppColors.sidebarText, size: 16),
      tooltip: 'Cerrar jornada',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

Future<void> _cerrarJornada(BuildContext context) async {
  // El proveedor se captura ANTES del await: después del cierre ya no hay
  // contexto de sesión válido (la app vuelve a la pantalla de login).
  final provider = context.read<AppProvider>();
  final accesos = provider.accesosHoy;

  final confirm = await showConfirmDialog(
    context,
    title: 'Cerrar jornada',
    content: 'Se dejará constancia del cierre en la bitácora y se cerrará la '
        'sesión para que el siguiente turno inicie con su propio usuario. '
        'Accesos validados hoy: $accesos. ¿Continuar?',
    confirmLabel: 'Cerrar jornada',
    isDangerous: true,
  );
  if (confirm != true) return;

  await provider.cerrarJornada();
}

class _BotonSalir extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => context.read<AppProvider>().logout(),
      icon: const Icon(Icons.logout_rounded,
          color: AppColors.sidebarText, size: 16),
      tooltip: 'Cerrar sesión',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
    );
  }
}

class _SidebarItem {
  final String label;
  final IconData icon;
  final bool adminOnly;
  const _SidebarItem(
      {required this.label, required this.icon, required this.adminOnly});
}

class _SidebarNavItem extends StatelessWidget {
  final _SidebarItem item;
  final bool isSelected;
  final bool compacto;
  final VoidCallback onTap;
  const _SidebarNavItem({
    required this.item,
    required this.isSelected,
    required this.compacto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? Colors.white : AppColors.sidebarText;

    final contenido = compacto
        // Solo ícono, centrado
        ? Center(child: Icon(item.icon, color: color, size: 20))
        // Diseño original: ícono + texto + punto
        : Row(
            children: [
              Icon(item.icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle)),
            ],
          );

    final boton = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: compacto ? 44 : null,
          padding: compacto
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.sidebarActive : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: contenido,
        ),
      ),
    );

    // En modo compacto el nombre aparece al pasar el mouse
    return compacto
        ? Tooltip(
            message: item.label,
            waitDuration: const Duration(milliseconds: 300),
            child: boton,
          )
        : boton;
  }
}