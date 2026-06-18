import 'dart:async';
import 'package:apms/widgets/manual_rx_dialog.dart';
import 'package:apms/widgets/medicine_linker_sheet.dart';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../services/api_service.dart';
import '../widgets/shared_widgets.dart';
import '../rx_scanner_screen.dart';

class PrescriptionsScreen extends StatefulWidget {
  const PrescriptionsScreen({super.key});
  @override
  State<PrescriptionsScreen> createState() => _RxState();
}

class _Rx {
  final int id;
  final String code, patient, doctor, status, date;
  final List<PrescriptionItemDto> items;
  const _Rx(
    this.id,
    this.code,
    this.patient,
    this.doctor,
    this.status,
    this.date,
    this.items,
  );
}

class _RxState extends State<PrescriptionsScreen> {
  int? _selected;
  String _filter = 'ALL';
  bool _apiLoading = false;
  int? _processingId;

  final _rxList = <_Rx>[];
  List<_Rx> get _filtered =>
      _rxList.where((r) => _filter == 'ALL' || r.status == _filter).toList();

  String? _offlineMsg;

  @override
  void initState() {
    super.initState();
    _loadRx();
  }

  Future<void> _handleDelete(int id) async {
    try {
      await ApiService.prescriptions.delete(id);
      setState(() => _selected = null);
      _loadRx(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription deleted'),
          backgroundColor: AC.greenFg,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting: $e'),
          backgroundColor: AC.redFg,
        ),
      );
    }
  }

  Future<void> _loadRx() async {
    if (!mounted) return;
    setState(() {
      _apiLoading = true;
      _offlineMsg = null;
    });
    try {
      final data = await ApiService.prescriptions.getAll(
        status: _filter == 'ALL' ? null : _filter,
      );
      if (!mounted) return;
      setState(() {
        _rxList
          ..clear()
          ..addAll(
            data.map(
              (p) => _Rx(
                p.id,
                p.roshettaCode ?? 'RX-${p.id}',
                p.patientName ?? 'Unknown',
                p.doctorName ?? 'Unknown',
                p.status,
                p.createdAt.split('T').first,
                p.items,
              ),
            ),
          );
      });
    } on NetworkException catch (e) {
      if (!mounted) return;
      setState(() {
        _offlineMsg = e.isOffline
            ? 'Backend offline — showing cached data. Tap Retry to reconnect.'
            : 'Error: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _offlineMsg = 'Failed to load: $e';
      });
    } finally {
      if (mounted) setState(() => _apiLoading = false);
    }
  }

  Future<void> _dispatchRobot(int prescriptionId) async {
    if (!mounted) return;
    setState(() => _processingId = prescriptionId);

    try {
      await ApiService.robot.dispatch(prescriptionId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job dispatched to robot!'),
          backgroundColor: AC.tealFg,
        ),
      );

      await ApiService.prescriptions.updateStatus(
        prescriptionId,
        'PARTIALLY_DISPENSED',
      );

      _loadRx();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to dispatch: $e'),
          backgroundColor: AC.redFg,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Future<void> _markComplete(int prescriptionId) async {
    if (!mounted) return;
    setState(() => _processingId = prescriptionId);
    try {
      await ApiService.prescriptions.checkout(prescriptionId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription checked out and inventory updated!'),
          backgroundColor: AC.greenFg,
        ),
      );
      setState(() => _selected = null);
      _loadRx();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: AC.redFg,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  static Color _sfg(String s) => s == 'COMPLETE'
      ? AC.greenFg
      : s == 'PENDING'
      ? AC.amberFg
      : s == 'PARTIALLY_DISPENSED'
      ? AC.blue500
      : s == 'CANCELLED'
      ? AC.redFg
      : AC.blue500;

  static Color _sbg(String s) => s == 'COMPLETE'
      ? AC.greenBg
      : s == 'PENDING'
      ? AC.amberBg
      : s == 'PARTIALLY_DISPENSED'
      ? AC.blueLt
      : s == 'CANCELLED'
      ? AC.redBg
      : AC.blueLt;

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    return Column(
      children: [
        OfflineBanner(message: _offlineMsg, onRetry: _loadRx),
        if (_apiLoading) const LinearProgressIndicator(minHeight: 2),
        ScreenTopbar(
          title: 'Prescriptions',
          subtitle:
              'prescriptions_roshetta · ${_rxList.where((r) => r.status == "PENDING").length} pending',
          actions: [
            appBtn(
              'Scan Prescription',
              bg: AC.blueLt,
              fg: AC.ink600,
              icon: Icons.document_scanner_rounded,
              onTap: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const RxScannerScreen()),
                );
                if (saved == true) _loadRx();
              },
            ),
            // ADD THIS NEW BUTTON:
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                showManualRxDialog(context).then((created) {
                  if (created == true)
                    _loadRx(); // Refresh list if a new prescription was created
                });
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'Add manual',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.blue500,
                foregroundColor: AC.white,
                elevation: 0,
                shape: const RoundedRectangleBorder(borderRadius: AR.r10),
              ),
            ),
          ],
        ),
        // Filter
        Container(
          height: 44,
          color: AC.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final s in ['ALL', 'PENDING', 'COMPLETE', 'CANCELLED'])
                InkWell(
                  onTap: () => setState(() {
                    _filter = s;
                    _selected = null;
                  }),
                  borderRadius: AR.pill,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _filter == s ? AC.blueLt : Colors.transparent,
                      borderRadius: AR.pill,
                      border: Border.all(
                        color: _filter == s
                            ? AC.blue500.withAlpha((0.4 * 255).toInt())
                            : Colors.transparent,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _filter == s
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: _filter == s ? AC.blue500 : AC.ink400,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        appDivider(),
        Expanded(
          child: Row(
            children: [
              // List (with empty state)
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 52,
                              color: AC.ink200,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _filter == 'ALL'
                                  ? 'No prescriptions yet'
                                  : 'No ${_filter.toLowerCase()} prescriptions',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AC.ink400,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: rows.length,
                        itemBuilder: (_, i) {
                          final rx = rows[i];
                          final sel = rx.id == _selected;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selected = sel ? null : rx.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: sel ? AC.blueXlt : AC.white,
                                borderRadius: AR.r12,
                                border: Border.all(
                                  color: sel ? AC.blue500 : AC.border,
                                  width: sel ? 1.5 : 0.5,
                                ),
                                boxShadow: AS.card,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _sbg(rx.status),
                                      borderRadius: AR.r10,
                                    ),
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      color: _sfg(rx.status),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          rx.code,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AC.ink900,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${rx.patient} · ${rx.doctor}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AC.ink300,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          rx.date,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AC.ink300,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      appBadge(
                                        rx.status,
                                        _sfg(rx.status),
                                        _sbg(rx.status),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${rx.items.length} items',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AC.ink400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_selected != null && _rxList.any((r) => r.id == _selected))
                _RxDetailPanel(
                  rx: _rxList.firstWhere((r) => r.id == _selected),
                  isProcessing: _processingId == _selected,
                  onClose: () => setState(() => _selected = null),
                  onDispatch: () => _dispatchRobot(_selected!),
                  onMarkComplete: () => _markComplete(_selected!),
                  onRefresh: _loadRx,
                  // FIX: Pass the onDelete callback down here
                  onDelete: () => _handleDelete(_selected!),
                ),
            ],
          ),
        ),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: AC.white,
            border: Border(top: BorderSide(color: AC.border, width: 0.5)),
          ),
          child: Row(
            children: [
              _footDot(
                AC.amberFg,
                'PENDING: ${_rxList.where((r) => r.status == "PENDING").length}',
              ),
              const SizedBox(width: 20),
              _footDot(
                AC.blue500,
                'PARTIAL: ${_rxList.where((r) => r.status == "PARTIALLY_DISPENSED").length}',
              ),
              const SizedBox(width: 20),
              _footDot(
                AC.greenFg,
                'COMPLETE: ${_rxList.where((r) => r.status == "COMPLETE").length}',
              ),
              const Spacer(),
              Text(
                'Total: ${_rxList.length} prescriptions',
                style: const TextStyle(
                  fontSize: 11,
                  color: AC.ink400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footDot(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: AC.ink400,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _RxDetailPanel extends StatelessWidget {
  final _Rx rx;
  final bool isProcessing;
  final VoidCallback onClose, onDispatch, onMarkComplete, onRefresh, onDelete;

  const _RxDetailPanel({
    required this.rx,
    required this.isProcessing,
    required this.onClose,
    required this.onDispatch,
    required this.onMarkComplete,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasUnlinked = rx.items.any((i) => i.medicineId == 0);
    final bool canDispatch =
        !hasUnlinked &&
        (rx.status == 'PENDING' || rx.status == 'PARTIALLY_DISPENSED');

    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: AC.white,
        border: Border(left: BorderSide(color: AC.border, width: 0.5)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rx.code,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AC.ink900,
                        ),
                      ),
                      Text(
                        rx.patient,
                        style: const TextStyle(fontSize: 11, color: AC.ink300),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(
                    Icons.close_rounded,
                    color: AC.ink300,
                    size: 18,
                  ),
                ),
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
                  _r('Doctor', rx.doctor),
                  _r('Date', rx.date),
                  _r('Status', rx.status),
                  _r('Items', '${rx.items.length} medicines'),
                  const SizedBox(height: 16),
                  const Text(
                    'ITEMS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AC.ink300,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...rx.items.map((item) {
                    final isUnlinked = item.medicineId == 0;
                    final displayName = isUnlinked
                        ? (item.requestedName.isNotEmpty
                              ? item.requestedName
                              : 'Unknown Scanned Item')
                        : item.tradeName;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUnlinked ? AC.amberBg : AC.page,
                        borderRadius: AR.r8,
                        border: Border.all(
                          color: isUnlinked ? AC.amberRing : AC.border,
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isUnlinked) ...[
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 14,
                                        color: AC.amberFg,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isUnlinked
                                              ? AC.amberFg
                                              : AC.ink900,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Qty: ${item.quantityPrescribed}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AC.ink400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isUnlinked && rx.status != 'COMPLETE')
                            ElevatedButton(
                              onPressed: () async {
                                final success = await MedicineLinkerSheet.show(
                                  context,
                                  item.id,
                                  displayName,
                                );
                                if (success == true) onRefresh();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AC.amberFg,
                                foregroundColor: AC.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                minimumSize: const Size(0, 26),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: AR.r8,
                                ),
                              ),
                              child: const Text(
                                'Link',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (hasUnlinked && rx.status != 'COMPLETE') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AC.redBg,
                      borderRadius: AR.r10,
                      border: Border.all(color: AC.redRing, width: 0.5),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: AC.redFg,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cannot dispatch until all items are linked to inventory.',
                            style: TextStyle(fontSize: 11, color: AC.redFg),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // --- NEW BUTTONS START HERE ---
                if (rx.status != 'COMPLETE') ...[
                  SizedBox(
                    width: double.infinity,
                    child: appBtn(
                      isProcessing ? 'Dispatching...' : 'Dispatch robot',
                      icon: isProcessing
                          ? null
                          : Icons.precision_manufacturing_rounded,
                      bg: AC.blue500,
                      onTap: (!canDispatch || isProcessing) ? null : onDispatch,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: appBtn(
                      'Mark complete',
                      icon: Icons.check_circle_outline_rounded,
                      bg: AC.greenBg,
                      fg: AC.greenFg,
                      onTap: isProcessing ? null : onMarkComplete,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: appBtn(
                    'Delete prescription',
                    icon: Icons.delete_outline_rounded,
                    bg: AC.redBg,
                    fg: AC.redFg,
                    onTap: isProcessing ? null : onDelete,
                  ),
                ),

                // --- NEW BUTTONS END HERE ---
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _r(String l, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            l,
            style: const TextStyle(fontSize: 11, color: AC.ink300),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AC.ink600,
            ),
          ),
        ),
      ],
    ),
  );
}
