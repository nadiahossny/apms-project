import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../services/api_service.dart';
import '../widgets/shared_widgets.dart';

class OperationalReportsScreen extends StatefulWidget {
  const OperationalReportsScreen({super.key});

  @override
  State<OperationalReportsScreen> createState() => _OperationalReportsState();
}

class _OperationalReportsState extends State<OperationalReportsScreen> {
  bool _loading = true;
  String? _error;
  AnalyticsDto? _analytics;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.reports.getAnalytics();
      if (mounted) setState(() => _analytics = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.page,
      body: Column(
        children: [
          ScreenTopbar(
            title: 'Operational Reports',
            subtitle: 'Standard business metrics (Rolling 365 Days)',
            actions: [
              appBtn('Refresh Data', icon: Icons.refresh_rounded, bg: AC.blueLt, fg: AC.blue500, onTap: _loadData)
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AC.blue500))
                : _error != null
                    ? Center(child: Text('Failed to load reports: $_error', style: const TextStyle(color: AC.redFg)))
                    : _buildDashboard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    if (_analytics == null) return const SizedBox();
    
    final double width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width > 1200 ? 4 : width > 800 ? 2 : 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. RIGID, RESPONSIVE KPI GRID (Crash fixed) ───
          GridView.count(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.8, // 🌟 FIXED: Gives cards more height so they never crash!
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _KpiCard(title: 'TOTAL REVENUE', value: 'EGP ${_analytics!.totalRevenue.toStringAsFixed(0)}', icon: Icons.account_balance_wallet_rounded, color: AC.blue500),
              _KpiCard(title: 'NET PROFIT', value: 'EGP ${_analytics!.totalProfit.toStringAsFixed(0)}', icon: Icons.trending_up_rounded, color: AC.greenFg),
              _KpiCard(title: 'UNITS DISPENSED', value: '${_analytics!.unitsDispensed}', icon: Icons.medication_rounded, color: AC.amberFg),
              _KpiCard(title: 'WASTE VALUE', value: 'EGP ${_analytics!.wasteValue.toStringAsFixed(0)}', icon: Icons.delete_outline_rounded, color: AC.redFg),
            ],
          ),
          const SizedBox(height: 32),

          // ─── 2. CLEAN LIST COLUMNS ───
          if (width > 900)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildLeftColumn()),
                const SizedBox(width: 24),
                Expanded(child: _buildRightColumn()),
              ],
            )
          else
            Column(
              children: [
                _buildLeftColumn(),
                const SizedBox(height: 24),
                _buildRightColumn(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      children: [
        _buildListCard('Top Performing Medicines', _analytics!.topMedicines, (item) => _ListRow(title: item['name'], subtitle: '${item['units']} units sold', trailing: 'EGP ${item['revenue']}', color: AC.greenFg)),
        const SizedBox(height: 24),
        _buildListCard('Most Frequently Requested', _analytics!.mostPrescribed, (item) => _ListRow(title: item['name'], subtitle: 'Frequent prescription/walk-in', trailing: '${item['prescription_count']} reqs', color: AC.blue500)),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      children: [
        _buildListCard('Top Suppliers (Spend)', _analytics!.topSuppliers, (item) => _ListRow(title: item['name'], subtitle: 'Total purchasing spend', trailing: 'EGP ${item['spend']}', color: AC.ink900)),
        const SizedBox(height: 24),
        _buildListCard('Immediate Expiry Risk (60 Days)', _analytics!.expiryRisk, (item) => _ListRow(title: item['name'], subtitle: '${item['qty']} units expiring in ${item['days']} days', trailing: 'EGP ${item['value']} Risk', color: AC.redFg)),
      ],
    );
  }

  Widget _buildListCard(String title, List<dynamic> items, Widget Function(dynamic) builder) {
    return Container(
      decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border), boxShadow: AS.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AC.page, width: 2))),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AC.ink900)),
          ),
          if (items.isEmpty)
             const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No data available in this period.', style: TextStyle(color: AC.ink400)))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: items.map(builder).toList()),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;

  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16), // 🌟 Reduced padding slightly
      decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border), boxShadow: AS.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 🌟 Safe spacing, no Spacer() needed!
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: AR.r8), child: Icon(icon, color: color, size: 20)),
              const Spacer(),
              // const Icon(Icons.more_horiz_rounded, color: AC.ink300, size: 20),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AC.ink400, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AC.ink900))),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final String title, subtitle, trailing;
  final Color color;

  const _ListRow({required this.title, required this.subtitle, required this.trailing, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: AR.r10, border: Border.all(color: AC.border, width: 0.5)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AC.ink900), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AC.ink400), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: AR.pill),
            child: Text(trailing, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: color)),
          ),
        ],
      ),
    );
  }
}