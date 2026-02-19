import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/screens/menu_screen.dart';
import 'package:elongacion_musical/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsService = await SettingsService.init();

  if (settingsService.lockPortrait) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } else {
    // Reset to defaults if not locked (though usually defaults include landscape)
    // Or explicit allow all:
    await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
    ]);
  }

  runApp(MyApp(settingsService: settingsService));
}

class MyApp extends StatelessWidget {
  final SettingsService settingsService;

  const MyApp({super.key, required this.settingsService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MixerProvider(settingsService)),
      ],
      child: MaterialApp(
        title: 'Elongación Musical',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212), // AppColors.background
          colorScheme: const ColorScheme.dark(
            primary: Colors.cyanAccent,
            secondary: Colors.redAccent,
            surface: Color(0xFF1E1E1E), // AppColors.surface
          ),
          useMaterial3: true,
          fontFamily: 'Roboto', // Default, we can change later if needed
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E), // AppColors.surface
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Colors.white70, 
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        home: const MenuScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
