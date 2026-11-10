import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_provider.dart';
import '../navegacion.dart';
import '../widgets/shell/app_rail.dart';
import '../widgets/shell/barra_superior.dart';
import '../widgets/shell/cierre_inactividad.dart';
import '../widgets/shell/cierre_jornada.dart';
import 'dashboard/dashboard_screen.dart';
import 'graduandos/graduandos_screen.dart';
import 'invitaciones/invitaciones_screen.dart';
import 'control_acceso/control_acceso_screen.dart';
import 'control_acceso/ceremonia_screen.dart';
import 'control_acceso/registro_screen.dart';
import 'notificaciones/notificaciones_screen.dart';
import 'usuarios/usuarios_screen.dart';
import 'directivos/directivos_screen.dart';
import 'bitacora/bitacora_screen.dart';
import 'configuracion_screen.dart';

/// Armazón de la app después de iniciar sesión: el menú lateral a la
/// izquierda y la pantalla elegida a la derecha. Cada pantalla dibuja su
/// propio encabezado (título, datos y botones), como en el lienzo.
///
/// El menú del administrador tiene las 6 opciones del diseño. Recordatorio,
/// Bitácora y Usuarios no salen en el menú: se abren desde un botón
/// o enlace y el menú deja marcada la opción de la que vienen (ver
/// navegacion.dart).
///
/// La sesión del administrador se cierra sola tras 15 minutos sin uso
/// (ver cierre_inactividad.dart).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final Map<int, Widget> _admin = {
    Nav.inicio: const DashboardScreen(),
    Nav.graduandos: const GraduandosScreen(),
    Nav.invitados: const InvitacionesScreen(),
    Nav.directivos: const DirectivosScreen(),
    Nav.ceremonia: const CeremoniaScreen(),
    Nav.ajustes: const ConfiguracionScreen(),
    Nav.recordatorio: const NotificacionesScreen(),
    Nav.bitacora: const BitacoraScreen(),
    Nav.usuarios: const UsuariosScreen(),
  };

  static final Map<int, Widget> _operador = {
    NavOperador.acceso: const ControlAccesoScreen(),
    NavOperador.registro: const RegistroScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final esAdmin = provider.isAdmin;
    final menu = esAdmin ? Nav.menu : NavOperador.menu;
    final pantallas = esAdmin ? _admin : _operador;
    final i = pantallas.containsKey(provider.selectedIndex) ? provider.selectedIndex : 0;
    final marcado = esAdmin ? Nav.opcionDelMenu(i) : i;

    final contenido = EnShell(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        // Que cada pantalla ocupe todo el espacio y empiece arriba (por
        // defecto la animación centra el contenido que es más bajo).
        layoutBuilder: (actual, anteriores) => Stack(
          fit: StackFit.expand,
          children: [...anteriores, if (actual != null) actual],
        ),
        child: KeyedSubtree(key: ValueKey(i), child: pantallas[i]!),
      ),
    );

    // Celular: barra arriba y el menú en un panel que se desliza.
    if (MediaQuery.sizeOf(context).width < 800) {
      return CierrePorInactividad(
        activo: esAdmin,
        alVencer: provider.logout,
        child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          // Admin: el título ya sale en cada pantalla. Operador: en el lector
          // no hay encabezado, así que la barra dice dónde está leyendo.
          title: Text(
            !esAdmin && i == NavOperador.acceso ? 'Control de acceso' : 'Apolo UDES',
            style: const TextStyle(fontSize: 16),
          ),
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
                    selected: k == marcado,
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
        ),
      );
    }

    // Tablet y computador: menú lateral fijo de 100 px.
    return CierrePorInactividad(
      activo: esAdmin,
      alVencer: provider.logout,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            AppRail(opciones: menu, marcado: marcado),
            Expanded(child: RepaintBoundary(child: contenido)),
          ],
        ),
      ),
    );
  }
}
