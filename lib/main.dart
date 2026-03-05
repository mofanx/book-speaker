import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/service_locator.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initServices();
  runApp(const BookSpeakerApp());
}

class BookSpeakerApp extends StatelessWidget {
  const BookSpeakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Book Speaker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
    );
  }
}
