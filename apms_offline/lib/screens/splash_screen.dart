// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> {
  // Using a softer "Cozy" palette
  final Color _softBlue = const Color(0xFFE3F2FD); 

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Minimalist Brand Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: AC.blue500.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 8)),
                ],
              ),
              child: const Icon(Icons.local_pharmacy_rounded, color: AC.blue500, size: 64),
            ),
            const SizedBox(height: 24),
            const Text(
              'PharmaSys',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AC.ink900, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'INTELLIGENT DISPENSING',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AC.blue500.withOpacity(0.6), letterSpacing: 2),
            ),
            const SizedBox(height: 64),
            const SizedBox(
              width: 40,
              child: LinearProgressIndicator(backgroundColor: Colors.white, valueColor: AlwaysStoppedAnimation(AC.blue500), minHeight: 2),
            ),
          ],
        ),
      ),
    );
  }
}