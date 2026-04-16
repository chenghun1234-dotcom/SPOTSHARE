import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'services/error_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp();
  runApp(const SpotShareApp());
}

class SpotShareApp extends StatelessWidget {
  const SpotShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpotShare',
      theme: ThemeData(primarySwatch: Colors.blue),
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: const SplashScreen(),
    );
  }
}

