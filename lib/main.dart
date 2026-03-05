import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/providers/theme_provider.dart';
import 'package:elongacion_musical/screens/menu_screen.dart';
import 'package:elongacion_musical/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:elongacion_musical/providers/metronome_provider.dart';
import 'package:provider/provider.dart';

import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsService = await SettingsService.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(MyApp(settingsService: settingsService));
}

class MyApp extends StatelessWidget {
  final SettingsService settingsService;

  const MyApp({super.key, required this.settingsService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(settingsService)),
        ChangeNotifierProvider(create: (_) => MixerProvider(settingsService)),
        ChangeNotifierProvider(create: (_) => MetronomeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Elongación Musical',
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFFFF4EB),
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFF97316),
                onPrimary: Colors.white,
                secondary: Color(0xFFD32F2F),
                onSecondary: Colors.white,
                error: Color(0xFFD32F2F),
                onError: Colors.white,
                surface: Color(0xFFFFFFFF),
                onSurface: Color(0xFF3E2723),
              ),
              useMaterial3: true,
              fontFamily: 'Roboto',
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFFFFFFF),
                elevation: 0,
                centerTitle: true,
                titleTextStyle: TextStyle(
                  color: Color(0xFF3E2723), 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF1E1A17),
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFFF98533),
                onPrimary: Colors.white,
                secondary: Color(0xFFE55353),
                onSecondary: Colors.white,
                error: Color(0xFFD32F2F),
                onError: Colors.white,
                surface: Color(0xFF2C2621),
                onSurface: Color(0xFFF2EBE5),
              ),
              useMaterial3: true,
              fontFamily: 'Roboto',
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF2C2621),
                elevation: 0,
                centerTitle: true,
                titleTextStyle: TextStyle(
                  color: Color(0xFFF2EBE5), 
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            home: const MenuScreen(),
            debugShowCheckedModeBanner: false,
          );
        }
      ),
    );
  }
}

