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
    const ConfiguracionScreen(),
  ];

  static final List<Widget> _operadorScreens = [
    const DashboardScreen(),
    const GraduandosScreen(),
    const InvitacionesScreen(),
    const ConfirmacionScreen(),
    const ControlAccesoScreen(),
    const NotificacionesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final selectedIndex = provider.selectedIndex;
    final screens = provider.isAdmin ? _adminScreens : _operadorScreens;
    final safeIndex = selectedIndex.clamp(0, screens.length - 1);

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