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
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await DatabaseService.initialize();
  await initializeDateFormatting('es_CO', null);

  runApp(const ApoloUdesApp());
}

class ApoloUdesApp extends StatelessWidget {
  const ApoloUdesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
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
        home: const _AppRoot(),
      ),
    );
  }
}

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