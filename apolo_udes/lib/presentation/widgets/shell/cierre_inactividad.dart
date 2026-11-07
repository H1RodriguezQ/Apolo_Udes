import 'dart:async';
import 'package:flutter/material.dart';

/// Cierra la sesión si nadie toca la pantalla durante [minutos].
///
/// Solo se usa con el administrador: su cuenta puede ver y borrar todos los
/// datos, y si deja la tablet o el computador abierto, cualquiera que pase
/// tendría acceso. Al operador NO se le aplica, porque en plena ceremonia
/// puede pasar un rato sin tocar la tablet y no debe tener que volver a
/// entrar con la fila esperando.
class CierrePorInactividad extends StatefulWidget {
  final Widget child;
  final bool activo;
  final int minutos;
  final VoidCallback alVencer;

  const CierrePorInactividad({
    super.key,
    required this.child,
    required this.activo,
    required this.alVencer,
    this.minutos = 15,
  });

  @override
  State<CierrePorInactividad> createState() => _CierrePorInactividadState();
}

class _CierrePorInactividadState extends State<CierrePorInactividad> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _reiniciar();
  }

  @override
  void didUpdateWidget(CierrePorInactividad viejo) {
    super.didUpdateWidget(viejo);
    if (viejo.activo != widget.activo) _reiniciar();
  }

  // Cada toque, clic, tecla o scroll vuelve a contar desde cero.
  void _reiniciar() {
    _timer?.cancel();
    if (!widget.activo) return;
    _timer = Timer(Duration(minutes: widget.minutos), () {
      if (mounted) widget.alVencer();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reiniciar(),
      onPointerSignal: (_) => _reiniciar(),
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (_, __) {
          _reiniciar();
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }
}
