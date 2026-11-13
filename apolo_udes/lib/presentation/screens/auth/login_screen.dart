import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/app_provider.dart';
import '../../../data/services/auth_service.dart';
import '../../../providers/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const String _emailHint = 'correo@udes.edu.co';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 250), // entrada corta: la tablet vuelve a esta pantalla varias veces al día
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    // Si la tablet ya tenía una sesión abierta, se entra sin volver a escribir
    // la contraseña. Así también se puede reabrir la app SIN internet: el
    // token de Firebase Auth y el perfil quedan guardados en el equipo.
    // Si no hay sesión (o no se puede leer el perfil), se queda en el
    // formulario y no se muestra ningún error.
    _restaurarSesion();
  }

  Future<void> _restaurarSesion() async {
    setState(() => _isLoading = true);
    await context.read<AppProvider>().restaurarSesion();
    // Al restaurarse, _AppRoot reemplaza esta pantalla por la de inicio y
    // este widget deja de existir: por eso se comprueba `mounted`.
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // El rol lo determina el servidor a partir del token; no se envia.
    final error = await context.read<AppProvider>().login(
          _correoController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = error;
    });
  }

  Future<void> _recuperarContrasena() async {
    final correo = _correoController.text.trim();
    if (correo.isEmpty) {
      setState(() =>
          _errorMessage = 'Escribe tu correo para recuperar la contraseña.');
      return;
    }
    try {
      await AuthService.recuperarContrasena(correo);
    } catch (_) {
      // Respuesta uniforme: no revela si la cuenta existe.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Si el correo está registrado, recibirás un enlace para restablecer la contraseña.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rediseño: a la izquierda la identidad de la universidad y para qué
    // sirve Apolo; a la derecha el formulario. En pantallas angostas solo
    // se muestra el formulario con el logo encima.
    final ancho = MediaQuery.sizeOf(context).width;
    final angosto = ancho < 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Row(
          children: [
            if (!angosto) const Expanded(flex: 13, child: _PanelInstitucional()),
            Expanded(
              flex: 21,
              child: Stack(
                children: [
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          children: [
                            if (angosto) ...[
                              const _LogoUdes(alto: 90),
                              const SizedBox(height: 24),
                            ],
                            _formulario(),
                            const SizedBox(height: 16),
                            Text(AppConstants.appVersion, style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(top: 24, right: 28, child: _BotonTemaLogin()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulario() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Iniciar sesión', style: AppTextStyles.h1.copyWith(fontSize: 26)),
              const SizedBox(height: 6),
              Text('Use la cuenta que le asignó el administrador.', style: AppTextStyles.label.copyWith(fontSize: 14)),
              const SizedBox(height: 28),
              Text('Correo', style: _etiqueta),
              const SizedBox(height: 8),
              TextFormField(
                controller: _correoController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: _emailHint),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Escriba su correo' : null,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Text('Contraseña', style: _etiqueta)),
                  InkWell(
                    onTap: _isLoading ? null : _recuperarContrasena,
                    child: Text('¿Olvidó su contraseña?',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Escriba su contraseña' : null,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_errorMessage!, style: TextStyle(color: AppColors.errorText, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Ingresar', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _etiqueta => TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary);
}

/// Mitad izquierda del login: logo, línea dorada y para qué sirve Apolo.
class _PanelInstitucional extends StatelessWidget {
  const _PanelInstitucional();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.isDark ? AppColors.header : const Color(0xFFFAFAF8),
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(58, 56, 58, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En modo oscuro el logo va sobre un recuadro blanco para que se lea.
          const _LogoUdes(alto: 120),
          const Spacer(),
          Container(width: 58, height: 4, color: AppColors.accent),
          const SizedBox(height: 28),
          Text('Apolo UDES',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary)),
          const SizedBox(height: 12),
          Text('Registro de graduandos y control de acceso a las ceremonias de grado.',
              style: TextStyle(fontSize: 30, height: 1.3, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 18),
          Text('Uso exclusivo del personal de la universidad en las tablets de registro y de las entradas.',
              style: AppTextStyles.label.copyWith(fontSize: 15, height: 1.6)),
          const Spacer(),
          // Sellos de acreditación oficiales (versión blanca en modo oscuro).
          Image.asset(
            AppColors.isDark ? 'assets/images/acreditaciones_blanco.png' : 'assets/images/acreditaciones_color.png',
            height: 64,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            semanticLabel: 'Acreditada en alta calidad y acreditación internacional EQUAA',
          ),
          const SizedBox(height: 18),
          Divider(color: AppColors.border),
          const SizedBox(height: 16),
          Text('Universidad de Santander · Campus Lagos del Cacique, Bucaramanga',
              style: AppTextStyles.bodySmall.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _BotonTemaLogin extends StatelessWidget {
  const _BotonTemaLogin();

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<ThemeProvider>();
    return SizedBox(
      width: 44,
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 44)),
        onPressed: tema.siguiente,
        child: Icon(AppColors.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

/// Logo oficial de la universidad: a color en modo claro y con las letras
/// en blanco en modo oscuro, para que siempre se lea sobre el fondo.
class _LogoUdes extends StatelessWidget {
  final double alto;
  const _LogoUdes({this.alto = 150});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppColors.isDark ? 'assets/images/udes_logo_blanco.png' : 'assets/images/udes_logo_color.png',
      height: alto,
      fit: BoxFit.contain,
      semanticLabel: 'Universidad de Santander',
    );
  }
}
