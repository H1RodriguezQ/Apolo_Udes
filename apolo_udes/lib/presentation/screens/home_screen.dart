import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  static final List<Widget> _adminScreens = [
    const DashboardScreen(),
    const GraduandosScreen(),
    const InvitacionesScreen(),
    const ConfirmacionScreen(),
    const ControlAccesoScreen(),
    const NotificacionesScreen(),
    const UsuariosScreen(),
    const DirectivosScreen(),
    const ConfiguracionScreen(),
  ];

  static final List<Widget> _operadorScreens = [
    const DashboardScreen(),
    const GraduandosScreen(),
    const InvitacionesScreen(),
    const ConfirmacionScreen(),
    const ControlAccesoScreen(),
    const NotificacionesScreen(),
    const DirectivosScreen(),
  ];

  static final List<String> _adminTitles = [
    'Dashboard',
    'Graduandos',
    'Invitaciones',
    'Confirmación',
    'Control de Acceso',
    'Notificaciones',
    'Usuarios',
    'Directivos',
    'Configuración',
  ];

  static final List<String> _operadorTitles = [
    'Dashboard',
    'Graduandos',
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

    // Detectamos si la pantalla actual es de tamaño celular (ancho menor a 800px)
    final bool isMobile = MediaQuery.of(context).size.width < 800;

    if (isMobile) {
      // =======================================================
      // VISTA OPTIMIZADA PARA CELULAR (SAMSUNG GALAXY A54)
      // =======================================================
      return Scaffold(
        appBar: AppBar(
          title: Text(
            titles[safeIndex],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          backgroundColor: const Color(0xFF0F2547), // Color a juego con tu barra lateral
          foregroundColor: Colors.white,
          elevation: 1,
          // Flutter agregará el botón "hamburguesa" de manera automática aquí
        ),
        // Tu barra lateral actual se esconde dentro de este Drawer deslizante
        drawer: const Drawer(
          child: AppSidebar(),
        ),
        body: Container(
          color: const Color(0xFFF3F4F6),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: screens[safeIndex],
          ),
        ),
      );
    } else {
      // =======================================================
      // VISTA DE TABLET / WEB ORIGINAL (SIN NINGÚN CAMBIO)
      // =======================================================
      return Scaffold(
        body: Row(
          children: [
            const AppSidebar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: screens[safeIndex],
              ),
            ),
          ],
        ),
      );
    }
  }
}