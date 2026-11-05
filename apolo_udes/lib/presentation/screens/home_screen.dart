import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../widgets/shell/app_rail.dart';
import '../widgets/shell/barra_superior.dart';
import '../widgets/sidebar/app_sidebar.dart' show confirmarCierreJornada;
import 'dashboard/dashboard_screen.dart';
import 'graduandos/graduandos_screen.dart';
import 'invitaciones/invitaciones_screen.dart';
import 'confirmacion/confirmacion_screen.dart';
import 'control_acceso/control_acceso_screen.dart';
import 'notificaciones/notificaciones_screen.dart';
import 'usuarios/usuarios_screen.dart';
import 'directivos/directivos_screen.dart';
import 'bitacora/bitacora_screen.dart';
import 'configuracion_screen.dart';

/// Armazón de la app después de iniciar sesión: menú lateral a la izquierda,
/// barra con el título arriba y la pantalla elegida debajo.
///
/// Cada opción del menú tiene su pantalla en la MISMA posición de la lista
/// (`_admin` y `_operador`): el menú envía el índice y aquí se usa ese
/// índice para elegir qué mostrar.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ── Administrador ──
  static const _menuAdmin = [
    OpcionMenu('Inicio', 'Inicio', Icons.home_outlined),
    OpcionMenu('Graduandos', 'Graduandos', Icons.school_outlined),
    OpcionMenu('Invitados', 'Invitados', Icons.people_outline),
    OpcionMenu('Directivos', 'Directivos', Icons.person_outline),
    OpcionMenu('Acceso', 'Control de acceso', Icons.qr_code_scanner_rounded),
    OpcionMenu('Correos', 'Correos y recordatorios', Icons.mail_outline),
    OpcionMenu('Bitácora', 'Bitácora', Icons.list_alt_rounded),
    OpcionMenu('Ajustes', 'Ajustes', Icons.tune_rounded),
  ];

  static final List<Widget> _admin = [
    const DashboardScreen(),
    const GraduandosScreen(),
    const PantallaConPestanas(pestanas: [
      ('Invitaciones', InvitacionesScreen()),
      ('Confirmaciones', ConfirmacionScreen()),
    ]),
    const DirectivosScreen(),
    const ControlAccesoScreen(),
    const NotificacionesScreen(),
    const BitacoraScreen(),
    const PantallaConPestanas(pestanas: [
      ('Ceremonia', ConfiguracionScreen()),
      ('Usuarios', UsuariosScreen()),
    ]),
  ];

  // ── Operador de entrada: lo primero que ve es el control de acceso ──
  static const _menuOperador = [
    OpcionMenu('Acceso', 'Control de acceso', Icons.qr_code_scanner_rounded),
    OpcionMenu('Inicio', 'Inicio', Icons.home_outlined),
    OpcionMenu('Invitados', 'Invitados', Icons.people_outline),
    OpcionMenu('Directivos', 'Directivos', Icons.person_outline),
  ];

  static final List<Widget> _operador = [
    const ControlAccesoScreen(),
    const DashboardScreen(),
    const PantallaConPestanas(pestanas: [
      ('Invitaciones', InvitacionesScreen()),
      ('Confirmaciones', ConfirmacionScreen()),
    ]),
    const DirectivosScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final menu = provider.isAdmin ? _menuAdmin : _menuOperador;
    final pantallas = provider.isAdmin ? _admin : _operador;
    final i = provider.selectedIndex.clamp(0, pantallas.length - 1);

    final contenido = EnShell(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        // Que cada pantalla ocupe todo el espacio y empiece arriba (por
        // defecto la animación centra el contenido que es más bajo).
        layoutBuilder: (actual, anteriores) => Stack(
          fit: StackFit.expand,
          children: [...anteriores, if (actual != null) actual],
        ),
        child: KeyedSubtree(key: ValueKey(i), child: pantallas[i]),
      ),
    );

    // Celular: barra arriba y el menú en un panel que se desliza.
    if (MediaQuery.sizeOf(context).width < 800) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(menu[i].titulo),
          backgroundColor: AppColors.rail,
          foregroundColor: Colors.white,
        ),
        drawer: Drawer(
          backgroundColor: AppColors.rail,
          child: SafeArea(
            child: ListView(
              children: [
                for (var k = 0; k < menu.length; k++)
                  ListTile(
                    leading: Icon(menu[k].icono, color: Colors.white),
                    title: Text(menu[k].titulo, style: const TextStyle(color: Colors.white)),
                    selected: k == i,
                    selectedTileColor: AppColors.boton,
                    onTap: () {
                      provider.setSelectedIndex(k);
                      Navigator.of(context).pop();
                    },
                  ),
                const Divider(color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.event_busy_rounded, color: Colors.white),
                  title: const Text('Cerrar jornada', style: TextStyle(color: Colors.white)),
                  onTap: () => confirmarCierreJornada(context),
                ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.white),
                  title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
                  onTap: () => provider.logout(),
                ),
              ],
            ),
          ),
        ),
        body: contenido,
      );
    }

    // Tablet y computador: menú lateral fijo de 100 px.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          AppRail(opciones: menu),
          Expanded(
            child: Column(
              children: [
                BarraSuperior(titulo: menu[i].titulo),
                Expanded(child: RepaintBoundary(child: contenido)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
