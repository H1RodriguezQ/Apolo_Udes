import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_provider.dart';
import '../../widgets/common/widgets.dart';

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
    final resultado = provider.verificarAcceso(codigo);

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
      setState(() => _ultimoResultado = null);
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

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Control de Acceso',
            subtitle: 'Verificación de asistencia mediante código QR',
          ),
          // Aviso de una limitación de diseño: mientras esta tablet está sin
          // internet no se entera de lo que validó la otra entrada, así que
          // el mismo QR podría aceptarse en ambas hasta reconectar.
          if (!provider.enLinea) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: AppColors.warning, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sin conexión: los accesos se validan con la información '
                      'guardada en esta tablet y se sincronizarán al reconectar. '
                      'Mientras tanto, el otro punto de entrada no ve estos registros.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: isMobile
                ? _buildMobileLayout(registros)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 340,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: 240,
                                      child: _buildCameraArea(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _toggleCamara,
                                          icon: Icon(
                                            _camaraActiva
                                                ? Icons.videocam_off_rounded
                                                : Icons.qr_code_scanner_rounded,
                                            size: 18,
                                          ),
                                          label: Text(_camaraActiva
                                              ? 'Detener'
                                              : 'Activar'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _camaraActiva
                                                ? AppColors.error
                                                : AppColors.primaryLight,
                                          ),
                                        ),
                                      ),
                                      if (_camaraActiva) ...[
                                        const SizedBox(width: 8),
                                        IconButton.filled(
                                          onPressed: _toggleLinterna,
                                          icon: Icon(_linternaActiva
                                              ? Icons.flash_off_rounded
                                              : Icons.flash_on_rounded),
                                          tooltip: 'Linterna',
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
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Expanded(child: Divider()),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text('o ingresa manualmente',
                                            style: AppTextStyles.caption),
                                      ),
                                      const Expanded(child: Divider()),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _codigoController,
                                    decoration: const InputDecoration(
                                      hintText: 'Documento o código QR',
                                      prefixIcon: Icon(Icons.badge_outlined),
                                    ),
                                    onSubmitted: (_) => _verificarManual(),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _procesando ? null : _verificarManual,
                                      icon: const Icon(Icons.search_rounded, size: 18),
                                      label: const Text('Verificar'),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.infoLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded,
                                            color: AppColors.info, size: 16),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Apunta al QR para registrar el acceso.',
                                            style: TextStyle(
                                                color: AppColors.info,
                                                fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('Registro en tiempo real',
                                        style: AppTextStyles.h4),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    Text('${registros.length} accesos registrados',
                                        style: AppTextStyles.bodySmall),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: registros.isEmpty
                                      ? const EmptyState(
                                          icon: Icons.no_accounts_rounded,
                                          title: 'Sin registros aún',
                                          subtitle:
                                              'Los accesos aparecerán aquí en tiempo real',
                                        )
                                      : ListView.separated(
                                          itemCount: registros.length,
                                          separatorBuilder: (_, __) =>
                                              const Divider(height: 1),
                                          itemBuilder: (context, i) =>
                                              _RegistroTile(registro: registros[i]),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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

  Widget _buildCameraArea() {
    if (_ultimoResultado != null) {
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

    return Container(
      color: AppColors.sidebarBg,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: Colors.white38, size: 64),
            SizedBox(height: 10),
            Text('Cámara inactiva',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
            SizedBox(height: 4),
            Text('Presiona "Activar cámara"',
                style: TextStyle(color: Colors.white24, fontSize: 11)),
          ],
        ),
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
