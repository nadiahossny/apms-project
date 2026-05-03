import 'dart:async';
import 'dart:math' as math;
import 'package:apms/mobile_scanner.dart';
import 'theme/tokens.dart';
import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'widgets/shared_widgets.dart';
import 'widgets/medicine_form_dialog.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

enum StockStatus { inStock, warning, critical, outOfStock }

class Medicine {
  final int id;
  final String barcode, serialNumber, tradeName, activeSubstance, company;
  final int quantityOnHand, reorderLevel, maxStock;
  final double unitCost, payRate, discountPct;
  final DateTime expirationDate;
  final String storageLocation;
  final bool requiresRefrigeration;

  const Medicine({
    required this.id, required this.barcode, required this.serialNumber,
    required this.tradeName, required this.activeSubstance, required this.company,
    required this.quantityOnHand, required this.reorderLevel, required this.maxStock,
    required this.unitCost, required this.payRate, required this.discountPct,
    required this.expirationDate, required this.storageLocation, required this.requiresRefrigeration,
  });

  int get daysToExpiry {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return expirationDate.difference(today).inDays;
  }

  StockStatus get stockStatus {
    if (quantityOnHand <= 0) return StockStatus.outOfStock;
    if (daysToExpiry <= 7) return StockStatus.critical;
    if (daysToExpiry <= 30 || quantityOnHand <= reorderLevel) return StockStatus.warning;
    return StockStatus.inStock;
  }

  double get stockPercent {
    if (maxStock > 0) return (quantityOnHand / maxStock).clamp(0.0, 1.0);
    return quantityOnHand > 0 ? 1.0 : 0.0;
  }

  String get expiryLabel {
    final d = daysToExpiry;
    if (d < 0) return 'Expired';
    if (d == 0) return 'Today';
    if (d < 30) return '${d} days';
    
    final months = (d / 30).floor();
    if (d < 365) return '$months mo';
    
    final years = (d / 365).floor();
    final remainingMonths = ((d % 365) / 30).floor();
    return remainingMonths > 0 ? '${years}y ${remainingMonths}mo' : '${years}y';
  }
  bool get isExpiringSoon => daysToExpiry <= 30;
  bool get isLowStock => quantityOnHand <= reorderLevel; 
}

enum InventoryFilter { all, expiring, lowStock, refrigerated }
enum SortColumn { name, qty, expiry, rate }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchCtrl = TextEditingController();

  InventoryFilter _filter = InventoryFilter.all;
  SortColumn _sortCol = SortColumn.name;
  bool _sortAsc = true;
  int? _selectedId;
  String _searchQ = '';
  bool _loading = false;
  String? _offlineMsg;
  final List<Medicine> _medicines = [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQ = _searchCtrl.text.toLowerCase().trim());
    });
    _loadFromApi();
  }

  Future<void> _loadFromApi() async {
    if (!mounted) return;
    setState(() { _loading = true; _offlineMsg = null; });

    try {
      final res = await ApiService.medicines.getAll();
      if (!mounted) return;
      setState(() {
        _medicines.clear();
        _medicines.addAll(
          res.items.map((dto) => Medicine(
            id: dto.id, barcode: dto.barcode, serialNumber: dto.serialNumber ?? '',
            tradeName: dto.tradeName, activeSubstance: dto.activeSubstance, company: dto.companyName,
            quantityOnHand: dto.quantityOnHand, reorderLevel: dto.reorderLevel, maxStock: dto.maxStock,
            unitCost: dto.unitCost, payRate: dto.payRate, discountPct: dto.discountPct,
            expirationDate: DateTime.tryParse(dto.expirationDate) ?? DateTime.now().add(const Duration(days: 365)),
            storageLocation: dto.storageLocation ?? '', requiresRefrigeration: dto.requiresRefrigeration,
          )),
        );
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() => _offlineMsg = e.isOffline ? 'Backend offline. Unable to load inventory.' : 'Error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _offlineMsg = 'Failed to load: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Future<void> _cleanUnknowns() async {
  //   setState(() => _loading = true);
  //   try {
  //     await ApiService.medicines.cleanUnknown();
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All unknown items wiped cleanly!'), backgroundColor: AC.greenFg));
  //       _loadFromApi();
  //     }
  //   } catch (e) {
  //     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Clean failed: $e'), backgroundColor: AC.redFg));
  //     setState(() => _loading = false);
  //   }
  // }

  void _confirmDelete(BuildContext context, Medicine m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.white,
        title: const Text('Delete Medicine?', style: TextStyle(color: AC.redFg, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to completely delete ${m.tradeName} from the database?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AC.ink400))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AC.redBg, foregroundColor: AC.redFg, elevation: 0),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _loading = true);
              try {
                await ApiService.medicines.deleteMedicine(m.id);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully'), backgroundColor: AC.greenFg));
                _loadFromApi();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AC.redFg));
                setState(() => _loading = false);
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  void _confirmAdHocDispatch(BuildContext context, Medicine m) {
    String reason = 'Walk-in Sale'; 
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AC.white,
          title: const Row(
            children: [
              Icon(Icons.precision_manufacturing_rounded, color: AC.blue500),
              SizedBox(width: 8),
              Text('Ad-hoc Robot Dispatch', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Command the robot to pick 1 unit of ${m.tradeName}?'),
              const SizedBox(height: 20),
              const Text('Reason for dispatch:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AC.ink600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AC.page,
                  borderRadius: AR.r8,
                  border: Border.all(color: AC.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: reason,
                    isExpanded: true,
                    items: ['Walk-in Sale', 'Damaged / Waste', 'Internal Display']
                        .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13, color: AC.ink900))))
                        .toList(),
                    onChanged: (v) => setDialogState(() => reason = v!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (reason == 'Walk-in Sale') 
                const Text('✅ This will command the robot, deduct 1 unit from stock, and log the revenue.', style: TextStyle(fontSize: 11, color: AC.greenFg, fontWeight: FontWeight.w600))
              else if (reason == 'Damaged / Waste') 
                const Text('⚠️ This will command the robot and deduct 1 unit as a financial loss.', style: TextStyle(fontSize: 11, color: AC.redFg, fontWeight: FontWeight.w600))
              else 
                const Text('ℹ️ This will only command the robot. Inventory will not be deducted.', style: TextStyle(fontSize: 11, color: AC.blue500, fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx), 
              child: const Text('Cancel', style: TextStyle(color: AC.ink400))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AC.blue500, foregroundColor: AC.white, elevation: 0),
              onPressed: isSubmitting ? null : () async {
                setDialogState(() => isSubmitting = true);
                try {
                  await ApiService.robot.dispatchAdHoc(medicineId: m.id, name: m.tradeName, qty: 1, bin: m.storageLocation);
                  
                  if (reason == 'Walk-in Sale') {
                    await ApiService.prescriptions.createOtcSale([{ 'medicine_id': m.id, 'quantity': 1 }]);
                  }

                  if(mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${m.tradeName} dispatched for $reason'), backgroundColor: AC.greenFg));
                    _loadFromApi(); 
                  }
                } catch (e) {
                  if(mounted) {
                    setDialogState(() => isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AC.redFg));
                  }
                }
              },
              child: isSubmitting 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AC.white, strokeWidth: 2)) 
                  : const Text('Dispatch Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDiscountDialog(BuildContext context, Medicine m) async {
    final ctrl = TextEditingController(text: m.discountPct > 0 ? m.discountPct.toStringAsFixed(0) : '');
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AC.white,
          title: Text('Apply Discount to ${m.tradeName}', style: const TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter percentage (0 to remove):', style: TextStyle(fontSize: 12, color: AC.ink600)),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(suffixText: '%', filled: true, fillColor: AC.page, border: OutlineInputBorder(borderRadius: AR.r8, borderSide: BorderSide.none), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: isSaving ? null : () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AC.ink400))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AC.amberFg, foregroundColor: AC.white),
              onPressed: isSaving ? null : () async {
                final val = double.tryParse(ctrl.text) ?? 0.0;
                if (val < 0 || val > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Must be between 0 and 100'), backgroundColor: AC.redFg));
                  return;
                }
                setDialogState(() => isSaving = true);
                try {
                  final dto = MedicineDto(
                    id: m.id, barcode: m.barcode, serialNumber: m.serialNumber.isEmpty ? null : m.serialNumber,
                    tradeName: m.tradeName, activeSubstance: m.activeSubstance, companyName: m.company,
                    quantityOnHand: m.quantityOnHand, reorderLevel: m.reorderLevel, maxStock: m.maxStock, unitCost: m.unitCost,
                    payRate: m.payRate, discountPct: val, expirationDate: m.expirationDate.toIso8601String(),
                    daysToExpiry: m.daysToExpiry, storageLocation: m.storageLocation.isEmpty ? null : m.storageLocation,
                    requiresRefrigeration: m.requiresRefrigeration, isArchived: false,
                  );
                  await ApiService.medicines.update(m.id, dto.toJson());
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Discount updated!'), backgroundColor: AC.greenFg));
                    _loadFromApi(); 
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AC.redFg));
                  setDialogState(() => isSaving = false);
                }
              },
              child: isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: AC.white, strokeWidth: 2)) : const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv']);
      if (result != null) {
        setState(() => _loading = true);
        final path = result.files.single.path!;
        final bytes = await File(path).readAsBytes();
        await ApiService.medicines.importExcel(bytes, result.files.single.name);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel data imported successfully!'), backgroundColor: AC.greenFg));
          _loadFromApi(); 
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e'), backgroundColor: AC.redFg));
        setState(() => _loading = false);
      }
    }
  }

  void _showForm(BuildContext context, {Medicine? m}) async {
    final dto = m == null ? null : MedicineDto(
      id: m.id, barcode: m.barcode, serialNumber: m.serialNumber.isEmpty ? null : m.serialNumber,
      tradeName: m.tradeName, activeSubstance: m.activeSubstance, companyId: null, companyName: m.company,
      quantityOnHand: m.quantityOnHand, reorderLevel: m.reorderLevel, maxStock: m.maxStock, unitCost: m.unitCost,
      payRate: m.payRate, discountPct: m.discountPct, expirationDate: m.expirationDate.toIso8601String(),
      daysToExpiry: m.daysToExpiry, storageLocation: m.storageLocation.isEmpty ? null : m.storageLocation,
      requiresRefrigeration: m.requiresRefrigeration, isArchived: false,
    );
    final result = await showMedicineDialog(context, existing: dto);
    if (result != null) _loadFromApi();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Medicine> get _filtered {
    var list = _medicines.where((m) {
      if (_searchQ.isNotEmpty) {
        final q = _searchQ;
        if (!(m.tradeName.toLowerCase().contains(q) || m.activeSubstance.toLowerCase().contains(q) || m.barcode.contains(q) || m.storageLocation.toLowerCase().contains(q) || m.company.toLowerCase().contains(q))) return false;
      }
      switch (_filter) {
        case InventoryFilter.all: return true;
        case InventoryFilter.expiring: return m.isExpiringSoon;
        case InventoryFilter.lowStock: return m.isLowStock;
        case InventoryFilter.refrigerated: return m.requiresRefrigeration;
      }
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortCol) {
        case SortColumn.name: cmp = a.tradeName.compareTo(b.tradeName); break;
        case SortColumn.qty: cmp = a.quantityOnHand.compareTo(b.quantityOnHand); break;
        case SortColumn.expiry: cmp = a.daysToExpiry.compareTo(b.daysToExpiry); break;
        case SortColumn.rate: cmp = a.payRate.compareTo(b.payRate); break;
      }
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  Medicine? get _selected {
    if (_selectedId == null || _medicines.isEmpty) return null;
    try { return _medicines.firstWhere((m) => m.id == _selectedId); } catch (_) { return null; }
  }

  void _sort(SortColumn col) {
    setState(() { if (_sortCol == col) { _sortAsc = !_sortAsc; } else { _sortCol = col; _sortAsc = true; } });
  }

  static Color _statusFg(StockStatus s) => switch (s) { StockStatus.inStock => AC.greenFg, StockStatus.warning => AC.amberFg, StockStatus.critical => AC.redFg, StockStatus.outOfStock => AC.ink300 };
  static Color _statusBg(StockStatus s) => switch (s) { StockStatus.inStock => AC.greenBg, StockStatus.warning => AC.amberBg, StockStatus.critical => AC.redBg, StockStatus.outOfStock => AC.page };
  static String _statusLabel(StockStatus s) => switch (s) { StockStatus.inStock => 'In stock', StockStatus.warning => 'Warning', StockStatus.critical => 'Critical', StockStatus.outOfStock => 'Out of stock' };
  static Color _stockBarColor(Medicine m) {
    if (m.quantityOnHand == 0) return AC.ink200;
    if (m.stockStatus == StockStatus.critical) return AC.redFg;
    if (m.quantityOnHand <= m.reorderLevel) return AC.amberFg;
    return AC.greenFg;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AC.page,
      body: Column(
        children: [
          OfflineBanner(message: _offlineMsg, onRetry: _loadFromApi),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          ScreenTopbar(
            title: 'Inventory', subtitle: 'medicines_inventory · Real-time stock',
            actions: [
              _buildSearchField(),
              const SizedBox(width: 10),
              if (AuthService.isManager) ...[
                appBtn(
                  'Import Excel',
                  icon: Icons.upload_file_rounded,
                  bg: const Color(0xFFE8F5E9), 
                  fg: const Color(0xFF2E7D32), 
                  onTap: _importFromExcel,
                ),
                
                const SizedBox(width: 8),
                appBtn(
                  'Scan Medicine',
                  icon: Icons.qr_code_scanner_rounded,
                  bg: AC.blueLt,
                  fg: AC.ink600,
                  onTap: () async {
                    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const MedicineScannerScreen()));
                    if (saved == true && mounted) _loadFromApi();
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showForm(context),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add medicine', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(backgroundColor: AC.blue500, foregroundColor: AC.white, elevation: 0, shape: const RoundedRectangleBorder(borderRadius: AR.r10)),
                ),
              ],
            ],
          ),
          _buildFilters(),
          Expanded(
            child: isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTable()),
                      if (_selected != null)
                        _DetailPanel(
                          medicine: _selected!,
                          onClose: () => setState(() => _selectedId = null),
                          onDispatch: () => _confirmAdHocDispatch(context, _selected!),
                          onEdit: () => _showForm(context, m: _selected!),
                          onDiscount: () => _showDiscountDialog(context, _selected!), 
                        ),
                    ],
                  )
                : _buildMobileList(),
          ),
          _StatusFooter(medicines: _medicines),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      width: 240, height: 36,
      decoration: BoxDecoration(color: const Color(0xFFF3F6FA), borderRadius: AR.r10, border: Border.all(color: AC.border, width: 0.5)),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.search_rounded, size: 15, color: AC.ink300),
          const SizedBox(width: 7),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 12, color: AC.ink900),
              decoration: const InputDecoration(hintText: 'Search by name, barcode, substance, bin…', hintStyle: TextStyle(fontSize: 12, color: AC.ink300), border: InputBorder.none, isDense: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final tabs = [
      (InventoryFilter.all, 'All', null as IconData?),
      (InventoryFilter.expiring, 'Expiring soon', Icons.schedule_outlined),
      (InventoryFilter.lowStock, 'Low stock', Icons.trending_down_rounded),
      (InventoryFilter.refrigerated, 'Refrigerated', Icons.ac_unit_rounded),
    ];

    return Container(
      height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(color: AC.white, border: Border(bottom: BorderSide(color: AC.border, width: 0.5))),
      child: Row(
        children: [
          ...tabs.map((t) {
            final active = _filter == t.$1;
            return InkWell(
              onTap: () => setState(() { _filter = t.$1; _selectedId = null; }),
              borderRadius: AR.pill,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160), margin: const EdgeInsets.only(right: 4), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: active ? AC.blueLt : Colors.transparent, borderRadius: AR.pill, border: Border.all(color: active ? AC.blue500.withOpacity(0.4) : Colors.transparent, width: 0.5)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (t.$3 != null) ...[Icon(t.$3, size: 13, color: active ? AC.blue500 : AC.ink400), const SizedBox(width: 4)],
                    Text(t.$2, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? AC.blue500 : AC.ink400)),
                  ],
                ),
              ),
            );
          }),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AC.page, borderRadius: AR.r8, border: Border.all(color: AC.border, width: 0.5)),
            child: Text('${_filtered.length} of ${_medicines.length}', style: const TextStyle(fontSize: 11, color: AC.ink400)),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      // 🌟 FIXED: Add uniform margin to detach the table from the filter bar!
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
      child: ClipRRect(
        borderRadius: AR.r14,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(constraints.maxWidth, 700.0), 
                child: Column(
                  children: [
                    _TableHeader(sortCol: _sortCol, sortAsc: _sortAsc, onSort: _sort),
                    Expanded(
                      child: _filtered.isEmpty
                          ? _EmptyState(filter: _filter, query: _searchQ)
                          : ListView.builder(
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) {
                                final m = _filtered[i];
                                return _TableRow(
                                  medicine: m,
                                  selected: m.id == _selectedId,
                                  isEven: i.isEven,
                                  onTap: () => setState(() => _selectedId = _selectedId == m.id ? null : m.id),
                                  onEdit: () => _showForm(context, m: m),
                                  onDispatch: () => _confirmAdHocDispatch(context, m),
                                  onDelete: () => _confirmDelete(context, m), 
                                  statusFg: _statusFg(m.stockStatus),
                                  statusBg: _statusBg(m.stockStatus),
                                  statusLabel: _statusLabel(m.stockStatus),
                                  barColor: _stockBarColor(m),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    if (_filtered.isEmpty) return _EmptyState(filter: _filter, query: _searchQ);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final m = _filtered[i];
        return _MobileCard(
          medicine: m, selected: m.id == _selectedId,
          onTap: () => setState(() => _selectedId = _selectedId == m.id ? null : m.id),
          statusFg: _statusFg(m.stockStatus), statusBg: _statusBg(m.stockStatus),
          statusLabel: _statusLabel(m.stockStatus), barColor: _stockBarColor(m),
        );
      },
    );
  }
}

class _TableHeader extends StatelessWidget {
  final SortColumn sortCol;
  final bool sortAsc;
  final ValueChanged<SortColumn> onSort;

  const _TableHeader({required this.sortCol, required this.sortAsc, required this.onSort});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(color: AC.page, border: Border(bottom: BorderSide(color: AC.border, width: 0.5))),
      child: Row(
        children: [
          _Th(label: 'Medicine', flex: 3, col: SortColumn.name, sortCol: sortCol, sortAsc: sortAsc, onSort: onSort),
          _Th(label: 'Barcode', flex: 2, col: null, sortCol: sortCol, sortAsc: sortAsc, onSort: onSort),
          _Th(label: 'Stock', flex: 2, col: SortColumn.qty, sortCol: sortCol, sortAsc: sortAsc, onSort: onSort),
          _Th(label: 'Expiry', flex: 2, col: SortColumn.expiry, sortCol: sortCol, sortAsc: sortAsc, onSort: onSort),
          _Th(label: 'Pay rate', flex: 2, col: SortColumn.rate, sortCol: sortCol, sortAsc: sortAsc, onSort: onSort),
          _Th(label: 'Status', flex: 2, col: null, sortCol: sortCol, sortAsc: sortAsc, onSort: onSort),
          _Th(label: 'Bin', flex: 1, col: null, sortCol: sortCol, sortAsc: sortAsc, onSort: onSort),
          const SizedBox(width: 140),
        ],
      ),
    );
  }
}

class _Th extends StatelessWidget {
  final String label;
  final int flex;
  final SortColumn? col;
  final SortColumn sortCol;
  final bool sortAsc;
  final ValueChanged<SortColumn> onSort;

  const _Th({required this.label, required this.flex, required this.col, required this.sortCol, required this.sortAsc, required this.onSort});

  @override
  Widget build(BuildContext context) {
    final active = col != null && sortCol == col;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: col == null ? null : () => onSort(col!),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Flexible(child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? AC.blue500 : AC.ink300, letterSpacing: 0.4), overflow: TextOverflow.ellipsis)),
              if (col != null) ...[
                const SizedBox(width: 3),
                Icon(active ? (sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) : Icons.unfold_more_rounded, size: 11, color: active ? AC.blue500 : AC.ink200),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  final Medicine medicine;
  final bool selected;
  final bool isEven;
  final VoidCallback onTap, onEdit, onDispatch, onDelete;
  final Color statusFg, statusBg;
  final String statusLabel;
  final Color barColor;

  const _TableRow({
    required this.medicine, required this.selected, required this.isEven,
    required this.onTap, required this.onEdit, required this.onDispatch, required this.onDelete,
    required this.statusFg, required this.statusBg, required this.statusLabel, required this.barColor,
  });

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.medicine;
    final pct = m.stockPercent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120), height: 58,
          decoration: BoxDecoration(
            color: widget.selected ? AC.blueXlt : _hovered ? AC.blueXlt.withOpacity(0.5) : widget.isEven ? AC.white : AC.page.withOpacity(0.4),
            border: Border(bottom: const BorderSide(color: AC.border, width: 0.5), left: BorderSide(color: widget.selected ? AC.blue500 : Colors.transparent, width: 2.5)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(m.tradeName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AC.ink900), overflow: TextOverflow.ellipsis)),
                          if (m.requiresRefrigeration) ...[
                            const SizedBox(width: 5),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: const BoxDecoration(color: AC.blueLt, borderRadius: AR.pill), child: const Text('cold', style: TextStyle(fontSize: 9, color: AC.blue500, fontWeight: FontWeight.w700))),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(m.activeSubstance, style: const TextStyle(fontSize: 10, color: AC.ink300), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),
              Expanded(flex: 2, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(m.barcode, style: const TextStyle(fontFamily: 'Courier', fontSize: 10, color: AC.ink400), overflow: TextOverflow.ellipsis))),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${m.quantityOnHand} units', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AC.ink600)),
                      const SizedBox(height: 4),
                      ClipRRect(borderRadius: AR.pill, child: LinearProgressIndicator(value: pct, backgroundColor: AC.border, valueColor: AlwaysStoppedAnimation<Color>(widget.barColor), minHeight: 3)),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: widget.statusBg, borderRadius: AR.pill),
                      child: Text(m.expiryLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: widget.statusFg), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: FittedBox(
                    fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                    child: Text('EGP ${m.payRate.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AC.ink600)),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Align(alignment: Alignment.centerLeft, child: _StatusBadge(label: widget.statusLabel, fg: widget.statusFg, bg: widget.statusBg)),
                ),
              ),
              Expanded(flex: 1, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text(m.storageLocation, style: const TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.w700, color: AC.ink600), overflow: TextOverflow.ellipsis))),
              SizedBox(
                width: 140, 
                child: AnimatedOpacity(
                  opacity: _hovered || widget.selected ? 1 : 0, duration: const Duration(milliseconds: 160),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RowActionBtn(icon: Icons.edit_outlined, tooltip: 'Edit', onTap: widget.onEdit),
                      const SizedBox(width: 4),
                      _RowActionBtn(icon: Icons.precision_manufacturing_rounded, tooltip: 'Dispatch pick', color: AC.blue500, onTap: widget.onDispatch),
                      const SizedBox(width: 4),
                      _RowActionBtn(icon: Icons.delete_outline_rounded, tooltip: 'Delete Item', color: AC.redFg, onTap: widget.onDelete),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileCard extends StatelessWidget {
  final Medicine medicine;
  final bool selected;
  final VoidCallback onTap;
  final Color statusFg, statusBg, barColor;
  final String statusLabel;

  const _MobileCard({required this.medicine, required this.selected, required this.onTap, required this.statusFg, required this.statusBg, required this.statusLabel, required this.barColor});

  @override
  Widget build(BuildContext context) {
    final m = medicine;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: selected ? AC.blueXlt : AC.white, borderRadius: AR.r12, border: Border.all(color: selected ? AC.blue500 : AC.border, width: selected ? 1.5 : 0.5), boxShadow: AS.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.tradeName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.ink900)),
                      const SizedBox(height: 2),
                      Text(m.activeSubstance, style: const TextStyle(fontSize: 11, color: AC.ink300)),
                    ],
                  ),
                ),
                _StatusBadge(label: statusLabel, fg: statusFg, bg: statusBg),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${m.quantityOnHand} units', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AC.ink600)),
                const Spacer(),
                const Text('Bin: ', style: TextStyle(fontSize: 11, color: AC.ink300)),
                Text(m.storageLocation, style: const TextStyle(fontFamily: 'Courier', fontSize: 11, fontWeight: FontWeight.w700, color: AC.ink600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: AR.pill, child: LinearProgressIndicator(value: m.stockPercent, backgroundColor: AC.border, valueColor: AlwaysStoppedAnimation<Color>(barColor), minHeight: 4)),
          ],
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onClose, onDispatch, onEdit, onDiscount; 

  const _DetailPanel({required this.medicine, required this.onClose, required this.onDispatch, required this.onEdit, required this.onDiscount});

  @override
  Widget build(BuildContext context) {
    final m = medicine;
    return Container(
      width: 300,
      decoration: const BoxDecoration(color: AC.white, boxShadow: AS.panel, border: Border(left: BorderSide(color: AC.border, width: 0.5))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AC.border, width: 0.5))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.tradeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.ink900)),
                      const SizedBox(height: 2),
                      Text(m.activeSubstance, style: const TextStyle(fontSize: 11, color: AC.ink300)),
                    ],
                  ),
                ),
                GestureDetector(onTap: onClose, child: const Icon(Icons.close_rounded, color: AC.ink300, size: 18)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STOCK LEVEL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AC.ink300, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${m.quantityOnHand}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AC.ink900, letterSpacing: -0.5)),
                      const Text(' units', style: TextStyle(fontSize: 13, color: AC.ink400)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: AR.pill,
                    child: LinearProgressIndicator(
                      value: m.stockPercent, 
                      backgroundColor: AC.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        m.quantityOnHand == 0 ? AC.ink200 : 
                        m.stockStatus == StockStatus.critical ? AC.redFg : 
                        m.quantityOnHand <= m.reorderLevel ? AC.amberFg : 
                        AC.greenFg
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('0', style: TextStyle(fontSize: 10, color: AC.ink300)),
                      Text('reorder: ${m.reorderLevel}', style: const TextStyle(fontSize: 10, color: AC.ink300)),
                      Text('max: ${m.maxStock}', style: const TextStyle(fontSize: 10, color: AC.ink300)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(height: 0.5, color: AC.border),
                  const SizedBox(height: 14),
                  const Text('IDENTIFICATION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AC.ink300, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  _PanelRow('Barcode', m.barcode, mono: true),
                  _PanelRow('Serial no.', m.serialNumber, mono: true),
                  _PanelRow('Company', m.company),
                  _PanelRow('Robot bin', m.storageLocation, mono: true, valueColor: AC.blue500),
                  const SizedBox(height: 14),
                  Container(height: 0.5, color: AC.border),
                  const SizedBox(height: 14),
                  const Text('PRICING', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AC.ink300, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  _PanelRow('Unit cost', 'EGP ${m.unitCost.toStringAsFixed(2)}'),
                  _PanelRow('Pay rate', 'EGP ${m.payRate.toStringAsFixed(2)}', valueColor: AC.greenFg),
                  _PanelRow('Discount', m.discountPct > 0 ? '${m.discountPct.toStringAsFixed(0)}%' : 'None', valueColor: m.discountPct > 0 ? AC.amberFg : null),
                  const SizedBox(height: 14),
                  Container(height: 0.5, color: AC.border),
                  const SizedBox(height: 14),
                  const Text('EXPIRY', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AC.ink300, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  _PanelRow('Expiry date', '${m.expirationDate.day.toString().padLeft(2, '0')}/${m.expirationDate.month.toString().padLeft(2, '0')}/${m.expirationDate.year}'),
                  _PanelRow('Days remaining', '${m.daysToExpiry} days', valueColor: m.daysToExpiry <= 7 ? AC.redFg : m.daysToExpiry <= 30 ? AC.amberFg : AC.greenFg),
                  _PanelRow('Refrigerated', m.requiresRefrigeration ? 'Yes — cold chain' : 'No', valueColor: m.requiresRefrigeration ? AC.blue500 : null),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AC.border, width: 0.5))),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onDispatch, 
                    icon: const Icon(Icons.precision_manufacturing_rounded, size: 16),
                    label: const Text('Dispatch robot pick', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(backgroundColor: AC.blue500, foregroundColor: AC.white, shape: const RoundedRectangleBorder(borderRadius: AR.r10), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 10)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDiscount, 
                        style: OutlinedButton.styleFrom(foregroundColor: AC.amberFg, side: const BorderSide(color: AC.amberRing, width: 0.5), shape: const RoundedRectangleBorder(borderRadius: AR.r10), padding: const EdgeInsets.symmetric(vertical: 9)),
                        child: const Text('Apply discount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onEdit, 
                        style: OutlinedButton.styleFrom(foregroundColor: AC.ink600, side: const BorderSide(color: AC.border, width: 0.5), shape: const RoundedRectangleBorder(borderRadius: AR.r10), padding: const EdgeInsets.symmetric(vertical: 9)),
                        child: const Text('Edit details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  final String label, value;
  final bool mono;
  final Color? valueColor;
  const _PanelRow(this.label, this.value, {this.mono = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 11, color: AC.ink300))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor ?? AC.ink600, fontFamily: mono ? 'Courier' : null))),
        ],
      ),
    );
  }
}

class _StatusFooter extends StatelessWidget {
  final List<Medicine> medicines;
  const _StatusFooter({required this.medicines});

  @override
  Widget build(BuildContext context) {
    final ok = medicines.where((m) => m.quantityOnHand > m.reorderLevel && m.daysToExpiry > 30).length;
    final low = medicines.where((m) => m.quantityOnHand > 0 && m.quantityOnHand <= m.reorderLevel).length;
    final exp = medicines.where((m) => m.daysToExpiry > 0 && m.daysToExpiry <= 30).length;
    final out = medicines.where((m) => m.quantityOnHand <= 0).length;

    return Container(
      height: 40, padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(color: AC.white, border: Border(top: BorderSide(color: AC.border, width: 0.5))),
      child: Row(
        children: [
          _FooterDot(color: AC.greenFg, label: '$ok Healthy'), const SizedBox(width: 16),
          _FooterDot(color: AC.blue500, label: '$low Low Stock'), const SizedBox(width: 16),
          _FooterDot(color: AC.amberFg, label: '$exp Expiring Soon'), const SizedBox(width: 16),
          _FooterDot(color: AC.redFg, label: '$out Out of Stock'), const Spacer(),
          const Text('Last synced: just now', style: TextStyle(fontSize: 10, color: AC.ink300)),
        ],
      ),
    );
  }
}

class _FooterDot extends StatelessWidget {
  final Color color;
  final String label;
  const _FooterDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 10, color: AC.ink400))],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final InventoryFilter filter;
  final String query;
  const _EmptyState({required this.filter, required this.query});

  @override
  Widget build(BuildContext context) {
    final message = query.isNotEmpty ? 'No medicines match "$query"' : switch (filter) { InventoryFilter.expiring => 'No medicines expiring within 30 days', InventoryFilter.lowStock => 'All stock levels are healthy', InventoryFilter.refrigerated => 'No refrigerated medicines', InventoryFilter.all => 'No medicines in inventory' };
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(query.isNotEmpty ? Icons.search_off_rounded : Icons.inventory_2_outlined, size: 48, color: AC.ink200),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AC.ink400)),
          const SizedBox(height: 6),
          const Text('Try adjusting your search or filter', style: TextStyle(fontSize: 12, color: AC.ink300)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  const _StatusBadge({required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: bg, borderRadius: AR.pill), child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)));
  }
}

class _RowActionBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _RowActionBtn({required this.icon, required this.tooltip, this.color = AC.ink400, required this.onTap});

  @override
  State<_RowActionBtn> createState() => _RowActionBtnState();
}

class _RowActionBtnState extends State<_RowActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap, behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140), width: 26, height: 26,
              decoration: BoxDecoration(color: _hovered ? widget.color.withOpacity(0.1) : Colors.transparent, borderRadius: AR.r8, border: Border.all(color: _hovered ? widget.color.withOpacity(0.3) : AC.border, width: 0.5)),
              child: Icon(widget.icon, size: 13, color: _hovered ? widget.color : AC.ink400),
            ),
          ),
        ),
      ),
    );
  }
}