import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda y expone el modo de tema: claro, oscuro o el del sistema.
class ThemeProvider extends ChangeNotifier {
  static const _clave = 'modo_tema';

  ThemeMode _modo = ThemeMode.system;
  ThemeMode get modo => _modo;

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(_clave);
      _modo = ThemeMode.values.firstWhere(
        (m) => m.name == guardado,
        orElse: () => ThemeMode.system,
      );
    } catch (e) {
      debugPrint('No se pudo leer el modo de tema: $e');
    }
  }

  Future<void> cambiar(ThemeMode modo) async {
    if (modo == _modo) return;
    _modo = modo;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, modo.name);
    } catch (e) {
      debugPrint('No se pudo guardar el modo de tema: $e');
    }
  }

  void siguiente() {
    cambiar(switch (_modo) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    });
  }
}