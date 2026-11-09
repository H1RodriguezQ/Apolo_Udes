import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';
import '../../widgets/common/apolo_ui.dart';

/// Decide cuál de los códigos que ve la cámara se procesa ahora, o ninguno.
///
/// La cámara puede ver varios QR a la vez (por ejemplo, el anterior todavía
/// en la pantalla), así que se revisan todos, no solo el primero. Un código
/// visto hace menos de 3 s sigue frente a la cámara: se renueva su hora y no
/// se repite. Si ya se está procesando otro, el nuevo no se marca, para
/// tomarlo en la siguiente detección. Actualiza [vistos].
String? codigoAProcesar(
  Iterable<String?> codigos,
  Map<String, DateTime> vistos,
  DateTime ahora, {
  required bool ocupado,
}) {
  for (final codigo in codigos) {
    if (codigo == null || codigo.isEmpty) continue;
    final visto = vistos[codigo];
    if (visto != null && ahora.difference(visto).inSeconds < 3) {
      vistos[codigo] = ahora;
      continue;
    }
    if (ocupado) return null;
    vistos[codigo] = ahora;
    return codigo;
  }
  return null;
}

/// Lector de códigos QR.
///
/// - El operador lo ve como pantalla completa (`enPanel: false`).
/// - El administrador lo ve como un panel a la izquierda de la pantalla
///   "Acceso a la ceremonia" (`enPanel: true`), junto a las cifras del
///   auditorio, para no tener que cambiar de pantalla.
class ControlAccesoScreen extends StatefulWidget {
  final bool enPanel;
  const ControlAccesoScreen({super.key, this.enPanel = false});

  @override
  State<ControlAccesoScreen> createState() => _ControlAccesoScreenState();
}

class _ControlAccesoScreenState extends State<ControlAccesoScreen> {
  final _codigoController = TextEditingController();
  MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  void _recrearController() {
    _scannerController.dispose();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    setState(() {});
  }

  bool _camaraActiva = false;
  bool _procesando = false;
  RegistroAcceso? _ultimoResultado;
  bool _resultadoValido = false;
  String _mensajeDenegado = 'Código no válido';

  // Códigos ya procesados y la última vez que la cámara los vio. Mientras
  // un código siga frente a la cámara (visto hace menos de 3 s) no se vuelve
  // a procesar: antes se repetía cada 3 s y llenaba la bitácora de
  // "rechazadas" (35 en la prueba del 7 de noviembre).
  final Map<String, DateTime> _vistos = {};

  @override
  void dispose() {
    _codigoController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final codigo = codigoAProcesar(
      capture.barcodes.map((b) => b.rawValue),
      _vistos,
      DateTime.now(),
      ocupado: _procesando,
    );
    if (codigo != null) _procesarCodigo(codigo);
  }

  /// Verifica el código SIN apagar la cámara: antes se detenía, se esperaba
  /// 0,4 s, se dejaba el resultado 2,5 s tapando la imagen y se volvía a
  /// crear la cámara (4 a 5 s por persona). Ahora la cámara sigue leyendo y
  /// el resultado se queda en la tarjeta de abajo hasta la siguiente lectura.
  Future<void> _procesarCodigo(String codigo) async {
    setState(() => _procesando = true);

    final provider = context.read<AppProvider>();
    // La tablet le pregunta al servidor si el código sigue libre antes de
    // dejar pasar a la persona.
    final resultado = await provider.verificarAcceso(codigo);
    if (!mounted) return;

    String mensajeDenegado = 'Código no válido';
    if (resultado == null) {
      if (provider.codigoYaUsado(codigo)) {
        mensajeDenegado = 'Código ya utilizado';
      } else {
        mensajeDenegado = 'Código QR inválido o no registrado';
      }
    }

    setState(() {
      _procesando = false;
      _mensajeDenegado = mensajeDenegado;
      _ultimoResultado = resultado ??
          RegistroAcceso(
            id: 'invalid',
            nombre: 'No encontrado',
            documento: codigo,
            horaAcceso: DateTime.now(),
            valido: false,
          );
      _resultadoValido = resultado != null;
    });
    // Desde que termina, cuenta de nuevo el tiempo para no repetirlo.
    _vistos[codigo] = DateTime.now();

    // Vibración para que el operador sepa el resultado sin mirar (en la
    // tablet; en la web no hace nada): suave si entra, fuerte si no.
    if (resultado != null) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _verificarManual() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) return;
    _codigoController.clear();
    await _procesarCodigo(codigo);
  }

  void _toggleCamara() {
    setState(() {
      _camaraActiva = !_camaraActiva;
      _ultimoResultado = null;
    });
    if (_camaraActiva) {
      _recrearController();
    } else {
      _scannerController.stop();
    }
  }

  void _toggleLinterna() {
    _scannerController.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final registros = provider.registrosAcceso;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    if (widget.enPanel) return _panelLector(provider);

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _panelLector(provider),
                    const SizedBox(height: 16),
                    _UltimasLecturas(registros: registros),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Tablet (rediseño): a la izquierda el lector y la búsqueda manual; a la
    // derecha el resultado en grande, los contadores y las últimas lecturas.
    // Los contadores salen de las lecturas de hoy en Firestore, así que
    // incluyen lo que validó la otra entrada.
    final validasHoy = provider.lecturasDelDia.where((l) => l.valida).toList();
    final punto = provider.miPunto;
    final ingresosAqui = punto.isEmpty
        ? registros.where((r) => r.valido).length
        : validasHoy.where((l) => l.punto == punto).length;
    final totalAuditorio = validasHoy.length;
    return PantallaApolo(
      desplazable: true,
      encabezado: EncabezadoPantalla(
        titulo: 'Control de acceso',
        segundaLinea: 'Ceremonia de grado${punto.isEmpty ? '' : ' · $punto'}',
        mostrarConexion: true,
      ),
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mientras esta tablet está sin internet no se entera de lo que
          // validó la otra entrada, así que el mismo QR podría aceptarse en
          // las dos hasta reconectar. Se avisa siempre que pase.
          if (!provider.enLinea) ...[const _AvisoSinConexion(), const SizedBox(height: 20)],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(height: 380, child: _buildCameraArea()),
                    ),
                    const SizedBox(height: 16),
                    _tarjetaManual(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ResultadoGrande(
                      registro: _ultimoResultado,
                      valido: _resultadoValido,
                      mensajeDenegado: _mensajeDenegado,
                      procesando: _procesando,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _Contador(etiqueta: 'Ingresos por esta entrada', valor: '$ingresosAqui')),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _Contador(
                            etiqueta: 'Total en el auditorio',
                            valor: '$totalAuditorio',
                            de: '${provider.aforoDisponible}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _UltimasLecturas(registros: registros),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// El lector en una sola tarjeta: cámara, resultado, código a mano y los
  /// contadores de la entrada donde se está leyendo.
  Widget _panelLector(AppProvider provider) {
    final punto = provider.miPunto;
    final deAqui = provider.lecturasDelDia.where((l) => l.punto == punto);
    final validasAqui = deAqui.where((l) => l.valida).length;
    final rechazadasAqui = deAqui.length - validasAqui;

    final celular = MediaQuery.sizeOf(context).width < 600;
    return Container(
      padding: EdgeInsets.all(celular ? 14 : 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(punto.isEmpty ? 'Lector de códigos' : 'Lector · $punto', style: AppTextStyles.h4.copyWith(fontSize: 16))),
              if (_camaraActiva)
                OutlinedButton.icon(
                  onPressed: _toggleCamara,
                  icon: const Icon(Icons.videocam_off_outlined, size: 18),
                  label: const Text('Apagar cámara'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!provider.enLinea) ...[const _AvisoSinConexion(), const SizedBox(height: 14)],
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(height: celular ? 240 : 260, child: _buildCameraArea()),
          ),
          const SizedBox(height: 14),
          _ResultadoGrande(
            registro: _ultimoResultado,
            valido: _resultadoValido,
            mensajeDenegado: _mensajeDenegado,
            procesando: _procesando,
          ),
          const SizedBox(height: 14),
          Text('Si el QR no lee, digite la cédula o el código', style: AppTextStyles.bodySmall),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codigoController,
                  style: AppTextStyles.mono(size: 16),
                  decoration: const InputDecoration(hintText: 'Número de documento'),
                  onSubmitted: (_) => _verificarManual(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _procesando ? null : _verificarManual,
                  child: const Text('Validar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Contador(etiqueta: 'Válidas aquí', valor: '$validasAqui')),
              const SizedBox(width: 12),
              Expanded(child: _Contador(etiqueta: 'Rechazadas aquí', valor: '$rechazadasAqui')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tarjetaManual() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Si el QR no lee, digite la cédula o el código',
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codigoController,
                  style: AppTextStyles.mono(size: 16),
                  decoration: const InputDecoration(hintText: 'Número de documento'),
                  onSubmitted: (_) => _verificarManual(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _procesando ? null : _verificarManual,
                  child: const Text('Validar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// La imagen de la cámara. El resultado NO se pinta encima: si la cámara
  /// se quita del árbol de widgets, se apaga y tarda en volver a prender.
  Widget _buildCameraArea() {
    if (_camaraActiva) {
      return Stack(
        children: [
          MobileScanner(controller: _scannerController, onDetect: _onDetect),
          Center(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const _ScanLine(),
          Positioned(
            top: 12,
            right: 12,
            // El botón de linterna solo sale si el equipo la deja usar. En el
            // iPhone, Safari no permite prender el flash desde una página web
            // (en la APK de la tablet sí funciona), así que ahí se oculta.
            child: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _scannerController,
              builder: (context, estado, _) {
                if (estado.torchState == TorchState.unavailable) return const SizedBox.shrink();
                final prendida = estado.torchState == TorchState.on;
                return IconButton.filledTonal(
                  onPressed: _toggleLinterna,
                  tooltip: prendida ? 'Apagar linterna' : 'Prender linterna',
                  icon: Icon(prendida ? Icons.flash_off_rounded : Icons.flash_on_rounded),
                );
              },
            ),
          ),
          const Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Text('Apunta al código QR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  )),
            ),
          ),
        ],
      );
    }

    // Cámara apagada: recuadro con esquinas, como en el diseño, y el botón
    // para encenderla (la cámara se pide solo cuando hace falta).
    return Container(
      color: const Color(0xFF0E1B33),
      child: Stack(
        children: [
          const Center(child: _Esquinas(tamano: 230)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Acerque el código QR\nal recuadro',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 15, height: 1.8)),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: _toggleCamara,
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('Encender cámara'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(seconds: 2), vsync: this)
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.2, end: 0.8).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          top: 240 * _animation.value,
          left: 40,
          right: 40,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                AppColors.primaryLight.withValues(alpha: 0.8),
                Colors.transparent,
              ]),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.4),
                    blurRadius: 6),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Esquinas blancas del recuadro de lectura.
class _Esquinas extends StatelessWidget {
  final double tamano;
  const _Esquinas({required this.tamano});

  @override
  Widget build(BuildContext context) {
    const lado = BorderSide(color: Colors.white, width: 2);
    Widget esquina(Alignment a, Border b) => Align(
          alignment: a,
          child: Container(width: 36, height: 36, decoration: BoxDecoration(border: b)),
        );
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Stack(children: [
        esquina(Alignment.topLeft, const Border(top: lado, left: lado)),
        esquina(Alignment.topRight, const Border(top: lado, right: lado)),
        esquina(Alignment.bottomLeft, const Border(bottom: lado, left: lado)),
        esquina(Alignment.bottomRight, const Border(bottom: lado, right: lado)),
      ]),
    );
  }
}

/// Aviso cuando la tablet no tiene internet.
class _AvisoSinConexion extends StatelessWidget {
  const _AvisoSinConexion();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.warningText, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sin conexión: los accesos se validan con la información guardada en esta '
              'tablet y se sincronizan al reconectar. Mientras tanto, la otra entrada no ve estas lecturas.',
              style: TextStyle(color: AppColors.warningText, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Resultado de la última lectura en letra grande, para que el operador lo
/// vea de un vistazo: verde si puede ingresar, ámbar si el código ya se usó
/// y rojo si no es válido.
class _ResultadoGrande extends StatelessWidget {
  final RegistroAcceso? registro;
  final bool valido;
  final String mensajeDenegado;
  final bool procesando;
  const _ResultadoGrande({required this.registro, required this.valido, required this.mensajeDenegado, required this.procesando});

  @override
  Widget build(BuildContext context) {
    final yaUsado = mensajeDenegado.contains('utilizado');
    final (fondo, texto, icono, titulo) = procesando
        ? (AppColors.infoLight, AppColors.infoText, Icons.hourglass_top_rounded, 'Verificando…')
        : registro == null
            ? (AppColors.surfaceVariant, AppColors.textSecondary, Icons.qr_code_2_rounded, 'Esperando lectura')
            : valido
                ? (AppColors.successLight, AppColors.successText, Icons.check_rounded, 'Puede ingresar')
                : yaUsado
                    ? (AppColors.warningLight, AppColors.warningText, Icons.warning_amber_rounded, 'Código ya utilizado')
                    : (AppColors.errorLight, AppColors.errorText, Icons.close_rounded, 'No puede ingresar');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: fondo,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icono, color: texto, size: 26),
                const SizedBox(width: 12),
                Text(titulo, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: texto)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: registro == null || procesando
                ? Text('Lea un código QR o digite el documento. El resultado aparece aquí.',
                    style: AppTextStyles.label.copyWith(fontSize: 14))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(valido ? registro!.nombre : mensajeDenegado,
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _Dato(etiqueta: valido ? 'Documento' : 'Código leído', valor: _ocultar(registro!.documento))),
                          Expanded(child: _Dato(etiqueta: 'Hora de lectura', valor: DateFormat('hh:mm a', 'es_CO').format(registro!.horaAcceso))),
                        ],
                      ),
                      if (valido) ...[
                        const SizedBox(height: 12),
                        Text('Este código queda marcado como usado en las dos entradas.',
                            style: AppTextStyles.body),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Solo se muestran los primeros y últimos dígitos: quien esté al lado del
  // operador no alcanza a leer la cédula completa.
  static String _ocultar(String doc) {
    if (doc.length <= 7) return doc;
    return '${doc.substring(0, 4)} ••• ${doc.substring(doc.length - 3)}';
  }
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  const _Dato({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: AppTextStyles.bodySmall),
        const SizedBox(height: 2),
        Text(valor, style: AppTextStyles.mono(size: 15)),
      ],
    );
  }
}

class _Contador extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String? de;
  const _Contador({required this.etiqueta, required this.valor, this.de});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: AppTextStyles.bodySmall),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(valor, style: AppTextStyles.mono(size: 28, peso: FontWeight.w500)),
              if (de != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 4),
                  child: Text('/  $de', style: AppTextStyles.mono(size: 15, color: AppColors.textSecondary)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UltimasLecturas extends StatelessWidget {
  final List<RegistroAcceso> registros;
  const _UltimasLecturas({required this.registros});

  @override
  Widget build(BuildContext context) {
    final ultimas = registros.take(5).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Text('Últimas lecturas', style: AppTextStyles.h4),
          ),
          Divider(height: 1, color: AppColors.border),
          if (ultimas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text('Todavía no hay lecturas en esta tablet.', style: AppTextStyles.label),
            ),
          for (final r in ultimas)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
              child: Row(
                children: [
                  Text(DateFormat('HH:mm').format(r.horaAcceso), style: AppTextStyles.mono(size: 14)),
                  const SizedBox(width: 16),
                  Expanded(child: Text(r.nombre, style: AppTextStyles.body, overflow: TextOverflow.ellipsis)),
                  StatusBadge(
                    label: r.valido ? 'Válido' : 'No válido',
                    backgroundColor: r.valido ? AppColors.successLight : AppColors.errorLight,
                    textColor: r.valido ? AppColors.success : AppColors.error,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
