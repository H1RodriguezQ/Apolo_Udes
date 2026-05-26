import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/app_provider.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  DateTime? _fechaCeremonia;
  bool _guardando = false;
  bool _cargando = true;
  final _aforoCtrl = TextEditingController();

  final Map<String, String> _horasPorFacultad = {
    'Ciencias de la Salud': '08:00 AM',
    'Ciencias Económicas y Administrativas': '10:00 AM',
    'Ingenierías': '02:00 PM',
    'Ciencias Jurídicas y Sociales': '04:00 PM',
    'Ciencias Naturales': '04:00 PM',
  };

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _aforoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('evento')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        if (data['fechaCeremonia'] != null) {
          final ts = data['fechaCeremonia'] as Timestamp;
          setState(() => _fechaCeremonia = ts.toDate());
        }
        if (data['horasPorFacultad'] != null) {
          final horas = Map<String, String>.from(data['horasPorFacultad']);
          setState(() => _horasPorFacultad.addAll(horas));
        }
        if (data['aforoDisponible'] != null) {
          final aforo = data['aforoDisponible'] as int;
          _aforoCtrl.text = aforo.toString();
          if (mounted) {
            context.read<AppProvider>().setAforoDisponible(aforo);
          }
        }
      }

      // Si no hay valor en Firestore, usar el del provider
      if (_aforoCtrl.text.isEmpty && mounted) {
        _aforoCtrl.text =
            context.read<AppProvider>().aforoDisponible.toString();
      }
    } catch (e) {
      debugPrint('Error cargando configuración: $e');
      if (mounted) {
        _aforoCtrl.text =
            context.read<AppProvider>().aforoDisponible.toString();
      }
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarConfiguracion() async {
    if (_fechaCeremonia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una fecha para la ceremonia'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final aforoValor = int.tryParse(_aforoCtrl.text.trim());
    if (aforoValor == null || aforoValor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un aforo válido (número mayor a 0)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('configuracion')
          .doc('evento')
          .set({
        'fechaCeremonia': Timestamp.fromDate(_fechaCeremonia!),
        'horasPorFacultad': _horasPorFacultad,
        'aforoDisponible': aforoValor,
        'lugar': AppConstants.eventoLugar,
        'direccion': AppConstants.eventoDireccion,
        'ciudad': AppConstants.eventoCiudad,
        'actualizadoPor':
            context.read<AppProvider>().usuarioActual?.correo ?? 'admin',
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      context.read<AppProvider>().setAforoDisponible(aforoValor);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Configuración guardada exitosamente'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaCeremonia ??
          DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'CO'),
    );
    if (fecha != null) setState(() => _fechaCeremonia = fecha);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Configuración del Evento', style: AppTextStyles.h1),
                    SizedBox(height: 4),
                    Text(
                      'Fecha, hora, aforo y lugar de la ceremonia de grado',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _guardando ? null : _guardarConfiguracion,
                icon: _guardando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_guardando ? 'Guardando...' : 'Guardar cambios'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (_cargando)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ── Fecha ──
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('📅 Fecha de la Ceremonia',
                                style: AppTextStyles.h3),
                            const SizedBox(height: 4),
                            const Text(
                              'Todas las facultades comparten la misma fecha',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            InkWell(
                              onTap: _seleccionarFecha,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _fechaCeremonia != null
                                        ? AppColors.primaryLight
                                        : AppColors.border,
                                    width: _fechaCeremonia != null ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  color: _fechaCeremonia != null
                                      ? AppColors.primaryLight.withValues(alpha: 0.05)
                                      : AppColors.surface,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      color: _fechaCeremonia != null
                                          ? AppColors.primaryLight
                                          : AppColors.textSecondary,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _fechaCeremonia != null
                                            ? '${_fechaCeremonia!.day}/${_fechaCeremonia!.month}/${_fechaCeremonia!.year}'
                                            : 'Toca para seleccionar la fecha',
                                        style: TextStyle(
                                          color: _fechaCeremonia != null
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                          fontSize: 15,
                                          fontWeight: _fechaCeremonia != null
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded,
                                        color: AppColors.textSecondary),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Aforo ──
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🎟️ Aforo Disponible',
                                style: AppTextStyles.h3),
                            const SizedBox(height: 4),
                            const Text(
                              'Número máximo de personas permitidas en el evento',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: 200,
                              child: TextFormField(
                                controller: _aforoCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.people_rounded),
                                  hintText: 'Ej: 500',
                                  helperText: 'Personas',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Horas por facultad ──
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🕐 Hora por Facultad',
                                style: AppTextStyles.h3),
                            const SizedBox(height: 4),
                            const Text(
                              'Cada facultad puede tener un horario diferente',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 20),
                            ..._horasPorFacultad.entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        value: entry.value,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                        ),
                                        items: AppConstants.horasCeremonia
                                            .map((h) => DropdownMenuItem(
                                                  value: h,
                                                  child: Text(h),
                                                ))
                                            .toList(),
                                        onChanged: (v) {
                                          if (v != null) {
                                            setState(() =>
                                                _horasPorFacultad[entry.key] =
                                                    v);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Lugar (fijo) ──
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('📍 Lugar del Evento',
                                style: AppTextStyles.h3),
                            const SizedBox(height: 16),
                            _infoRow(Icons.location_on_rounded,
                                AppConstants.eventoLugar),
                            const SizedBox(height: 8),
                            _infoRow(Icons.map_rounded,
                                AppConstants.eventoDireccion),
                            const SizedBox(height: 8),
                            _infoRow(Icons.location_city_rounded,
                                AppConstants.eventoCiudad),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppColors.primaryLight
                                        .withValues(alpha: 0.2)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 16, color: AppColors.primaryLight),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'El lugar es fijo y no puede modificarse desde la app.',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primaryLight),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(text,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      ],
    );
  }
}