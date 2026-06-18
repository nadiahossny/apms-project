import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart'; 

void main() {
  runApp(const RoshettyApp());
}

class RoshettyApp extends StatelessWidget {
  const RoshettyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roshetty',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8AB6F9), 
          primary: const Color(0xFF8AB6F9), // Pastel Blue
          secondary: const Color(0xFFB3D4FF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9FBFC),
      ),
      home: const WelcomeScreen(), 
    );
  }
}