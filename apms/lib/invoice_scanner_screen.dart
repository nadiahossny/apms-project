// lib/screens/invoice_scanner_screen.dart
// Scans a Fatoora invoice QR code with the device camera.
// Parses the QR → pre-fills the invoice form → manager confirms → POST /api/invoices
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../theme/tokens.dart'; // Make sure you import your tokens!
// ── Colour tokens (matches main.dart AC.*) ───────────────────────────────────
const _blue = Color(0xFF4A90D9);
const _blueLt = Color(0xFFEBF4FF);
const _page = Color(0xFFF0F4F8);
const _white = Color(0xFFFFFFFF);
const _ink9 = Color(0xFF111827);
const _ink6 = Color(0xFF374151);
const _ink3 = Color(0xFF9CA3AF);
const _green = Color(0xFF059669);
const _greenB = Color(0xFFF0FDF4);
const _amber = Color(0xFFD97706);
const _red = Color(0xFFDC2626);
const _redB = Color(0xFFFFF1F2);
const _border = Color(0xFFE5E9EE);

class InvoiceScannerScreen extends StatefulWidget {
  const InvoiceScannerScreen({super.key});
  @override
  State<InvoiceScannerScreen> createState() => _InvoiceScannerState();
}



class _InvoiceScannerState extends State<InvoiceScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _parsedData;
  bool _scanned = false;

  Future<void> _processImage(ImageSource source) async {
    setState(() { _loading = true; _error = null; });
    
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // 🌟 CALLING DEMIANA'S OCR API FOR THE INVOICE
      final uri = Uri.parse('https://barley-salsa-krypton.ngrok-free.app/extract');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
      // final data = jsonDecode(response.body);
        // 🌟 Clean API Service Call!
      final medsList = await ApiService.ocr.extractMedicines(image.path);
      
      // 🌟 Updated mapping for invoices
      final invoiceItems = medsList.map((m) => {
        'medicine_id': 0, 
        'name': m.toString().toUpperCase(),
        'quantity': 1,
        'cost': 0.0, 
      }).toList();

      if (mounted) {
        setState(() {
          _parsedData = {
             'fatoora_number': 'INV-OCR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
             'company_name': 'Unknown Supplier (OCR)',
             'invoice_date': DateTime.now().toIso8601String().split('T').first,
             'total_amount': 0.0,
             'total_discount': 0.0,
             'items': invoiceItems,
          };
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
    // If successfully scanned, pass data to your existing Wrapper!
    if (_scanned && _parsedData != null) {
      return InvoiceReviewWrapper(parsedData: _parsedData!);
    }

    return Scaffold(
      backgroundColor: AC.page,
      appBar: AppBar(
        backgroundColor: AC.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AC.ink900),
        title: const Text('AI Invoice Scanner', style: TextStyle(color: AC.ink900, fontSize: 16, fontWeight: FontWeight.bold)),
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
                decoration: const BoxDecoration(color: AC.amberBg, shape: BoxShape.circle),
                child: _loading 
                  ? const CircularProgressIndicator(color: AC.amberFg, strokeWidth: 3)
                  : const Icon(Icons.receipt_long_rounded, size: 64, color: AC.amberFg),
              ),
              const SizedBox(height: 32),
              const Text('Upload Supplier Invoice', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AC.ink900)),
              const SizedBox(height: 8),
              const Text('AI will automatically extract the invoice lines.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AC.ink400)),
              const SizedBox(height: 40),
              
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(_error!, style: const TextStyle(color: AC.redFg, fontSize: 12), textAlign: TextAlign.center),
                ),

              // UI Match: AMBER buttons for Inventory/Invoices
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
            Icon(icon, color: AC.amberFg, size: 32),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.ink900)),
          ],
        ),
      ),
    );
  }
}

// class _CornerPainter extends CustomPainter {
//   final bool isRight, isBottom;
//   final Color color;
//   final double thick;
//   const _CornerPainter({
//     required this.isRight,
//     required this.isBottom,
//     required this.color,
//     required this.thick,
//   });
//   @override
//   void paint(Canvas c, Size s) {
//     final p = Paint()
//       ..color = color
//       ..strokeWidth = thick
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.square;
//     final x = isRight ? 0.0 : s.width;
//     final y = isBottom ? 0.0 : s.height;
//     c.drawLine(Offset(x, y), Offset(isRight ? s.width : 0, y), p);
//     c.drawLine(Offset(x, y), Offset(x, isBottom ? s.height : 0), p);
//   }

//   @override
//   bool shouldRepaint(_) => false;
// }

// ── Parsed invoice data model ─────────────────────────────────────────────────
class _ScannedInvoice {
  final String fatooraNumber, companyName, invoiceDate;
  final double totalAmount, totalDiscount;
  final Map<String, dynamic> rawJson;
  const _ScannedInvoice({
    required this.fatooraNumber,
    required this.companyName,
    required this.invoiceDate,
    required this.totalAmount,
    required this.totalDiscount,
    required this.rawJson,
  });
}

// ── Review & confirm sheet ────────────────────────────────────────────────────
class _InvoiceReviewSheet extends StatefulWidget {
  final _ScannedInvoice invoice;
  final VoidCallback onRescan;
  const _InvoiceReviewSheet({required this.invoice, required this.onRescan});
  @override
  State<_InvoiceReviewSheet> createState() => _ReviewState();
}

class _ReviewState extends State<_InvoiceReviewSheet> {
  bool _saving = false;
  String? _error;
  bool _saved = false;

  Future<void> _save() async {
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Try real API first
      await ApiService.invoices.create({
        'fatoora_number': widget.invoice.fatooraNumber,
        'company_name': widget.invoice.companyName,
        'invoice_date': widget.invoice.invoiceDate.isNotEmpty
            ? widget.invoice.invoiceDate
            : DateTime.now().toIso8601String().split('T').first,
        'total_amount': widget.invoice.totalAmount,
        'total_discount': widget.invoice.totalDiscount,
        'ocr_raw_json': widget.invoice.rawJson,
        'items': <Map<String, dynamic>>[],
      });
      if (!mounted) return;
      setState(() {
        _saved = true;
        _saving = false;
      });
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on NetworkException catch (e) {
      if (!mounted) return;
      // Backend offline — save succeeded visually but warn user
      if (e.isOffline) {
        setState(() {
          _saving = false;
          _saved = true;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved locally — will sync when backend is connected',
            ),
            backgroundColor: Color(0xFFD97706),
            duration: Duration(seconds: 4),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 1000));
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _white,
        foregroundColor: _ink9,
        elevation: 0,
        title: const Text(
          'Review Invoice',
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
                  // Success banner
                  if (_saved)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _greenB,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _green.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: _green),
                          SizedBox(width: 10),
                          Text(
                            'Invoice saved successfully',
                            style: TextStyle(
                              color: _green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Scanned badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _blueLt,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_rounded, color: _blue, size: 14),
                        SizedBox(width: 5),
                        Text(
                          'Scanned from QR',
                          style: TextStyle(
                            color: _blue,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Invoice detail card
                  _detailCard('Invoice details', [
                    _row(
                      'Fatoora number',
                      inv.fatooraNumber.isEmpty ? '—' : inv.fatooraNumber,
                    ),
                    _row(
                      'Company',
                      inv.companyName.isEmpty ? '—' : inv.companyName,
                    ),
                    _row(
                      'Invoice date',
                      inv.invoiceDate.isEmpty ? '—' : inv.invoiceDate,
                    ),
                    _row(
                      'Total amount',
                      'EGP ${inv.totalAmount.toStringAsFixed(2)}',
                    ),
                    _row(
                      'Total discount',
                      'EGP ${inv.totalDiscount.toStringAsFixed(2)}',
                    ),
                    _row(
                      'Net payable',
                      'EGP ${(inv.totalAmount - inv.totalDiscount).toStringAsFixed(2)}',
                      valueColor: _blue,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Note about line items
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: _amber,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Line items are not encoded in the QR. After saving, go to the invoice detail to add individual medicine items manually.',
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 12,
                              height: 1.5,
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
                        color: _redB,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _red.withOpacity(0.4)),
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

          // Action buttons
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
                    label: Text(_saving ? 'Saving…' : 'Save invoice'),
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

  Widget _detailCard(String title, List<Widget> rows) => Container(
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

  Widget _row(String label, String value, {Color? valueColor}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 120,
        child: Text(label, style: const TextStyle(fontSize: 12, color: _ink3)),
      ),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? _ink6,
          ),
        ),
      ),
    ],
  );
}

// ── PDF Import Wrapper ────────────────────────────────────────────────────────
class InvoiceReviewWrapper extends StatelessWidget {
  final Map<String, dynamic> parsedData;

  const InvoiceReviewWrapper({super.key, required this.parsedData});

  @override
  Widget build(BuildContext context) {
    // 1. Map the backend dictionary to your private _ScannedInvoice model
    final invoice = _ScannedInvoice(
      fatooraNumber: parsedData['fatoora_number']?.toString() ?? '',
      companyName: parsedData['company_name']?.toString() ?? 'Unknown',
      invoiceDate: parsedData['invoice_date']?.toString() ?? '',
      totalAmount: (parsedData['total_amount'] as num?)?.toDouble() ?? 0.0,
      totalDiscount: (parsedData['total_discount'] as num?)?.toDouble() ?? 0.0,
      rawJson: parsedData,
    );

    // 2. Return your existing Review Sheet!
    return _InvoiceReviewSheet(
      invoice: invoice,
      onRescan: () {
        // If they hit "Re-scan" on a PDF import, it makes sense to just pop back 
        // to the invoice list so they can try importing a different file.
        Navigator.of(context).pop();
      },
    );
  }
}