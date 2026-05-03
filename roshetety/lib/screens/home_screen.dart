// roshetty/lib/screens/home_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:roshetety/screens/ocr_screen.dart';
import 'package:roshetety/services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final bool arabic; 
  const HomeScreen({super.key, required this.arabic});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _manualInputController = TextEditingController();
  late bool _currentArabic;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _currentArabic = widget.arabic;
  }

  String _t(String ar, String en) => _currentArabic ? ar : en;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _currentArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF4F9FF), Color(0xFFE0EAFC)], // Soft pastel blue sky
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Language Toggle ──
                  Align(
                    alignment: _currentArabic ? Alignment.topLeft : Alignment.topRight,
                    child: TextButton(
                      onPressed: () => setState(() => _currentArabic = !_currentArabic),
                      child: Text(_currentArabic ? 'English' : 'عربي', 
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF5A8DEE))),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(_t('مرحباً بك', 'Welcome'), 
                    style: const TextStyle(fontSize: 20, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                  const Text('Roshetty APMS', 
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF5A8DEE), letterSpacing: -1)),
                  
                  const SizedBox(height: 40),

                  // ── Action Section: Manual Request ──
                  _sectionHeader(_t('طلب سريع', 'Quick Request')),
                  const SizedBox(height: 16),
                  _buildGlassCard(
                    child: Column(
                      children: [
                        TextField(
                          controller: _manualInputController,
                          decoration: InputDecoration(
                            hintText: _t('اسم الدواء...', 'Medicine name...'),
                            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                            border: InputBorder.none,
                            prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF8AB6F9)),
                            contentPadding: const EdgeInsets.all(20),
                          ),
                        ),
                        _buildActionPill(
                          label: _t('إرسال للصيدلية', 'Send to Pharmacy'),
                          onTap: _submitManualOrder,
                          isLoading: _isSubmitting,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Action Section: OCR Scan ──
                  _sectionHeader(_t('مسح الروشتة', 'Scan Prescription')),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => OcrScreen(arabic: _currentArabic))
                    ),
                    child: _buildGlassCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8AB6F9).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.document_scanner_rounded, size: 54, color: Color(0xFF5A8DEE)),
                              ),
                              const SizedBox(height: 20),
                              Text(_t('فتح الكاميرا', 'Open Camera'), 
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF5A8DEE))),
                            ],
                          ),
                        ),
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

  // ── UI Components ──

  Widget _sectionHeader(String text) => Text(text, 
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)));

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildActionPill({required String label, required VoidCallback onTap, required bool isLoading}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFF5A8DEE),
            borderRadius: BorderRadius.circular(27),
            boxShadow: [BoxShadow(color: const Color(0xFF5A8DEE).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Center(
            child: isLoading 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Future<void> _submitManualOrder() async {
    final text = _manualInputController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      // Direct call to place order with "requested" name
      await RoshettyApi.placeOrder(cartItems: [{'requested': text, 'quantity': 1}]);
      if (!mounted) return;
      _manualInputController.clear();
      _showCustomToast(_t('تم الإرسال بنجاح', 'Sent successfully'));
    } catch (e) {
      _showCustomToast(_t('فشل الإرسال', 'Failed to send'), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showCustomToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF8AB6F9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}