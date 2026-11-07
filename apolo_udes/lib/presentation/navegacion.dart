import 'package:flutter/material.dart';
import 'widgets/shell/app_rail.dart';

/// Números de pantalla del administrador. Las 6 primeras salen en el menú
/// lateral (como en el lienzo); las demás se abren desde un botón o un
/// enlace y el menú deja marcada la opción "padre".
class Nav {
  static const inicio = 0;
  static const graduandos = 1;
  static const invitados = 2;
  static const directivos = 3;
  static const ceremonia = 4; // "Acceso": ceremonia en curso
  static const ajustes = 5;
  // Sin botón en el menú:
  static const recordatorio = 6; // desde Invitados e Inicio
  static const bitacora = 7; // desde Inicio
  static const lector = 8; // desde Ceremonia en curso
  static const usuarios = 9; // desde Ajustes

  static const menu = [
    OpcionMenu('Inicio', 'Inicio', Icons.home_outlined),
    OpcionMenu('Graduandos', 'Graduandos', Icons.school_outlined),
    OpcionMenu('Invitados', 'Invitados', Icons.people_outline),
    OpcionMenu('Directivos', 'Directivos', Icons.person_outline),
    OpcionMenu('Acceso', 'Ceremonia en curso', Icons.qr_code_scanner_rounded),
    OpcionMenu('Ajustes', 'Ajustes', Icons.tune_rounded),
  ];

  /// Qué opción del menú se marca cuando se está en la pantalla `i`.
  static int opcionDelMenu(int i) => switch (i) {
        recordatorio => invitados,
        bitacora => inicio,
        lector => ceremonia,
        usuarios => ajustes,
        _ => i,
      };
}

/// Pantallas del operador de entrada: el lector y su registro.
class NavOperador {
  static const acceso = 0;
  static const registro = 1;

  static const menu = [
    OpcionMenu('Acceso', 'Control de acceso', Icons.qr_code_scanner_rounded),
    OpcionMenu('Registro', 'Registro de la entrada', Icons.list_rounded),
  ];
}
