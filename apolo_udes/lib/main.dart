import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'data/services/database_service.dart';
import 'providers/app_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  // Asegura la inicialización de los bindings de Flutter antes de llamadas asíncronas
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Firebase con las opciones de configuración multiplataforma
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicialización de los servicios de base de datos local
  await DatabaseService.initialize();
  
  // Configuración de los formatos locales de fecha en español (Colombia)
  await initializeDateFormatting('es_CO', null);

  runApp(const ApoloUdesApp());
}

class ApoloUdesApp extends StatelessWidget {
  const ApoloUdesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Carga automática de los datos de los graduandos al inicializar el proveedor
      create: (_) => AppProvider()..cargarGraduandosDesdeDB(),
      child: MaterialApp(
        title: 'Apolo UDES',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        
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
    );
  }
}

/// Controla la transición visual entre la pantalla de inicio de sesión
/// y la pantalla principal (Home) según el estado de autenticación del usuario.
class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    // Escucha el estado de autenticación desde el AppProvider
    final isAuthenticated = context.watch<AppProvider>().isAuthenticated;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      // Transición fluida de 300ms entre pantallas
      child: isAuthenticated
          ? const HomeScreen(key: ValueKey('home'))
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}