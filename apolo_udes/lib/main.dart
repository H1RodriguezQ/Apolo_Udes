import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'data/services/database_service.dart';
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  // Asegura la inicialización de los bindings de Flutter antes de llamadas asíncronas
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Firebase con las opciones de configuración multiplataforma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // En la web la sesión dura solo mientras la pestaña esté abierta: al
  // cerrarla, la próxima vez pide correo y contraseña. En la tablet Android
  // la sesión se sigue recordando para que el operador no la escriba a cada rato.
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
  }

  // Persistencia sin conexión: Firestore guarda en disco la última copia
  // leída, así que la tablet sigue mostrando los graduandos y validando QR
  // aunque se quede sin internet (la copia de seguridad en SQLite es
  // complementaria: sirve para abrir la app ya sin conexión).
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      // 100 MB (el máximo permitido): alcanza de sobra para cientos de
      // graduandos e invitados, y evita que Firestore borre la caché.
      cacheSizeBytes: 100 * 1024 * 1024,
    );
  }

  // Inicialización de los servicios de base de datos local
  await DatabaseService.initialize();

  // Configuración de los formatos locales de fecha en español (Colombia)
  await initializeDateFormatting('es_CO', null);

  // Carga el modo de tema guardado (claro, oscuro o sistema)
  final themeProvider = ThemeProvider();
  await themeProvider.cargar();

  runApp(ApoloUdesApp(themeProvider: themeProvider));
}

class ApoloUdesApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const ApoloUdesApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Carga automática de los datos de los graduandos al inicializar el proveedor
        ChangeNotifierProvider(
            create: (_) => AppProvider()..cargarGraduandosDesdeDB()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, tema, _) => MaterialApp(
          title: 'Apolo UDES',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: tema.modo,

          // Sincroniza AppColors con el modo real y reconstruye la interfaz
          builder: (context, child) {
            final oscuro = tema.modo == ThemeMode.dark ||
                (tema.modo == ThemeMode.system &&
                    MediaQuery.platformBrightnessOf(context) ==
                        Brightness.dark);
            AppColors.isDark = oscuro;
            return KeyedSubtree(
              key: ValueKey(oscuro),
              child: child ?? const SizedBox.shrink(),
            );
          },

          // ── Localización para DatePicker en español ──
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'CO'),
            Locale('en', 'US'),
          ],
          locale: const Locale('es', 'CO'),

          // Widget raíz que evalúa el estado de la sesión
          home: const _AppRoot(),
        ),
      ),
    );
  }
}

/// Controla la transición visual entre la pantalla de inicio de sesión
/// y la pantalla principal (Home) según el estado de autenticación del usuario.
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.watch<AppProvider>().isAuthenticated;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: isAuthenticated
          ? const HomeScreen(key: ValueKey('home'))
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}