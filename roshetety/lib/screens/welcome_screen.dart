// roshetty/lib/screens/welcome_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:roshetety/screens/home_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _arabic = true;
  String _t(String ar, String en) => _arabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF4F9FF), Color(0xFFE0EAFC)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Align(
                    alignment: _arabic ? Alignment.topLeft : Alignment.topRight,
                    child: TextButton(
                      onPressed: () => setState(() => _arabic = !_arabic),
                      child: Text(_arabic ? 'English' : 'عربي', 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5A8DEE))),
                    ),
                  ),
                  const Spacer(),
                  // Circular Ghibli-style branding
                  Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
                    ),
                    child: const Icon(Icons.spa_rounded, size: 80, color: Color(0xFF8AB6F9)),
                  ),
                  const SizedBox(height: 40),
                  Text(_t('روشتتي', 'Roshetty'),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50), letterSpacing: -1)),
                  const SizedBox(height: 12),
                  Text(_t('صيدليتك في يدك', 'Your pharmacy in your hands'),
                    style: const TextStyle(fontSize: 18, color: Color(0xFF6B7280))),
                  const Spacer(),
                  // Premium Pill Button
                  GestureDetector(
                    // Update the GestureDetector's onTap
onTap: () => Navigator.of(context).pushReplacement(
  MaterialPageRoute(builder: (_) => HomeScreen(arabic: _arabic)),
),
                    child: Container(
                      height: 65,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A8DEE),
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: [BoxShadow(color: const Color(0xFF5A8DEE).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: Center(
                        child: Text(_t('ابدأ الآن', 'Get Started'),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}