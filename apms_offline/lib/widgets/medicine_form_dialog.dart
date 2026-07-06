// ═══════════════════════════════════════════════════════════════════════════
// lib/widgets/medicine_form_dialog.dart
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/tokens.dart'; // Added tokens import

Future<MedicineDto?> showMedicineDialog(
  BuildContext context, {
  MedicineDto? existing,
}) {
  return showDialog<MedicineDto>(
    context: context,
    barrierDismissible: false,
    builder: (_) => MedicineFormDialog(existing: existing),
  );
}

class MedicineFormDialog extends StatefulWidget {
  final MedicineDto? existing;
  const MedicineFormDialog({super.key, this.existing});

  @override
  State<MedicineFormDialog> createState() => _MedicineFormDialogState();
}

class _MedicineFormDialogState extends State<MedicineFormDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  int _section = 0; 

  late final TextEditingController _barcode;
  late final TextEditingController _serialNo;
  late final TextEditingController _tradeName;
  late final TextEditingController _substance;
  late final TextEditingController _company;
  late final TextEditingController _qty;
  late final TextEditingController _reorder;
  late final TextEditingController _maxStock;
  late final TextEditingController _unitCost;
  late final TextEditingController _payRate;
  late final TextEditingController _discount;
  late final TextEditingController _binLoc;
  late final TextEditingController _expiryDate;
  late bool _refrigerated;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _barcode = TextEditingController(text: e?.barcode ?? '');
    _serialNo = TextEditingController(text: e?.serialNumber ?? '');
    _tradeName = TextEditingController(text: e?.tradeName ?? '');
    _substance = TextEditingController(text: e?.activeSubstance ?? '');
    _company = TextEditingController(text: e?.companyName ?? '');
    _qty = TextEditingController(text: e?.quantityOnHand.toString() ?? '0');
    _reorder = TextEditingController(text: e?.reorderLevel.toString() ?? '10');
    _maxStock = TextEditingController(text: e?.maxStock.toString() ?? '200');
    _unitCost = TextEditingController(
      text: e?.unitCost.toStringAsFixed(2) ?? '0.00',
    );
    _payRate = TextEditingController(
      text: e?.payRate.toStringAsFixed(2) ?? '0.00',
    );
    _discount = TextEditingController(
      text: e?.discountPct.toStringAsFixed(2) ?? '0.00',
    );
    _binLoc = TextEditingController(text: e?.storageLocation ?? '');
    _expiryDate = TextEditingController(text: e?.expirationDate ?? '');
    _refrigerated = e?.requiresRefrigeration ?? false;
  }

  @override
  void dispose() {
    for (final c in [_barcode, _serialNo, _tradeName, _substance, _company, _qty, _reorder, _maxStock, _unitCost, _payRate, _discount, _binLoc, _expiryDate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });

    final data = {
      'barcode': _barcode.text.trim(),
      'serial_number': _serialNo.text.trim().isEmpty ? null : _serialNo.text.trim(),
      'trade_name': _tradeName.text.trim(),
      'active_substance': _substance.text.trim(),
      'company_name': _company.text.trim(), 
      'quantity_on_hand': int.parse(_qty.text),
      'reorder_level': int.parse(_reorder.text),
      'max_stock': int.parse(_maxStock.text),
      'unit_cost': double.parse(_unitCost.text),
      'pay_rate': double.parse(_payRate.text),
      'discount_pct': double.parse(_discount.text),
      'expiration_date': _expiryDate.text.trim(),
      'storage_location': _binLoc.text.trim().isEmpty ? null : _binLoc.text.trim(),
      'requires_refrigeration': _refrigerated,
    };

    try {
      final MedicineDto result;
      if (_isEdit) {
        result = await ApiService.medicines.update(widget.existing!.id, data);
      } else {
        result = await ApiService.medicines.create(data);
      }
      if (mounted) Navigator.of(context).pop(result);
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } on NetworkException catch (e) {
      setState(() {
        _error = e.isOffline ? 'Network timeout or gateway unreachable. Check LAN host.' : 'Network error: ${e.message}';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(2040),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AC.blue500),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _expiryDate.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: Container(
          decoration: BoxDecoration(
            color: AC.white,
            borderRadius: AR.r14,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: Column(
            children: [
              _buildHeader(),
              _buildSectionTabs(),
              Expanded(
                child: Form(
                  key: _formKey, 
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8), 
                    child: _buildSectionContent(),
                  ),
                ),
              ),
              if (_error != null) _buildError(),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    decoration: const BoxDecoration(
      color: AC.blue500,
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    child: Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: AR.r8),
          child: Icon(_isEdit ? Icons.edit_rounded : Icons.add_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEdit ? 'Edit medicine' : 'Add new medicine', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              if (_isEdit)
                Text(widget.existing!.tradeName, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.7), size: 20),
        ),
      ],
    ),
  );

  Widget _buildSectionTabs() {
    final tabs = ['Identification', 'Stock', 'Pricing', 'Expiry & Storage'];
    return Container(
      height: 42,
      decoration: const BoxDecoration(color: Color(0xFFF4F9FF), border: Border(bottom: BorderSide(color: AC.border, width: 0.5))),
      child: Row(
        children: tabs.asMap().entries.map((e) {
          final active = e.key == _section;
          return GestureDetector(
            onTap: () => setState(() => _section = e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? AC.blue500 : Colors.transparent, width: 2))),
              child: Center(
                child: Text(
                  e.value,
                  style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? AC.blue500 : AC.ink400),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: [
        _sectionIdentification(),
        _sectionStock(),
        _sectionPricing(),
        _sectionExpiry(),
      ][_section],
    );
  }

  Widget _sectionIdentification() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _row([
        _field('Trade name *', _tradeName, required: true, hint: 'e.g. Panadol 500mg'),
        _field('Active substance *', _substance, required: true, hint: 'e.g. Paracetamol'),
      ]),
      const SizedBox(height: 16),
      _row([
        _field('Barcode *', _barcode, required: true, hint: 'EAN-13 / GS1', keyboard: TextInputType.number),
        _field('Serial / lot number', _serialNo, hint: 'e.g. LOT-2024-PA01'),
      ]),
      const SizedBox(height: 16),
      _row([
        _field('Supplier company *', _company, required: true, hint: 'e.g. Pharmaoverseas'),
        const Expanded(child: SizedBox()),
      ]),
    ],
  );

  Widget _sectionStock() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _row([
        _field(
          'Quantity on hand *', _qty, required: true, hint: '0', keyboard: TextInputType.number, onChanged: (_) => setState(() {}),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (int.tryParse(v) == null) return 'Must be a whole number';
            return null;
          },
        ),
        _field('Reorder level *', _reorder, required: true, hint: '10', keyboard: TextInputType.number),
      ]),
      const SizedBox(height: 16),
      _row([
        _field('Max stock *', _maxStock, required: true, hint: '200', keyboard: TextInputType.number),
        const Expanded(child: SizedBox()),
      ]),
      const SizedBox(height: 20),
      _stockPreview(),
    ],
  );

  Widget _stockPreview() {
    final qty = int.tryParse(_qty.text) ?? 0;
    final max = int.tryParse(_maxStock.text) ?? 200;
    final reord = int.tryParse(_reorder.text) ?? 10;
    final pct = max > 0 ? (qty / max).clamp(0.0, 1.0) : 0.0;
    final color = qty == 0 ? AC.ink300 : pct < 0.15 ? AC.redFg : pct < 0.35 ? AC.amberFg : AC.greenFg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Stock preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AC.ink400)),
            Text('$qty / $max units', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(100)),
          child: LinearProgressIndicator(value: pct, backgroundColor: AC.border, valueColor: AlwaysStoppedAnimation(color), minHeight: 6),
        ),
        const SizedBox(height: 4),
        Text('Reorder at $reord units', style: const TextStyle(fontSize: 10, color: AC.ink400)),
      ],
    );
  }

  Widget _sectionPricing() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _row([
        _field('Unit cost (EGP) *', _unitCost, required: true, hint: '0.00', keyboard: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
        _field('Pay rate / selling price (EGP) *', _payRate, required: true, hint: '0.00', keyboard: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
      ]),
      const SizedBox(height: 16),
      _row([
        _field(
          'Discount % (0–100)', _discount, hint: '0.00', keyboard: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            if (v == null || v.isEmpty) return null;
            final d = double.tryParse(v);
            if (d == null || d < 0 || d > 100) return 'Must be 0–100';
            return null;
          },
        ),
        const Expanded(child: SizedBox()),
      ]),
      const SizedBox(height: 20),
      _marginPreview(),
    ],
  );

  Widget _marginPreview() {
    final cost = double.tryParse(_unitCost.text) ?? 0;
    final rate = double.tryParse(_payRate.text) ?? 0;
    final disc = double.tryParse(_discount.text) ?? 0;
    final margin = rate > 0 ? ((rate - cost) / rate * 100) : 0.0;
    final effectiveRate = rate * (1 - disc / 100);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.greenBg, borderRadius: AR.r10, border: Border.all(color: const Color(0xFFA7F3D0), width: 0.5)),
      child: Row(
        children: [
          _marginStat('Unit cost', 'EGP ${cost.toStringAsFixed(2)}'),
          _divLine(),
          _marginStat('Effective rate', 'EGP ${effectiveRate.toStringAsFixed(2)}'),
          _divLine(),
          _marginStat('Gross margin', '${margin.toStringAsFixed(1)}%', color: margin > 0 ? AC.greenFg : AC.redFg),
        ],
      ),
    );
  }

  Widget _marginStat(String label, String val, {Color? color}) => Expanded(
    child: Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AC.ink400)),
        const SizedBox(height: 3),
        Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color ?? AC.ink900)),
      ],
    ),
  );

  Widget _divLine() => Container(width: 0.5, height: 32, color: const Color(0xFFA7F3D0));

  Widget _sectionExpiry() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _row([
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Expiry date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AC.ink600)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: AbsorbPointer(
                  child: TextFormField(
                    controller: _expiryDate,
                    style: const TextStyle(fontSize: 13, color: AC.ink900),
                    decoration: const InputDecoration(
                      hintText: 'YYYY-MM-DD', suffixIcon: Icon(Icons.calendar_today_outlined, size: 16, color: AC.ink400),
                      hintStyle: TextStyle(fontSize: 13, color: AC.ink400), filled: true, fillColor: AC.page,
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AC.border, width: 0.5)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AC.border, width: 0.5)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Expiry date required';
                      if (DateTime.tryParse(v) == null) return 'Use YYYY-MM-DD format';
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        _field('Robot bin / storage location', _binLoc, hint: 'e.g. A-03-B'),
      ]),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: () => setState(() => _refrigerated = !_refrigerated),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _refrigerated ? AC.blueLt : AC.page,
            borderRadius: AR.r10,
            border: Border.all(color: _refrigerated ? AC.blue500 : AC.border, width: _refrigerated ? 1.5 : 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: _refrigerated ? AC.blue500.withOpacity(0.1) : AC.border, borderRadius: AR.r8),
                child: Icon(Icons.ac_unit_rounded, color: _refrigerated ? AC.blue500 : AC.ink400, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Requires refrigeration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _refrigerated ? AC.blue500 : AC.ink600)),
                    const Text('Cold chain — stored in refrigerated unit', style: TextStyle(fontSize: 10, color: AC.ink400)),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: _refrigerated ? AC.blue500 : Colors.white,
                  borderRadius: AR.r8,
                  border: Border.all(color: _refrigerated ? AC.blue500 : AC.ink400, width: 1.5),
                ),
                child: _refrigerated ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildError() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: AC.redBg, borderRadius: AR.r10, border: Border.all(color: AC.redRing, width: 0.5)),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AC.redFg, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: AC.redFg))),
      ],
    ),
  );

  // FIX: Converted custom buttons to matching app styling (ElevatedButton and TextButton)
  Widget _buildFooter() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AC.border, width: 0.5))),
    child: Row(
      children: [
        if (_section > 0)
          TextButton.icon(
            onPressed: () => setState(() => _section--),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(foregroundColor: AC.ink600),
          ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AC.ink400),
          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        if (_section < 3)
          ElevatedButton.icon(
            onPressed: () => setState(() => _section++),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Next', style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(backgroundColor: AC.blue500, foregroundColor: AC.white, shape: const RoundedRectangleBorder(borderRadius: AR.r10), elevation: 0),
          )
        else
          ElevatedButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading 
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AC.white, strokeWidth: 2)) 
                : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded, size: 16),
            label: Text(_isEdit ? 'Save changes' : 'Add medicine', style: const TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(backgroundColor: AC.blue500, foregroundColor: AC.white, shape: const RoundedRectangleBorder(borderRadius: AR.r10), elevation: 0),
          ),
      ],
    ),
  );

  Widget _row(List<Widget> children) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: children.asMap().entries.map((e) => e.key < children.length - 1 ? [e.value, const SizedBox(width: 16)] : [e.value]).expand((x) => x).toList(),
  );

  Widget _field(String label, TextEditingController ctrl, {bool required = false, String? hint, TextInputType keyboard = TextInputType.text, String? Function(String?)? validator, void Function(String)? onChanged}) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AC.ink600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl, keyboardType: keyboard, onChanged: onChanged, style: const TextStyle(fontSize: 13, color: AC.ink900),
          decoration: InputDecoration(
            hintText: hint, hintStyle: const TextStyle(fontSize: 13, color: AC.ink400), filled: true, fillColor: AC.page,
            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AC.border, width: 0.5)),
            enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AC.border, width: 0.5)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: AC.blue500, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
          validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null : null),
        ),
      ],
    ),
  );
}