import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../services/api_service.dart';
import 'package:apms/widgets/medicine_form_dialog.dart'; // FIX: Imported form dialog

Future<bool?> showManualInvoiceDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _ManualInvoiceDialog(),
  );
}

class _ManualInvoiceDialog extends StatefulWidget {
  const _ManualInvoiceDialog();

  @override
  State<_ManualInvoiceDialog> createState() => _ManualInvoiceDialogState();
}

class _ManualInvoiceDialogState extends State<_ManualInvoiceDialog> {
  final _fatooraCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  
  DateTime _invoiceDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  List<MedicineDto> _inventory = [];
  
  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchMedicines();
    _addItem();
  }

  Future<void> _fetchMedicines() async {
    try {
      final res = await ApiService.medicines.getAll();
      if (mounted) {
        setState(() {
          _inventory = res.items; 
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addItem() => setState(() => _items.add({'medicine_id': null, 'quantity': 1, 'unit_cost': 0.0}));
  void _removeItem(int index) => setState(() => _items.removeAt(index));

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _invoiceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _invoiceDate = date);
    }
  }

  Future<void> _save() async {
    if (_fatooraCtrl.text.trim().isEmpty || _totalCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fatoora number and Total Amount are required.'), backgroundColor: AC.redFg));
      return;
    }

    if (_items.any((i) => i['medicine_id'] == null && (i['manual_name']?.isNotEmpty ?? false))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('For invoices, you MUST select the medicine from the dropdown list to track inventory.'), backgroundColor: AC.amberFg));
      return; 
    }

    final validItems = _items.where((i) => i['medicine_id'] != null && i['quantity'] > 0).toList();

    try {
      final payload = {
        "fatoora_number": _fatooraCtrl.text.trim(),
        "company_name": _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim(),
        "invoice_date": _invoiceDate.toIso8601String().split('T').first,
        "total_amount": double.tryParse(_totalCtrl.text) ?? 0.0,
        "total_discount": double.tryParse(_discountCtrl.text) ?? 0.0,
        "payment_status": "PENDING",
        "items": validItems.map((i) => {
          "medicine_id": i['medicine_id'],
          "quantity": i['quantity'],
          "unit_cost": i['unit_cost']
        }).toList(),
      };

      await ApiService.invoices.create(payload);
      
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice saved successfully!'), backgroundColor: AC.greenFg));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AC.redFg));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AC.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('Add Manual Invoice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 600,
        child: _isLoading 
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildField('Fatoora Number *', _fatooraCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField('Company Name', _companyCtrl)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildField('Total Amount (EGP) *', _totalCtrl, isNumber: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField('Total Discount', _discountCtrl, isNumber: true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: const BoxDecoration(color: AC.page, borderRadius: AR.r8),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 16, color: AC.ink400),
                          const SizedBox(width: 8),
                          Text('Invoice Date: ${_invoiceDate.toIso8601String().split('T').first}', style: const TextStyle(fontSize: 13, color: AC.ink900)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text('RECEIVED ITEMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AC.ink300, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  
                  ..._items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Autocomplete<MedicineDto>(
                                    displayStringForOption: (MedicineDto option) => option.tradeName,
                                    optionsBuilder: (TextEditingValue textValue) {
                                      if (textValue.text.isEmpty) return _inventory;
                                      return _inventory.where((m) => 
                                        m.tradeName.toLowerCase().contains(textValue.text.toLowerCase())
                                      );
                                    },
                                    onSelected: (MedicineDto option) {
                                      setState(() {
                                        _items[idx]['medicine_id'] = option.id;
                                        _items[idx]['manual_name'] = option.tradeName;
                                      });
                                    },
                                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                      return TextField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        onChanged: (val) {
                                          _items[idx]['medicine_id'] = null;
                                          _items[idx]['manual_name'] = val;
                                        },
                                        style: const TextStyle(fontSize: 12),
                                        decoration: const InputDecoration(
                                          hintText: 'Search inventory...',
                                          filled: true, 
                                          fillColor: AC.page, 
                                          border: OutlineInputBorder(borderRadius: AR.r8, borderSide: BorderSide.none), 
                                          isDense: true, 
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                                        ),
                                      );
                                    },
                                    optionsViewBuilder: (context, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 4, borderRadius: AR.r8, color: AC.white,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 280),
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero, shrinkWrap: true,
                                              itemCount: options.length,
                                              itemBuilder: (context, index) {
                                                final MedicineDto option = options.elementAt(index);
                                                return InkWell(
                                                  onTap: () => onSelected(option),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(12),
                                                    child: Text(option.tradeName, style: const TextStyle(fontSize: 12)),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // FIX: Added button to register a new medicine without losing form progress
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: AC.blue500, size: 20),
                                  tooltip: 'Add new medicine to database',
                                  onPressed: () async {
                                    final newMed = await showMedicineDialog(context);
                                    if (newMed != null && mounted) {
                                      setState(() {
                                        _inventory.add(newMed);
                                        _items[idx]['medicine_id'] = newMed.id;
                                        _items[idx]['manual_name'] = newMed.tradeName;
                                        _items[idx]['unit_cost'] = newMed.unitCost;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              initialValue: item['quantity'].toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Qty', filled: true, fillColor: AC.page, border: OutlineInputBorder(borderRadius: AR.r8, borderSide: BorderSide.none), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              onChanged: (val) => _items[idx]['quantity'] = int.tryParse(val) ?? 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              key: ValueKey(item['unit_cost'].toString()), // Forces update if auto-filled
                              initialValue: item['unit_cost'].toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Cost', filled: true, fillColor: AC.page, border: OutlineInputBorder(borderRadius: AR.r8, borderSide: BorderSide.none), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                              onChanged: (val) => _items[idx]['unit_cost'] = double.tryParse(val) ?? 0.0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AC.redFg, size: 20),
                            onPressed: () => _removeItem(idx),
                          )
                        ],
                      ),
                    );
                  }),
                  
                  TextButton.icon(
                    onPressed: _addItem, 
                    icon: const Icon(Icons.add, size: 16), 
                    label: const Text('Add Item'),
                    style: TextButton.styleFrom(foregroundColor: AC.blue500),
                  )
                ],
              ),
            ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AC.ink400)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AC.blue500, foregroundColor: AC.white, shape: const RoundedRectangleBorder(borderRadius: AR.r8)),
          onPressed: _isSaving || _isLoading ? null : _save,
          child: _isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AC.white)) : const Text('Save Invoice'),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: AC.ink400),
        filled: true,
        fillColor: AC.page,
        border: const OutlineInputBorder(borderRadius: AR.r8, borderSide: BorderSide.none),
        isDense: true,
      ),
    );
  }
}