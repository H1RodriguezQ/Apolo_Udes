import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/theme_provider.dart';
import '../sidebar/app_sidebar.dart' show confirmarCierreJornada;

/// Una opción del menú lateral.
class OpcionMenu {
  final String etiqueta; // texto corto bajo el icono
  final String titulo; // título de la barra superior
  final IconData icono;
  const OpcionMenu(this.etiqueta, this.titulo, this.icono);
}

/// Menú lateral angosto (100 px) del rediseño para tablets: escudo arriba,
/// opciones con icono y texto, y la cuenta abajo.
class AppRail extends StatelessWidget {
  final List<OpcionMenu> opciones;
  final int marcado; // opción resaltada (puede ser la "padre" de la pantalla)
  const AppRail({super.key, required this.opciones, required this.marcado});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Container(
      width: 100,
      color: AppColors.rail,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        children: [
          // Escudo de la universidad sobre un cuadro blanco.
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(7),
            child: Image.asset('assets/images/udes_escudo.png', fit: BoxFit.contain, filterQuality: FilterQuality.medium),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (var i = 0; i < opciones.length; i++)
                    _BotonMenu(
                      opcion: opciones[i],
                      activo: i == marcado,
                      onTap: () => provider.setSelectedIndex(i),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _BotonCuenta(),
        ],
      ),
    );
  }
}

class _BotonMenu extends StatelessWidget {
  final OpcionMenu opcion;
  final bool activo;
  final VoidCallback onTap;
  const _BotonMenu({required this.opcion, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = activo ? Colors.white : AppColors.sidebarText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        button: true,
        selected: activo,
        label: opcion.titulo,
        child: Material(
          color: activo ? AppColors.boton : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: SizedBox(
              height: 64,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(opcion.icono, size: 22, color: color),
                  const SizedBox(height: 4),
                  Text(
                    opcion.etiqueta,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: color,
                      fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Círculo con las iniciales del usuario. Al tocarlo abre el menú de la
/// cuenta: cambiar el tema, cerrar la jornada o cerrar sesión.
class _BotonCuenta extends StatelessWidget {
  const _BotonCuenta();

  String _iniciales(String texto) {
    final partes = texto.split(RegExp(r'[\s@._-]+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final usuario = provider.usuarioActual;
    final nombre = (usuario?.nombre ?? '').trim();
    final correo = usuario?.correo ?? '';
    final iniciales = _iniciales(nombre.isNotEmpty ? nombre : correo);

    return PopupMenuButton<String>(
      tooltip: 'Cuenta',
      offset: const Offset(90, -150),
      onSelected: (opcion) {
        switch (opcion) {
          case 'tema':
            final tema = context.read<ThemeProvider>();
            tema.cambiar(AppColors.isDark ? ThemeMode.light : ThemeMode.dark);
          case 'jornada':
            confirmarCierreJornada(context);
          case 'salir':
            context.read<AppProvider>().logout();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(provider.isAdmin ? 'Administrador' : 'Operador',
                  style: AppTextStyles.h4),
              Text(correo, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'tema',
          child: ListTile(
            leading: Icon(Icons.contrast_rounded),
            title: Text('Cambiar tema'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'jornada',
          child: ListTile(
            leading: Icon(Icons.event_busy_rounded),
            title: Text('Cerrar jornada'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'salir',
          child: ListTile(
            leading: Icon(Icons.logout_rounded),
            title: Text('Cerrar sesión'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.railBorde),
        ),
        child: Text(
          iniciales,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
