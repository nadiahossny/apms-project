import 'dart:async';
import 'package:apms/widgets/manual_invoice_dialog.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/tokens.dart';
import '../services/api_service.dart';
import '../widgets/shared_widgets.dart';
import '../invoice_scanner_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesState();
}

class _InvoicesState extends State<InvoicesScreen> {
  final _search = TextEditingController();
  String _filter = 'ALL'; 
  int? _selected;
  bool _apiLoading = false;

  static const _statuses = ['ALL', 'PENDING', 'PARTIAL', 'PAID'];

  final _invoices = <_Invoice>[];

  List<_Invoice> get _filtered => _invoices.where((inv) {
    final q = _search.text.toLowerCase();
    final matchQ = q.isEmpty || inv.number.toLowerCase().contains(q) || inv.company.toLowerCase().contains(q);
    final matchF = _filter == 'ALL' || inv.status == _filter;
    return matchQ && matchF;
  }).toList();

  String? _offlineMsg;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _loadFromApi();
  }

  Future<void> _loadFromApi() async {
    if (!mounted) return;
    setState(() { _apiLoading = true; _offlineMsg = null; });
    try {
      final data = await ApiService.invoices.getAll(status: _filter == 'ALL' ? null : _filter);
      if (!mounted) return;
      setState(() {
        _invoices
          ..clear()
          ..addAll(data.map((d) => _Invoice(d.id, d.fatooraNumber, d.companyName, d.invoiceDate, d.totalAmount, d.totalDiscount, d.paymentStatus)));
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() => _offlineMsg = e.isOffline ? 'Backend offline — showing cached data.' : 'Error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _offlineMsg = 'Failed to load: $e');
    } finally {
      if (mounted) setState(() => _apiLoading = false);
    }
  }

  Future<void> _handleMarkPaid(_Invoice inv) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updating invoice ${inv.number}...')));
    try {
      await ApiService.invoices.updatePaymentStatus(inv.id, 'PAID');
      if (!mounted) return;
      
      setState(() {
        final idx = _invoices.indexWhere((i) => i.id == inv.id);
        if (idx != -1) {
          _invoices[idx] = _Invoice(inv.id, inv.number, inv.company, inv.date, inv.total, inv.discount, 'PAID');
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice marked as PAID!'), backgroundColor: AC.greenFg));
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AC.redFg));
    }
  }

  Future<void> _handleViewItems(_Invoice inv) async {
    try {
      final fullInvoice = await ApiService.invoices.getById(inv.id);
      if (!mounted) return;
      showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
          backgroundColor: AC.white,
          title: Text('Items for ${inv.number}', style: const TextStyle(fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: fullInvoice.items.isEmpty 
                ? const Text('No items found on this invoice.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: fullInvoice.items.length,
                    itemBuilder: (context, i) {
                      final item = fullInvoice.items[i];
                      return ListTile(
                        title: Text(item['name'] ?? 'Unknown Medicine', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text('Qty: ${item['quantity']} | Unit Cost: EGP ${item['cost']}', style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load items: $e'), backgroundColor: AC.redFg));
    }
  }

  Future<void> _handleImportExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not read file'), backgroundColor: AC.redFg));
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importing ${file.name}...'), backgroundColor: AC.blue500));

      final response = await ApiService.invoices.importExcel(
        file.bytes!,
        file.name,
      );
      final itemsCount = response['items_count'] ?? 0;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Excel invoice imported! $itemsCount items added to inventory.'),
        backgroundColor: AC.greenFg,
      ));
      _loadFromApi();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import error: $e'), backgroundColor: AC.redFg));
    }
  }

  Future<void> _handleDelete(_Invoice inv) async {
    try {
      await ApiService.invoices.delete(inv.id);
      setState(() {
        _selected = null;
        _invoices.removeWhere((i) => i.id == inv.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice deleted'), backgroundColor: AC.greenFg));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e'), backgroundColor: AC.redFg));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final isWide = MediaQuery.of(context).size.width >= 700;
    return Column(
      children: [
        OfflineBanner(message: _offlineMsg, onRetry: _loadFromApi),
        if (_apiLoading) const LinearProgressIndicator(minHeight: 2),
        ScreenTopbar(
          title: 'Invoices',
          subtitle: 'invoices_fawateer · Fatoora scanner',
          actions: [
            
              Container(
                constraints: const BoxConstraints(maxWidth: 210), 
                height: 36,
                decoration: BoxDecoration(color: const Color(0xFFF3F6FA), borderRadius: AR.r10, border: Border.all(color: AC.border, width: 0.5)),
                child: Row(
                  children: [
                    const SizedBox(width: 10), const Icon(Icons.search_rounded, size: 15, color: AC.ink300), const SizedBox(width: 7),
                    Expanded(child: TextField(controller: _search, style: const TextStyle(fontSize: 12, color: AC.ink900), decoration: const InputDecoration(hintText: 'Search...', hintStyle: TextStyle(fontSize: 12, color: AC.ink300), border: InputBorder.none, isDense: true))),
                  ],
                ),
              
            ),
            const SizedBox(width: 10),
            appBtn(
              'Scan Invoice',
               bg: AC.blueLt,
               fg: AC.ink600,
              icon: Icons.document_scanner_rounded,
              onTap: () async {
                final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const InvoiceScannerScreen()));
                if (saved == true && mounted) _loadFromApi();
              },
            ),
            const SizedBox(width: 8),
            appBtn(
                  'Import Excel',
                  icon: Icons.upload_file_rounded,
                  bg: const Color(0xFFE8F5E9), 
                  fg: const Color(0xFF2E7D32), 
                  onTap:  _handleImportExcel,
                ),
                
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => showManualInvoiceDialog(context),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add manual', style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.blue500, 
                foregroundColor: AC.white, 
                elevation: 0, 
                shape: const RoundedRectangleBorder(borderRadius: AR.r10)
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 44, color: AC.white, 
          child: Row(
            children: [
              ..._statuses.map((s) {
                final active = _filter == s;
                return InkWell(
                  onTap: () => setState(() { _filter = s; _selected = null; }),
                  borderRadius: AR.pill,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? AC.blueLt : Colors.transparent, borderRadius: AR.pill,
                      border: Border.all(color: active ? AC.blue500.withOpacity(0.4) : Colors.transparent, width: 0.5),
                    ),
                    child: Text(s, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? AC.blue500 : AC.ink400)),
                  ),
                );
              }),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AC.page, borderRadius: AR.r8, border: Border.all(color: AC.border, width: 0.5)),
                child: Text('${rows.length} invoices', style: const TextStyle(fontSize: 11, color: AC.ink400)),
              ),
            ],
          ),
        ),
        appDivider(),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: rows.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_outlined, size: 48, color: AC.ink200),
                            SizedBox(height: 12),
                            Text('No invoices match your filter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AC.ink400)),
                          ],
                        ),
                      )
                    : ListView.separated(
                       padding: const EdgeInsets.all(16),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: rows.length,
                        itemBuilder: (_, i) => _InvoiceTile(
                          invoice: rows[i], selected: rows[i].id == _selected,
                          onTap: () => setState(() => _selected = _selected == rows[i].id ? null : rows[i].id),
                        ),
                      ),
              ),
              if (_selected != null && isWide)
                _InvoiceDetail(
                  invoice: _invoices.firstWhere((inv) => inv.id == _selected),
                  onClose: () => setState(() => _selected = null),
                  onMarkPaid: () => _handleMarkPaid(_invoices.firstWhere((inv) => inv.id == _selected)),
                  onViewItems: () => _handleViewItems(_invoices.firstWhere((inv) => inv.id == _selected)),
                  onDelete: () => _handleDelete(_invoices.firstWhere((inv) => inv.id == _selected)), 
                ),
            ],
          ),
        ),
        Container(
          height: 36, padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(color: AC.white, border: Border(top: BorderSide(color: AC.border, width: 0.5))),
          child: Row(
            children: [
              _footDot(AC.redFg, 'PENDING: EGP ${_invoices.where((i) => i.status == "PENDING").fold(0.0, (s, i) => s + i.netPayable).toStringAsFixed(0)}'), const SizedBox(width: 20),
              _footDot(AC.amberFg, 'PARTIAL: EGP ${_invoices.where((i) => i.status == "PARTIAL").fold(0.0, (s, i) => s + i.netPayable).toStringAsFixed(0)}'), const SizedBox(width: 20),
              _footDot(AC.greenFg, 'PAID: EGP ${_invoices.where((i) => i.status == "PAID").fold(0.0, (s, i) => s + i.total).toStringAsFixed(0)}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footDot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 10, color: AC.ink400))]);
}

class _Invoice {
  final int id;
  final String number, company, date, status;
  final double total, discount;
  double get netPayable => total - discount;
  const _Invoice(this.id, this.number, this.company, this.date, this.total, this.discount, this.status);
}

class _InvoiceTile extends StatelessWidget {
  final _Invoice invoice;
  final bool selected;
  final VoidCallback onTap;
  const _InvoiceTile({required this.invoice, required this.selected, required this.onTap});

  static Color _sfg(String s) => s == 'PAID' ? AC.greenFg : s == 'PARTIAL' ? AC.amberFg : AC.redFg;
  static Color _sbg(String s) => s == 'PAID' ? AC.greenBg : s == 'PARTIAL' ? AC.amberBg : AC.redBg;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: selected ? AC.blueXlt : AC.white, borderRadius: AR.r12, border: Border.all(color: selected ? AC.blue500 : AC.border, width: selected ? 1.5 : 0.5), boxShadow: AS.card),
        child: Row(
          children: [
            Container(width: 40, height: 40, decoration: const BoxDecoration(color: AC.blueXlt, borderRadius: AR.r10), child: const Icon(Icons.receipt_outlined, color: AC.blue500, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invoice.number, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.ink900)),
                  const SizedBox(height: 2),
                  Text('${invoice.company} · ${invoice.date}', style: const TextStyle(fontSize: 11, color: AC.ink300)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('EGP ${invoice.netPayable.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.ink900)),
                const SizedBox(height: 4),
                appBadge(invoice.status, _sfg(invoice.status), _sbg(invoice.status)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceDetail extends StatelessWidget {
  final _Invoice invoice;
  final VoidCallback onClose, onMarkPaid, onViewItems, onDelete;
  
  const _InvoiceDetail({
    required this.invoice, 
    required this.onClose, 
    required this.onMarkPaid, 
    required this.onViewItems,
    required this.onDelete, 
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(color: AC.white, border: Border(left: BorderSide(color: AC.border, width: 0.5))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: Text(invoice.number, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.ink900))),
                GestureDetector(onTap: onClose, child: const Icon(Icons.close_rounded, color: AC.ink300, size: 18)),
              ],
            ),
          ),
          appDivider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Company', invoice.company),
                  _detailRow('Date', invoice.date),
                  _detailRow('Total', 'EGP ${invoice.total.toStringAsFixed(2)}'),
                  _detailRow('Discount', 'EGP ${invoice.discount.toStringAsFixed(2)}'),
                  _detailRow('Net payable', 'EGP ${invoice.netPayable.toStringAsFixed(2)}', valueColor: AC.blue500),
                  _detailRow('Status', invoice.status, valueColor: invoice.status == 'PAID' ? AC.greenFg : null),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: appBtn(
                    'View line items',
                    icon: Icons.list_alt_rounded,
                    bg: AC.blue500,
                    onTap: onViewItems, 
                  ),
                ),
                 const SizedBox(height: 8),
                if (invoice.status != 'PAID') ...[
                  SizedBox(
                    width: double.infinity,
                    child: appBtn(
                      'Mark as paid',
                      icon: Icons.check_circle_outline_rounded,
                      bg: AC.greenBg,
                    fg: AC.greenFg,
                      onTap: onMarkPaid, 
                    ),
                  ),
                 
                ],
                
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: appBtn(
                    'Delete invoice',
                    icon: Icons.delete_outline_rounded,
                    bg: AC.redBg,
                    fg: AC.redFg,
                    onTap: onDelete, 
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String val, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 11, color: AC.ink300))),
        Expanded(child: Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor ?? AC.ink600))),
      ],
    ),
  );
}