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
  final _lugarCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();

  // Facultades reales de UDES
  final List<String> _facultades = [
    'Ciencias Médicas y de la Salud',
    'Ingenierías y Tecnologías',
    'Ciencias Económicas, Administrativas y Contables',
    'Ciencias Exactas, Naturales y Agropecuarias',
    'Ciencias Sociales, Humanidades y Educación',
  ];

  final Map<String, String> _horasPorFacultad = {};

  @override
  void initState() {
    super.initState();
    _inicializarHoras();
    _cargarConfiguracion();
  }



  void _inicializarHoras() {
    // Generar horas cada 30 minutos desde 8:30 AM hasta 6:00 PM
    final List<String> horasDisponibles = _generarHorarios();
    
    // Asignar una hora diferente a cada facultad
    for (int i = 0; i < _facultades.length; i++) {
      if (i < horasDisponibles.length) {
        _horasPorFacultad[_facultades[i]] = horasDisponibles[i];
      } else {
        _horasPorFacultad[_facultades[i]] = horasDisponibles.last;
      }
    }
  }

  List<String> _generarHorarios() {
    final List<String> horarios = [];
    // Comenzar desde 8:30 AM
    int hora = 8;
    int minuto = 30;

    while (hora < 18 || (hora == 18 && minuto == 0)) {
      final hourFormatted = hora > 12 ? hora - 12 : (hora == 0 ? 12 : hora);
      final periodo = hora >= 12 ? 'PM' : 'AM';
      final horarioFormato =
          '${hourFormatted.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')} $periodo';
      horarios.add(horarioFormato);

      minuto += 30;
      if (minuto >= 60) {
        minuto = 0;
        hora++;
      }

      if (hora > 18) break;
    }

    return horarios;
  }

  @override
  void dispose() {
    _aforoCtrl.dispose();
    _lugarCtrl.dispose();
    _direccionCtrl.dispose();
    _ciudadCtrl.dispose();
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

        if (data['lugar'] != null) {
          _lugarCtrl.text = data['lugar'] as String;
        }

        if (data['direccion'] != null) {
          _direccionCtrl.text = data['direccion'] as String;
        }

        if (data['ciudad'] != null) {
          _ciudadCtrl.text = data['ciudad'] as String;
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
      } else {
        // Valores por defecto
        _lugarCtrl.text = 'Auditorio Mayor, Campus Lagos del Cacique';
        _direccionCtrl.text = 'Calle 70 No. 55-210';
        _ciudadCtrl.text = 'Bucaramanga, Santander';
        _aforoCtrl.text = '500';
      }

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

    if (_lugarCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa el lugar del evento'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_direccionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa la dirección del evento'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_ciudadCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa la ciudad del evento'),
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
        'lugar': _lugarCtrl.text.trim(),
        'direccion': _direccionCtrl.text.trim(),
        'ciudad': _ciudadCtrl.text.trim(),
        'horasPorFacultad': _horasPorFacultad,
        'aforoDisponible': aforoValor,
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
                      'Fecha, hora, aforo, lugar y facultades',
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
                                      ? AppColors.primaryLight
                                          .withValues(alpha: 0.05)
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

                    // ── Lugar del Evento (Editable) ──
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('📍 Lugar del Evento',
                                style: AppTextStyles.h3),
                            const SizedBox(height: 4),
                            const Text(
                              'Nombre del lugar donde se realizará la ceremonia',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _lugarCtrl,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.location_on_rounded),
                                hintText: 'Ej: Auditorio Mayor',
                                helperText: 'Nombre del lugar',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _direccionCtrl,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.map_rounded),
                                hintText: 'Ej: Calle 70 No. 55-210',
                                helperText: 'Dirección completa',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _ciudadCtrl,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.location_city_rounded),
                                hintText: 'Ej: Bucaramanga, Santander',
                                helperText: 'Ciudad, Departamento',
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
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}