import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';
import '../../widgets/common/apolo_ui.dart';
import '../../navegacion.dart';

class ControlAccesoScreen extends StatefulWidget {
  const ControlAccesoScreen({super.key});

  @override
  State<ControlAccesoScreen> createState() => _ControlAccesoScreenState();
}

class _ControlAccesoScreenState extends State<ControlAccesoScreen> {
  final _codigoController = TextEditingController();
  MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  void _recrearController() {
    _scannerController.dispose();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    setState(() => _linternaActiva = false);
  }

  bool _camaraActiva = false;
  bool _linternaActiva = false;
  bool _procesando = false;
  RegistroAcceso? _ultimoResultado;
  bool _resultadoValido = false;
  String _mensajeDenegado = 'Código no válido';

  @override
  void dispose() {
    _codigoController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_procesando) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    _procesarCodigo(barcode!.rawValue!);
  }

  Future<void> _procesarCodigo(String codigo) async {
    setState(() => _procesando = true);
    _scannerController.stop();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final provider = context.read<AppProvider>();
    // Ahora es asíncrono: la tablet le pregunta al servidor si el código
    // sigue libre antes de dejar pasar a la persona.
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

    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted && _camaraActiva) {
      // En el celular el resultado tapa la cámara y se quita; en la tablet
      // queda a la derecha hasta la siguiente lectura.
      if (MediaQuery.sizeOf(context).width < 900) setState(() => _ultimoResultado = null);
      _recrearController();
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
    setState(() => _linternaActiva = !_linternaActiva);
    _scannerController.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final registros = provider.registrosAcceso;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!provider.enLinea) ...[const _AvisoSinConexion(), const SizedBox(height: 12)],
            Expanded(child: _buildMobileLayout(registros)),
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
        alVolver: provider.isAdmin ? () => provider.setSelectedIndex(Nav.ceremonia) : null,
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
                      child: SizedBox(height: 380, child: _buildCameraArea(mostrarResultado: false)),
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
                    OutlinedButton(
                      onPressed: _ultimoResultado == null ? null : () => setState(() => _ultimoResultado = null),
                      child: const Text('Leer el siguiente código'),
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

  Widget _buildMobileLayout(List<RegistroAcceso> registros) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                        width: double.infinity,
                        height: 220,
                        child: _buildCameraArea()),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _toggleCamara,
                        icon: Icon(
                            _camaraActiva
                                ? Icons.videocam_off_rounded
                                : Icons.qr_code_scanner_rounded,
                            size: 18),
                        label: Text(_camaraActiva ? 'Detener' : 'Activar cámara'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _camaraActiva
                                ? AppColors.error
                                : AppColors.primaryLight),
                      ),
                    ),
                    if (_camaraActiva) ...[
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _toggleLinterna,
                        icon: Icon(_linternaActiva
                            ? Icons.flash_off_rounded
                            : Icons.flash_on_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: _linternaActiva
                              ? AppColors.warning
                              : AppColors.surfaceVariant,
                          foregroundColor: _linternaActiva
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codigoController,
                    decoration: const InputDecoration(
                        hintText: 'Documento o código QR',
                        prefixIcon: Icon(Icons.badge_outlined)),
                    onSubmitted: (_) => _verificarManual(),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _procesando ? null : _verificarManual,
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Verificar'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppColors.info, size: 14),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Apunta al QR para registrar el acceso.',
                            style: TextStyle(color: AppColors.info, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Registro en tiempo real',
                          style: AppTextStyles.h4),
                      Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle)),
                      Text('${registros.length} accesos',
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  registros.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                              child: Text('Sin registros aún',
                                  style: AppTextStyles.bodySmall)))
                      : Column(
                          children: registros
                              .take(10)
                              .map((r) => _RegistroTile(registro: r))
                              .toList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraArea({bool mostrarResultado = true}) {
    if (mostrarResultado && _ultimoResultado != null) {
      return _ResultadoOverlay(
        valido: _resultadoValido,
        nombre: _ultimoResultado!.nombre,
        documento: _ultimoResultado!.documento,
        mensajeDenegado: _mensajeDenegado,
      );
    }

    if (_procesando) {
      return Container(
        color: AppColors.sidebarBg,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 14),
              Text('Verificando...',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      );
    }

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
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _toggleLinterna,
                  tooltip: 'Linterna',
                  icon: Icon(_linternaActiva ? Icons.flash_off_rounded : Icons.flash_on_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _toggleCamara,
                  tooltip: 'Apagar cámara',
                  icon: const Icon(Icons.videocam_off_outlined),
                ),
              ],
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

class _ResultadoOverlay extends StatelessWidget {
  final bool valido;
  final String nombre;
  final String documento;
  final String mensajeDenegado;

  const _ResultadoOverlay({
    required this.valido,
    required this.nombre,
    required this.documento,
    required this.mensajeDenegado,
  });

  @override
  Widget build(BuildContext context) {
    final color = valido
        ? AppColors.success
        : mensajeDenegado.contains('utilizado')
            ? AppColors.warning
            : AppColors.error;

    final icon = valido
        ? Icons.check_circle_rounded
        : mensajeDenegado.contains('utilizado')
            ? Icons.warning_rounded
            : Icons.cancel_rounded;

    return Container(
      color: color.withValues(alpha: 0.95),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 56),
              const SizedBox(height: 10),
              Text(
                valido ? 'ACCESO PERMITIDO' : 'ACCESO DENEGADO',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              if (valido) ...[
                const SizedBox(height: 6),
                Text(nombre,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                const Text('Bienvenido/a',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ] else ...[
                const SizedBox(height: 6),
                Text(mensajeDenegado,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Código: $documento',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistroTile extends StatelessWidget {
  final RegistroAcceso registro;
  const _RegistroTile({required this.registro});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 12),
            decoration: const BoxDecoration(
                color: AppColors.success, shape: BoxShape.circle),
          ),
          UserAvatar(name: registro.nombre, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(registro.nombre,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('Doc: ${registro.documento}',
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(DateFormat('HH:mm:ss').format(registro.horaAcceso),
                  style: AppTextStyles.caption),
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Ingresó',
                    style: TextStyle(
                        color: AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
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
