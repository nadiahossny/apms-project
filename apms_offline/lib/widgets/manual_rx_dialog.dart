import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../services/api_service.dart';

Future<bool?> showManualRxDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _ManualRxDialog(),
  );
}

class _ManualRxDialog extends StatefulWidget {
  const _ManualRxDialog();

  @override
  State<_ManualRxDialog> createState() => _ManualRxDialogState();
}

class _ManualRxDialogState extends State<_ManualRxDialog> {
  final _codeCtrl = TextEditingController();
  final _patientCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  List<MedicineDto> _inventory = [];// To populate medicine dropdowns
  
  // List of items: { medicine_id: int?, quantity: int }
  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetchMedicines();
    _addItem(); // Start with one empty item row
  }

  Future<void> _fetchMedicines() async {
    try {
      final res = await ApiService.medicines.getAll();
      if (mounted) {
        setState(() {
          _inventory = res.items; // Adjust based on your actual DTO structure
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addItem() {
    setState(() {
      _items.add({'medicine_id': null, 'quantity': 1});
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _save() async {
    // Filter out invalid items
    final validItems = _items.where((i) => i['medicine_id'] != null && i['quantity'] > 0).toList();
    
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one valid medicine item.'), backgroundColor: AC.amberFg));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        "roshetta_code": _codeCtrl.text.trim().isEmpty ? null : _codeCtrl.text.trim(),
        "patient_name": _patientCtrl.text.trim().isEmpty ? null : _patientCtrl.text.trim(),
        "doctor_name": _doctorCtrl.text.trim().isEmpty ? null : _doctorCtrl.text.trim(),
        "items": validItems.map((i) => {
          "medicine_id": i['medicine_id'], // Will be null if typed manually
          "quantity_prescribed": i['quantity'],
          "requested_name": i['manual_name'] // Sends the custom typed name to the backend
        }).toList(),
      };

      // Assuming you have a create method in your ApiService.prescriptions
      await ApiService.prescriptions.create(payload);
      
      if (mounted) {
        Navigator.of(context).pop(true); // Return true on success
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prescription created successfully!'), backgroundColor: AC.greenFg));
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
      title: const Text('Add Manual Prescription', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 500,
        child: _isLoading 
          ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildField('Roshetta Code (Optional)', _codeCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildField('Patient Name', _patientCtrl)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildField('Doctor Name', _doctorCtrl),
                  const SizedBox(height: 20),
                  
                  const Text('PRESCRIPTION ITEMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AC.ink300, letterSpacing: 1.2)),
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
                            child: Autocomplete<MedicineDto>(
                              // Explicitly define the parameter type here:
                              displayStringForOption: (MedicineDto option) => option.tradeName,
                              optionsBuilder: (TextEditingValue textValue) {
                                if (textValue.text.isEmpty) return _inventory;
                                return _inventory.where((m) => 
                                  m.tradeName.toLowerCase().contains(textValue.text.toLowerCase())
                                );
                              },
                              // Explicitly define the parameter type here:
                              onSelected: (MedicineDto option) {
                                setState(() {
                                  _items[idx]['medicine_id'] = option.id; // Make sure 'id' matches your DTO property
                                  _items[idx]['manual_name'] = option.tradeName;
                                });
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  onChanged: (val) {
                                    // If they type manually without selecting, clear the ID
                                    _items[idx]['medicine_id'] = null;
                                    _items[idx]['manual_name'] = val;
                                  },
                                  style: const TextStyle(fontSize: 12),
                                  decoration: const InputDecoration(
                                    hintText: 'Search inventory or type custom name...',
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
                    label: const Text('Add Medicine'),
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
          child: _isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AC.white)) : const Text('Save Prescription'),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
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