import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/settings.dart';
import 'services/service_locator.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initServices();
  S.setLocale(settingsService.appLocale);
  runApp(const BookSpeakerApp());
}

class BookSpeakerApp extends StatelessWidget {
  const BookSpeakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: S.notifier,
      builder: (_, __, ___) {
        final themeMode = _getFlutterThemeMode(settingsService.themeMode);
        return MaterialApp(
          title: 'Book Speaker',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            colorSchemeSeed: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.blue,
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          home: const HomeScreen(),
        );
      },
    );
  }

  ThemeMode _getFlutterThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
