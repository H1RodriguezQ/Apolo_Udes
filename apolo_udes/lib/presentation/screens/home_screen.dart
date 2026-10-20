import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../widgets/sidebar/app_sidebar.dart';
import 'dashboard/dashboard_screen.dart';
import 'graduandos/graduandos_screen.dart';
import 'invitaciones/invitaciones_screen.dart';
import 'confirmacion/confirmacion_screen.dart';
import 'control_acceso/control_acceso_screen.dart';
import 'notificaciones/notificaciones_screen.dart';
import 'usuarios/usuarios_screen.dart';
import 'directivos/directivos_screen.dart';
import 'configuracion_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // IMPORTANTE: este orden debe coincidir exactamente con el de
  // `_allItems` en app_sidebar.dart. El menu envia un indice y aqui se
  // usa ese mismo indice para elegir la pantalla.
  static final List<Widget> _adminScreens = [
    const DashboardScreen(),        // 0
    const GraduandosScreen(),       // 1
    const InvitacionesScreen(),     // 2
    const ConfirmacionScreen(),     // 3
    const ControlAccesoScreen(),    // 4
    const NotificacionesScreen(),   // 5
    const DirectivosScreen(),       // 6
    const UsuariosScreen(),         // 7
    const ConfiguracionScreen(),    // 8
  ];

  static final List<Widget> _operadorScreens = [
    const DashboardScreen(),        // 0
    const InvitacionesScreen(),     // 1
    const ConfirmacionScreen(),     // 2
    const ControlAccesoScreen(),    // 3
    const NotificacionesScreen(),   // 4
    const DirectivosScreen(),       // 5
  ];

  static final List<String> _adminTitles = [
    'Dashboard',
    'Graduandos',
    'Invitaciones',
    'Confirmación',
    'Control de Acceso',
    'Notificaciones',
    'Directivos',
    'Usuarios',
    'Configuración',
  ];

  static final List<String> _operadorTitles = [
    'Dashboard',
    'Invitaciones',
    'Confirmación',
    'Control de Acceso',
    'Notificaciones',
    'Directivos',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final selectedIndex = provider.selectedIndex;
    final screens = provider.isAdmin ? _adminScreens : _operadorScreens;
    final titles = provider.isAdmin ? _adminTitles : _operadorTitles;
    final safeIndex = selectedIndex.clamp(0, screens.length - 1);

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isMobile = screenWidth < 800;

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            titles[safeIndex],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.sidebarBg,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 1,
        ),
        // enDrawer: el menú se cierra solo al elegir una opción
        drawer: const Drawer(
          child: AppSidebar(enDrawer: true),
        ),
        body: Container(
          color: AppColors.background, // antes: Color(0xFFF3F4F6) fijo
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: screens[safeIndex],
          ),
        ),
      );
    } else {
      return Scaffold(
        body: Row(
          children: [
            const AppSidebar(),
            Expanded(
              // Aísla el repintado del contenido mientras el sidebar se anima
              child: RepaintBoundary(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: screens[safeIndex],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}