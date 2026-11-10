import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';
import '../common/widgets.dart';

Future<void> confirmarCierreJornada(BuildContext context) async {
  // El proveedor se captura ANTES del await: después del cierre ya no hay
  // contexto de sesión válido (la app vuelve a la pantalla de login).
  final provider = context.read<AppProvider>();
  final accesos = provider.accesosHoy;

  final confirm = await showConfirmDialog(
    context,
    title: 'Cerrar jornada',
    content: 'Se dejará constancia del cierre en la bitácora, se cerrará la '
        'sesión y se borrarán los datos guardados en esta tablet. Las '
        'lecturas ya están en el servidor y no se pierden. '
        'Accesos validados hoy: $accesos. ¿Continuar?',
    confirmLabel: 'Cerrar jornada',
    isDangerous: true,
  );
  if (confirm != true) return;

  await provider.cerrarJornada();
}
