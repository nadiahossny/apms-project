import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../services/api_service.dart';

class MedicineLinkerSheet extends StatefulWidget {
  final String initialSearch;
  final ValueChanged<MedicineDto> onLinked;

  const MedicineLinkerSheet({
    super.key,
    required this.initialSearch,
    required this.onLinked,
  });

  /// Helper method used specifically by the Prescriptions Screen to link directly to the database
  static Future<bool?> show(BuildContext context, int prescriptionItemId, String scannedName) async {
    final selectedMed = await showModalBottomSheet<MedicineDto>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MedicineLinkerSheet(
        initialSearch: scannedName,
        onLinked: (med) => Navigator.pop(context, med), // Returns the selected medicine
      ),
    );

    if (selectedMed != null) {
      try {
        // Link the medicine in the PostgreSQL database immediately
        await ApiService.prescriptions.linkMedicine(prescriptionItemId, selectedMed.id);
        return true; // Signals the parent screen to refresh
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to link: $e'), backgroundColor: AC.redFg)
          );
        }
        return false;
      }
    }
    return false;
  }

  @override
  State<MedicineLinkerSheet> createState() => _MedicineLinkerSheetState();
}

class _MedicineLinkerSheetState extends State<MedicineLinkerSheet> {
  final _searchCtrl = TextEditingController();
  List<MedicineDto> _inventory = [];
  List<MedicineDto> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialSearch;
    _searchCtrl.addListener(_filter);
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    try {
      final res = await ApiService.medicines.getAll(limit: 500); 
      if (!mounted) return;
      setState(() {
        _inventory = res.items;
        _loading = false;
      });
      _filter(); 
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load inventory: $e';
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = _inventory.where((m) {
        return m.tradeName.toLowerCase().contains(q) ||
               m.activeSubstance.toLowerCase().contains(q) ||
               m.barcode.contains(q);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AC.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AC.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: AC.border, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Link Medicine to Inventory',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AC.ink900),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close_rounded, color: AC.ink300),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Search for: ${widget.initialSearch}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AC.blue500),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search inventory to link...',
                    prefixIcon: Icon(Icons.search_rounded, color: AC.ink300),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AC.redFg, fontSize: 12)),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AC.blue500))
                : _filtered.isEmpty
                    ? const Center(child: Text('No matching medicines found in inventory.', style: TextStyle(color: AC.ink400)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final m = _filtered[index];
                          final outOfStock = m.quantityOnHand <= 0;
                          
                          return ListTile(
                            tileColor: AC.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: AR.r10,
                              side: BorderSide(color: AC.border, width: 0.5),
                            ),
                            title: Text(m.tradeName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('${m.activeSubstance}\nBin: ${m.storageLocation}', style: const TextStyle(fontSize: 12, color: AC.ink400)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('EGP ${m.payRate.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AC.ink900)),
                                Text(
                                  outOfStock ? 'Out of stock' : '${m.quantityOnHand} units',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: outOfStock ? AC.redFg : AC.greenFg,
                                  ),
                                ),
                              ],
                            ),
                            onTap: outOfStock ? null : () => widget.onLinked(m),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}