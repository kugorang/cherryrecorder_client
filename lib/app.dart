import 'package:flutter/material.dart';
import 'features/splash/presentation/screens/splash_screen.dart';

class CherryRecorderApp extends StatelessWidget {
  const CherryRecorderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '체리 레코더',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
