import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/tokens.dart';

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

      final ocrResult = await ApiService.invoices.uploadInvoiceImage(image.path);

      if (mounted) {
        setState(() {
          _parsedData = ocrResult;
          _scanned = true;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to extract invoice: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_scanned && _parsedData != null) {
      return InvoiceReviewScreen(parsedData: _parsedData!);
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
              const Text('AI will automatically extract items with quantities and prices.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AC.ink400)),
              const SizedBox(height: 40),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(_error!, style: const TextStyle(color: AC.redFg, fontSize: 12), textAlign: TextAlign.center),
                ),

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

class _EditableInvoiceItem {
  String name;
  int quantity;
  double unitCost;

  _EditableInvoiceItem({
    required this.name,
    required this.quantity,
    required this.unitCost,
  });

  Map<String, dynamic> toJson() => {
    'manual_name': name,
    'quantity': quantity,
    'unit_cost': unitCost,
  };
}

class InvoiceReviewScreen extends StatefulWidget {
  final Map<String, dynamic> parsedData;
  const InvoiceReviewScreen({super.key, required this.parsedData});

  @override
  State<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends State<InvoiceReviewScreen> {
  late List<_EditableInvoiceItem> _items;
  late TextEditingController _fatooraCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _totalCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _dateCtrl;
  bool _saving = false;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final data = widget.parsedData;
    _fatooraCtrl = TextEditingController(
      text: data['fatoora_number']?.toString() ?? 'INV-OCR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    _companyCtrl = TextEditingController(
      text: data['company_name']?.toString() ?? 'Unknown Supplier',
    );
    _totalCtrl = TextEditingController(
      text: ((data['total_amount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
    );
    _discountCtrl = TextEditingController(
      text: ((data['total_discount'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2),
    );
    _dateCtrl = TextEditingController(
      text: data['invoice_date']?.toString() ?? DateTime.now().toIso8601String().split('T').first,
    );

    final rawItems = data['items'] as List? ?? [];
    _items = rawItems.map((item) {
      if (item is Map) {
        return _EditableInvoiceItem(
          name: item['name']?.toString() ?? item['original_name']?.toString() ?? '',
          quantity: int.tryParse(item['quantity']?.toString() ?? '1') ?? 1,
          unitCost: double.tryParse(item['unit_cost']?.toString() ?? '0') ?? 0.0,
        );
      }
      return _EditableInvoiceItem(name: item.toString(), quantity: 1, unitCost: 0.0);
    }).toList();
  }

  @override
  void dispose() {
    _fatooraCtrl.dispose();
    _companyCtrl.dispose();
    _totalCtrl.dispose();
    _discountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_EditableInvoiceItem(name: '', quantity: 1, unitCost: 0.0)));
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _save() async {
    if (_fatooraCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Fatoora number is required');
      return;
    }

    setState(() { _saving = true; _error = null; });

    try {
      await ApiService.invoices.create({
        'fatoora_number': _fatooraCtrl.text.trim(),
        'company_name': _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
        'invoice_date': _dateCtrl.text.trim(),
        'total_amount': double.tryParse(_totalCtrl.text) ?? 0.0,
        'total_discount': double.tryParse(_discountCtrl.text) ?? 0.0,
        'payment_status': 'PENDING',
        'ocr_raw_json': widget.parsedData,
        'items': _items.map((i) => i.toJson()).toList(),
      });

      if (mounted) {
        setState(() => _saved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice saved successfully! Medicines added to inventory.'), backgroundColor: AC.greenFg),
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.page,
      appBar: AppBar(
        backgroundColor: AC.white,
        foregroundColor: AC.ink900,
        elevation: 0,
        title: const Text('Review Invoice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(0.5), child: Container(height: 0.5, color: AC.border)),
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
                      decoration: BoxDecoration(color: AC.greenBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.greenFg.withOpacity(0.4))),
                      child: const Row(children: [Icon(Icons.check_circle_rounded, color: AC.greenFg), SizedBox(width: 10), Text('Invoice saved successfully', style: TextStyle(color: AC.greenFg, fontWeight: FontWeight.w600))]),
                    ),

                  _buildEditableField('Fatoora Number *', _fatooraCtrl),
                  const SizedBox(height: 10),
                  _buildEditableField('Company Name', _companyCtrl),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildEditableField('Invoice Date', _dateCtrl)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildEditableField('Total (EGP)', _totalCtrl)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildEditableField('Discount (EGP)', _discountCtrl)),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text('LINE ITEMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AC.ink300, letterSpacing: 1.2)),
                      const Spacer(),
                      Text('${_items.length} items', style: const TextStyle(fontSize: 11, color: AC.ink400)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ..._items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AC.white, borderRadius: AR.r10, border: Border.all(color: AC.border, width: 0.5)),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: TextEditingController(text: item.name),
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(labelText: 'Medicine Name', filled: true, fillColor: AC.page, border: OutlineInputBorder(borderRadius: AR.r8, borderSide: BorderSide.none), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              onChanged: (val) => item.name = val,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: TextEditingController(text: item.quantity.toString()),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(labelText: 'Qty', filled: true, fillColor: AC.page, border: OutlineInputBorder(borderRadius: AR.r8, borderSide: BorderSide.none), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              onChanged: (val) => item.quantity = int.tryParse(val) ?? 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: TextEditingController(text: item.unitCost.toStringAsFixed(2)),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(labelText: 'Cost', filled: true, fillColor: AC.page, border: OutlineInputBorder(borderRadius: AR.r8, borderSide: BorderSide.none), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              onChanged: (val) => item.unitCost = double.tryParse(val) ?? 0.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AC.redFg, size: 20),
                            onPressed: () => _removeItem(idx),
                          ),
                        ],
                      ),
                    );
                  }),

                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Item'),
                    style: TextButton.styleFrom(foregroundColor: AC.blue500),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AC.redBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.redFg.withOpacity(0.4))),
                      child: Text(_error!, style: const TextStyle(color: AC.redFg, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(color: AC.white, border: Border(top: BorderSide(color: AC.border, width: 0.5))),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(foregroundColor: AC.ink600, side: const BorderSide(color: AC.border), minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _saving || _saved ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(_saving ? 'Saving...' : 'Save Invoice'),
                    style: ElevatedButton.styleFrom(backgroundColor: AC.blue500, foregroundColor: AC.white, minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: AC.ink400),
        filled: true, fillColor: AC.white,
        border: OutlineInputBorder(borderRadius: AR.r8, borderSide: BorderSide(color: AC.border)),
        isDense: true,
      ),
    );
  }
}