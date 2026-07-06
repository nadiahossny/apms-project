// lib/screens/ocr_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'result_screen.dart';
import '../services/api_service.dart';

class OcrScreen extends StatefulWidget {
  final bool arabic; 
  const OcrScreen({super.key, required this.arabic});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  String? _error;
  late bool _currentArabic;

  @override
  void initState() {
    super.initState();
    _currentArabic = widget.arabic;
  }

  String _t(String ar, String en) => _currentArabic ? ar : en;

  Future<void> _processImage(ImageSource source) async {
    setState(() { _loading = true; _error = null; });
    
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final uri = Uri.parse('http://${RoshettyApi.host}:8001/upload');
      
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'ngrok-skip-browser-warning': 'true', 
        });

      // ── التعديل الجديد عشان يشتغل على الويب والموبايل ──
      final imageBytes = await image.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'file', 
          imageBytes,
          filename: image.name, 
        )
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseBody);
        
        final List<dynamic> rawMeds = decoded['medicine_names'] ?? [];
        
        final List<Map<String, dynamic>> medicines = rawMeds.map((medicineName) => {
          'name': medicineName.toString(),
          'quantity': 1, 
        }).toList();

        if (medicines.isEmpty) {
          _setError(_t('لم يتعرف الخادم على أي أدوية.', 'No medicine names found by server.'));
          return;
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ResultScreen(meds: medicines, arabic: _currentArabic)),
        );
      } else {
         _setError(_t('خطأ في الخادم: ${response.statusCode}', 'Server error: ${response.statusCode}'));
         debugPrint('OCR Backend Error: $responseBody');
      }

    } catch (e) {
      _setError(_t('حدث خطأ أثناء الاتصال.', 'Connection error.'));
      debugPrint('OCR Exception: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  void _setError(String msg) {
    if (!mounted) return;
    setState(() { _error = msg; _loading = false; });
  }

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
              colors: [Color(0xFFF4F9FF), Color(0xFFE0EAFC)]
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Align(
                    alignment: _currentArabic ? Alignment.topLeft : Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF5A8DEE)),
                    ),
                  ),
                  const Spacer(),
                  _buildScannerIcon(),
                  const SizedBox(height: 40),
                  Text(
                    _loading ? _t('جاري التحليل...', 'Analyzing with AI...') : _t('مسح الروشتة', 'Scan Prescription'),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF2C3E50)),
                  ),
                  const SizedBox(height: 40),
                  if (_error != null) 
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3))
                      ),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 14), textAlign: TextAlign.center),
                    ),
                  const Spacer(),
                  
                  // ── Premium Pill Buttons ──
                  if (_loading)
                     const Center(child: CircularProgressIndicator(color: Color(0xFF5A8DEE)))
                  else ...[
                    _buildPillButton(
                      onTap: () => _processImage(ImageSource.camera),
                      label: _t('التقاط صورة', 'Take Photo'),
                      icon: Icons.camera_alt_rounded,
                      isPrimary: true,
                    ),
                    const SizedBox(height: 16),
                    _buildPillButton(
                      onTap: () => _processImage(ImageSource.gallery),
                      label: _t('اختيار من المعرض', 'Choose from Gallery'),
                      icon: Icons.photo_library_rounded,
                      isPrimary: false,
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerIcon() {
    return Container(
      width: 140, height: 140,
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), shape: BoxShape.circle),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.document_scanner_rounded, size: 60, color: Theme.of(context).colorScheme.primary),
          if (_loading) 
             SizedBox(
               width: 140, height: 140,
               child: CircularProgressIndicator(
                 strokeWidth: 3,
                 color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
               ),
             )
        ],
      ),
    );
  }

  Widget _buildPillButton({required VoidCallback onTap, required String label, required IconData icon, required bool isPrimary}) {
    return GestureDetector(
      onTap: _loading ? null : onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF5A8DEE) : Colors.white.withOpacity(0.6),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isPrimary ? Colors.white : const Color(0xFF5A8DEE)),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: isPrimary ? Colors.white : const Color(0xFF5A8DEE), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}