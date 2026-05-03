// lib/screens/rx_scanner_screen.dart
// Scans Ministry of Health prescription QR → pre-fills prescription form
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../theme/tokens.dart';

const _blue = Color(0xFF4A90D9);
const _blueLt = Color(0xFFEBF4FF);
const _page = Color(0xFFF0F4F8);
const _white = Color(0xFFFFFFFF);
const _ink9 = Color(0xFF111827);
const _ink6 = Color(0xFF374151);
const _ink3 = Color(0xFF9CA3AF);
const _green = Color(0xFF059669);
const _red = Color(0xFFDC2626);
const _border = Color(0xFFE5E9EE);

class RxScannerScreen extends StatefulWidget {
  const RxScannerScreen({super.key});
  @override
  State<RxScannerScreen> createState() => _RxScannerState();
}

class _RxScannerState extends State<RxScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  String? _error;
  _ScannedRx? _parsed;
  bool _scanned = false;

  Future<void> _processImage(ImageSource source) async {
    setState(() { _loading = true; _error = null; });
    
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // 🌟 CALLING DEMIANA'S OCR API
      final uri = Uri.parse('https://barley-salsa-krypton.ngrok-free.app/extract');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // final data = jsonDecode(response.body);
        // 🌟 Clean API Service Call!
     final medsList = await ApiService.ocr.extractMedicines(image.path);
      
      // 🌟 Updated mapping: 'm' is now just the name string directly
      final parsedMeds = medsList.map((m) => _RxMed(
        name: m.toString().toUpperCase(),
        qty: 1,
      )).toList();

      if (mounted) {
        setState(() {
          _parsed = _ScannedRx(
            roshettaCode: 'OCR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
            patientName: 'Walk-in (OCR Scan)',
            doctorName: 'AI Engine',
            medicines: parsedMeds, 
          );
          _scanned = true;
          _loading = false;
        });
      }
      } else {
        throw Exception('AI Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to extract text: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If successfully scanned, show your existing Review Sheet!
    if (_scanned && _parsed != null) {
      return _RxReviewSheet(rx: _parsed!, onRescan: () {
        setState(() {
          _scanned = false;
          _parsed = null;
        });
      });
    }

    return Scaffold(
      backgroundColor: AC.page,
      appBar: AppBar(
        backgroundColor: AC.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AC.ink900),
        title: const Text('AI Roshetta Scanner', style: TextStyle(color: AC.ink900, fontSize: 16, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(color: AC.blueLt, shape: BoxShape.circle),
                child: _loading 
                  ? const CircularProgressIndicator(color: AC.blue500, strokeWidth: 3)
                  : const Icon(Icons.document_scanner_rounded, size: 64, color: AC.blue500),
              ),
              const SizedBox(height: 32),
              const Text('Upload Prescription', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AC.ink900)),
              const SizedBox(height: 8),
              const Text('AI will automatically extract the medicines.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AC.ink400)),
              const SizedBox(height: 40),
              
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(_error!, style: const TextStyle(color: AC.redFg, fontSize: 12), textAlign: TextAlign.center),
                ),

              // UI Match: BLUE buttons for AI/Scanning
              Row(
                children: [
                  Expanded(
                    child: _buildUploadOption(
                      icon: Icons.camera_alt_rounded,
                      title: 'Take Photo',
                      onTap: () => _processImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildUploadOption(
                      icon: Icons.photo_library_rounded,
                      title: 'Gallery',
                      onTap: () => _processImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadOption({required IconData icon, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: _loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
        child: Column(
          children: [
            Icon(icon, color: AC.blue500, size: 32),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.ink900)),
          ],
        ),
      ),
    );
  }
}

class _ScannedRx {
  final String roshettaCode;
  final String patientName;
  final String doctorName;
  final List<_RxMed> medicines;

  _ScannedRx({
    required this.roshettaCode,
    required this.patientName,
    required this.doctorName,
    required this.medicines,
  });
}

class _RxMed {
  final String name;
  final int qty;

  const _RxMed({required this.name, required this.qty});
}

class _RxReviewSheet extends StatefulWidget {
  final _ScannedRx rx;
  final VoidCallback onRescan; // 🌟 1. Tell it to expect a function

  // 🌟 2. Add 'required this.onRescan' to the constructor
  const _RxReviewSheet({required this.rx, required this.onRescan});

  @override
  State<_RxReviewSheet> createState() => _RxReviewState();
}

class _RxReviewState extends State<_RxReviewSheet> {
  bool _saving = false;
  String? _error;
  bool _saved = false;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ApiService.prescriptions.create({
        'roshetta_code': widget.rx.roshettaCode,
        'patient_name': widget.rx.patientName,
        'doctor_name': widget.rx.doctorName,
        'items': widget.rx.medicines
            .map(
              (m) => {
                'requested_name': m.name,
                'quantity_prescribed': m.qty,
                'medicine_id': null,
              },
            )
            .toList(),
      });
      
      if (!mounted) return;
      setState(() {
        _saved = true;
        _saving = false;
      });
      
      // Delay closing so user sees the success message
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop(true);
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rx = widget.rx;
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _white,
        foregroundColor: _ink9,
        elevation: 0,
        title: const Text(
          'Review Prescription',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_saved)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _green.withAlpha((0.4 * 255).toInt()),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: _green),
                          SizedBox(width: 10),
                          Text(
                            'Prescription saved',
                            style: TextStyle(
                              color: _green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Patient + doctor info
                  appCard('Prescription details', [
                    _row(
                      'Code',
                      rx.roshettaCode.isEmpty
                          ? 'Auto-generated'
                          : rx.roshettaCode,
                    ),
                    _row(
                      'Patient',
                      rx.patientName.isEmpty
                          ? 'Not encoded in QR'
                          : rx.patientName,
                    ),
                    _row(
                      'Doctor',
                      rx.doctorName.isEmpty
                          ? 'Not encoded in QR'
                          : rx.doctorName,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Medicines list
                  Container(
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: Text(
                            'Medicines',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _ink9,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Divider(height: 16),
                        ),
                        if (rx.medicines.isEmpty)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: Text(
                              'No medicines encoded in QR — add manually after saving',
                              style: TextStyle(fontSize: 12, color: _ink3),
                            ),
                          )
                        else
                          ...rx.medicines.map(
                            (m) => Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _blueLt,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.medication_rounded,
                                        color: _blue,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      m.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _ink9,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _blueLt,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Text(
                                      '×${m.qty}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _red.withAlpha((0.4 * 255).toInt()),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: _red, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: _white,
              border: Border(top: BorderSide(color: _border, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onRescan,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                    label: const Text('Re-scan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink6,
                      side: const BorderSide(color: _border),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _saving || _saved ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(_saving ? 'Saving…' : 'Save prescription'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: _white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget appCard(String title, List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: _white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink9,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Divider(height: 16),
        ),
        ...rows.map(
          (r) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: r,
          ),
        ),
      ],
    ),
  );

  Widget _row(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 80,
        child: Text(label, style: const TextStyle(fontSize: 12, color: _ink3)),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _ink6,
          ),
        ),
      ),
    ],
  );
}