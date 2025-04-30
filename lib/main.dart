import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:catzoteam/home.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Firebase.initializeApp();
  runApp(const CatzoTeamApp());
}

class CatzoTeamApp extends StatelessWidget {
  const CatzoTeamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, decoration: TextDecoration.none),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
        ),
      ),
      home: HomeScreen(),
    );
  }
}