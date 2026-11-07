import 'package:flutter/material.dart';
import '../navegacion.dart';
import '../widgets/common/apolo_ui.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_provider.dart';
import '../widgets/common/selector_tema.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  DateTime? _fechaCeremonia;
  // Último día en que los graduandos pueden registrar invitados. Vacío =
  // registro abierto. Lo hace cumplir firestore.rules (registroAbierto).
  DateTime? _cierreRegistro;
  bool _guardando = false;
  bool _cargando = true;
  final _aforoCtrl = TextEditingController();
  final _lugarCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  // Datos que la invitación por correo imprime en la tarjeta (se envían a
  // Apps Script en configuracion/evento): el número de la ceremonia y el
  // lugar tal como debe aparecer en la invitación.
  final _numeroCeremoniaCtrl = TextEditingController();
  final _lugarCeremoniaCtrl = TextEditingController();

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
    _numeroCeremoniaCtrl.dispose();
    _lugarCeremoniaCtrl.dispose();
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

        if (data['cierreRegistro'] is Timestamp) {
          _cierreRegistro = (data['cierreRegistro'] as Timestamp).toDate();
        }
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

        // Invitación por correo: si el documento todavía no trae los campos
        // (registro anterior a esta versión) se dejan vacíos y el admin los
        // completa la próxima vez que guarde.
        if (data['numeroCeremonia'] != null) {
          _numeroCeremoniaCtrl.text = '${data['numeroCeremonia']}';
        }

        if (data['lugarCeremonia'] != null) {
          _lugarCeremoniaCtrl.text = data['lugarCeremonia'] as String;
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
        _numeroCeremoniaCtrl.text = '1';
        _lugarCeremoniaCtrl.text = 'Auditorio Mayor · Campus Lagos del Cacique';
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
      if (mounted) setState(() => _cargando = false);
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

    // Número de ceremonia: entero de 1 a 99. Va impreso en el asunto del
    // correo y en la tarjeta de la invitación ("CEREMONIA N.º 3").
    final numeroCeremonia = int.tryParse(_numeroCeremoniaCtrl.text.trim());
    if (numeroCeremonia == null || numeroCeremonia < 1 || numeroCeremonia > 99) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa el número de ceremonia (entre 1 y 99)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Lugar tal como se imprime en la invitación: de 3 a 120 caracteres.
    final lugarCeremonia = _lugarCeremoniaCtrl.text.trim();
    if (lugarCeremonia.length < 3 || lugarCeremonia.length > 120) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'El lugar de la ceremonia debe tener entre 3 y 120 caracteres'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_cierreRegistro != null && _cierreRegistro!.isAfter(_fechaCeremonia!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El cierre del registro debe ser antes de la ceremonia'),
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
        // Lo que imprime la invitación por correo (ver Codigo.gs).
        'numeroCeremonia': numeroCeremonia,
        'lugarCeremonia': lugarCeremonia,
        // Se cierra al final de ese día (23:59:59).
        if (_cierreRegistro != null)
          'cierreRegistro': Timestamp.fromDate(DateTime(
              _cierreRegistro!.year, _cierreRegistro!.month, _cierreRegistro!.day, 23, 59, 59)),
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
      initialDate:
          _fechaCeremonia ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'CO'),
    );
    if (fecha != null) setState(() => _fechaCeremonia = fecha);
  }

  Future<void> _seleccionarCierre() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _cierreRegistro ?? (_fechaCeremonia ?? DateTime.now()).subtract(const Duration(days: 5)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'CO'),
      helpText: 'Último día para registrar invitados',
    );
    if (fecha != null) setState(() => _cierreRegistro = fecha);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final ancho = MediaQuery.sizeOf(context).width;
    final horas = _generarHorarios();

    final ceremonia = _Bloque(
      titulo: 'La ceremonia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CampoConEtiqueta(
                  etiqueta: 'Fecha',
                  campo: InkWell(
                    onTap: _seleccionarFecha,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                      child: Text(
                        _fechaCeremonia == null ? 'dd/mm/aaaa' : DateFormat('dd/MM/yyyy').format(_fechaCeremonia!),
                        style: AppTextStyles.mono(size: 15, color: _fechaCeremonia == null ? AppColors.textHint : null),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CampoConEtiqueta(
                  etiqueta: 'Número de ceremonia',
                  campo: TextField(
                    controller: _numeroCeremoniaCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                    style: AppTextStyles.mono(size: 15),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CampoConEtiqueta(
                  etiqueta: 'Sillas del auditorio',
                  campo: TextField(
                    controller: _aforoCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                    style: AppTextStyles.mono(size: 15),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CampoConEtiqueta(
            etiqueta: 'Cierre del registro de invitados',
            nota: '(después de este día la página ya no deja registrar)',
            campo: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _seleccionarCierre,
                    borderRadius: BorderRadius.circular(8),
                    child: InputDecorator(
                      decoration: const InputDecoration(suffixIcon: Icon(Icons.event_busy_outlined, size: 18)),
                      child: Text(
                        _cierreRegistro == null ? 'Sin fecha: el registro está abierto' : 'Hasta el ${DateFormat('dd/MM/yyyy').format(_cierreRegistro!)} a las 11:59 p. m.',
                        style: _cierreRegistro == null ? AppTextStyles.label.copyWith(fontSize: 15) : AppTextStyles.mono(size: 15),
                      ),
                    ),
                  ),
                ),
                if (_cierreRegistro != null) ...[
                  const SizedBox(width: 8),
                  BotonSecundario(texto: 'Quitar', onPressed: () => setState(() => _cierreRegistro = null)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          CampoConEtiqueta(etiqueta: 'Lugar', campo: TextField(controller: _lugarCtrl, decoration: const InputDecoration(hintText: 'Auditorio Mayor'))),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: CampoConEtiqueta(etiqueta: 'Dirección', campo: TextField(controller: _direccionCtrl, decoration: const InputDecoration(hintText: 'Calle 70 No. 55-210'))),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CampoConEtiqueta(etiqueta: 'Ciudad', campo: TextField(controller: _ciudadCtrl, decoration: const InputDecoration(hintText: 'Bucaramanga'))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          CampoConEtiqueta(
            etiqueta: 'Lugar como sale en la invitación',
            campo: TextField(controller: _lugarCeremoniaCtrl, maxLength: 120, decoration: const InputDecoration(counterText: '', hintText: 'Auditorio Mayor, Campus Lagos del Cacique')),
          ),
        ],
      ),
    );

    final facultades = _horasPorFacultad.keys.toList();
    final horario = _Bloque(
      titulo: 'Hora por facultad',
      accion: Text('Sale en los correos y en Control de acceso', style: AppTextStyles.bodySmall),
      sinMargen: true,
      child: Column(
        children: [
          for (final f in facultades)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
              child: Row(
                children: [
                  Expanded(child: Text(f, style: AppTextStyles.body)),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: horas.contains(_horasPorFacultad[f]) ? _horasPorFacultad[f] : null,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        alignment: AlignmentDirectional.centerEnd,
                        hint: Text(_horasPorFacultad[f] ?? '', style: AppTextStyles.mono(size: 15)),
                        items: [
                          for (final h in horas)
                            DropdownMenuItem(value: h, alignment: AlignmentDirectional.centerEnd, child: Text(h, style: AppTextStyles.mono(size: 15))),
                        ],
                        onChanged: (v) => setState(() => _horasPorFacultad[f] = v!),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    const apariencia = _Bloque(titulo: 'Apariencia', child: SelectorTema());

    final usuarios = _Bloque(
      titulo: 'Usuarios',
      accion: BotonSecundario(texto: 'Administrar', onPressed: () => provider.setSelectedIndex(Nav.usuarios)),
      sinMargen: true,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snap) {
          final docs = (snap.data?.docs ?? []).where((d) => (d.data()['estado'] ?? 'activo') != 'eliminado').toList();
          return Column(
            children: [
              for (final d in docs.take(8))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
                  child: Row(
                    children: [
                      Expanded(
                        child: CeldaTexto(
                          '${d.data()['nombre'] ?? ''}'.trim().isEmpty ? '${d.data()['correo'] ?? ''}' : '${d.data()['nombre']}',
                          debajo: switch (d.data()['rol']) { 'admin' => 'Administrador', 'operador' => 'Operador', _ => 'Consulta' },
                          fuerte: true,
                        ),
                      ),
                      Text('${d.data()['puntoValidacion'] ?? (d.data()['rol'] == 'admin' ? 'Administración' : '')}', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );

    final finalizar = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.errorText.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Finalizar ceremonia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.errorText)),
          const SizedBox(height: 8),
          Text(
            'Cuando la ceremonia termine, se borran los graduandos, invitados, directivos y lecturas para dejar '
            'Apolo listo para la siguiente. Se conservan los usuarios, estos ajustes y la bitácora.',
            style: AppTextStyles.body.copyWith(height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            'Por seguridad este borrado no se hace desde la tablet: lo hace el administrador desde el computador '
            'con el script deploy/limpieza.js.',
            style: AppTextStyles.bodySmall.copyWith(height: 1.5),
          ),
        ],
      ),
    );

    final izquierda = Column(children: [ceremonia, const SizedBox(height: 20), horario, const SizedBox(height: 20), apariencia]);
    final derecha = Column(children: [usuarios, const SizedBox(height: 20), finalizar]);

    return PantallaApolo(
      desplazable: true,
      encabezado: EncabezadoPantalla(
        titulo: 'Ajustes',
        acciones: [
          ElevatedButton(
            onPressed: _guardando || _cargando ? null : _guardarConfiguracion,
            child: Text(_guardando ? 'Guardando…' : 'Guardar cambios'),
          ),
        ],
      ),
      cuerpo: _cargando
          ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          : ancho >= 1100
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(flex: 3, child: izquierda), const SizedBox(width: 20), Expanded(flex: 2, child: derecha)],
                )
              : Column(children: [izquierda, const SizedBox(height: 20), derecha]),
    );
  }
}

/// Tarjeta con título de la pantalla de Ajustes.
class _Bloque extends StatelessWidget {
  final String titulo;
  final Widget? accion;
  final Widget child;
  final bool sinMargen; // el contenido llega hasta los bordes (listas)
  const _Bloque({required this.titulo, required this.child, this.accion, this.sinMargen = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Expanded(child: Text(titulo, style: AppTextStyles.h4.copyWith(fontSize: 16))),
                if (accion != null) accion!,
              ],
            ),
          ),
          sinMargen ? child : Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: child),
        ],
      ),
    );
  }
}
