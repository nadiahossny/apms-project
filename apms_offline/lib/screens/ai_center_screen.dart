import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../services/api_service.dart';
import '../widgets/shared_widgets.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});
  @override
  State<AIScreen> createState() => _AIstate();
}

class _AIstate extends State<AIScreen> {
  final List<String> _tabs = [
    'Overview',
    'Market Demand',
    'Expiry Risk',
    'Clearance Promos',
    'Dead Stock',
    'Integrity Audit',
  ];
  String _activeTab = 'Overview';

  Map<String, dynamic>? _salesTrend;
  Map<String, dynamic>? _categoryData;
  Map<String, dynamic>? _supplierData;
  Map<String, dynamic>? _anomalies;
  Map<String, dynamic>? _discounts;
  Map<String, dynamic>? _expiryTimeline;
  Map<String, dynamic>? _deadStockData;
  Map<String, dynamic>? _demandForecast;
  Map<String, dynamic>? _smartReorder;

  @override
  void initState() {
    super.initState();
    _loadTabData(_activeTab);
  }

  Future<Map<String, dynamic>> _safeFetch(Future<Map<String, dynamic>> Function() fetcher) async {
    try { return await fetcher(); } catch (e) { return {}; }
  }

  void _loadTabData(String tab) {
    if (tab == 'Overview' && _salesTrend == null) {
      _safeFetch(() => ApiService.gAi.getSalesTrend()).then((res) { if (mounted) setState(() => _salesTrend = res); });
      _safeFetch(() => ApiService.gAi.getCategoryDistribution()).then((res) { if (mounted) setState(() => _categoryData = res); });
      _safeFetch(() => ApiService.gAi.getSupplierDistribution()).then((res) { if (mounted) setState(() => _supplierData = res); });
    } else if (tab == 'Market Demand' && _smartReorder == null) {
      _safeFetch(() => ApiService.gAi.getDemandForecast()).then((res) { if (mounted) setState(() => _demandForecast = res); });
      _safeFetch(() => ApiService.gAi.getSmartReorder()).then((res) { if (mounted) setState(() => _smartReorder = res); });
    } else if (tab == 'Expiry Risk' && _expiryTimeline == null) {
      _safeFetch(() => ApiService.gAi.getExpiryTimeline()).then((res) { if (mounted) setState(() => _expiryTimeline = res); });
      _safeFetch(() => ApiService.gAi.getSuggestDiscounts()).then((res) { if (mounted) setState(() => _discounts = res); });
    } else if (tab == 'Clearance Promos' && _discounts == null) {
      _safeFetch(() => ApiService.gAi.getSuggestDiscounts()).then((res) { if (mounted) setState(() => _discounts = res); });
    } else if (tab == 'Dead Stock' && _deadStockData == null) {
      _safeFetch(() => ApiService.gAi.getDeadStock()).then((res) { if (mounted) setState(() => _deadStockData = res); });
    } else if (tab == 'Integrity Audit' && _anomalies == null) {
      _safeFetch(() => ApiService.gAi.getAnomalies()).then((res) { if (mounted) setState(() => _anomalies = res); });
    }
  }

  void _forceRefreshAll() {
    setState(() {
      _salesTrend = null;
      _categoryData = null;
      _supplierData = null;
      _anomalies = null;
      _discounts = null;
      _expiryTimeline = null;
      _deadStockData = null;
      _demandForecast = null;
      _smartReorder = null;
    });
    _loadTabData(_activeTab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.page,
      body: Column(
        children: [
          ScreenTopbar(
            title: 'AI Command Center',
            subtitle: 'Advanced historical predictive models',
            actions: [appBtn('Refresh Models', icon: Icons.refresh_rounded, bg: AC.blueLt, fg: AC.blue500, onTap: _forceRefreshAll)],
          ),
          _buildPillFilters(),
          appDivider(),
          Expanded(child: _buildActiveTabContent()),
        ],
      ),
    );
  }

  Widget _buildPillFilters() {
    return Container(
      height: 52,
      color: AC.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _tabs.map((t) {
          final active = _activeTab == t;
          return Padding(
            padding: const EdgeInsets.only(right: 6, top: 10, bottom: 10),
            child: InkWell(
              onTap: () {
                setState(() => _activeTab = t);
                _loadTabData(t);
              },
              borderRadius: AR.pill,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? AC.blueLt : Colors.transparent,
                  borderRadius: AR.pill,
                  border: Border.all(color: active ? AC.blue500.withOpacity(0.4) : Colors.transparent, width: 0.5),
                ),
                child: Center(
                  child: Text(t, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? AC.blue500 : AC.ink400)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 🌟 FIX: Show a clean, centered loading spinner for the ENTIRE tab if data is missing
  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 'Overview':
        if (_salesTrend == null || _categoryData == null) return const Center(child: CircularProgressIndicator(color: AC.blue500));
        return _buildOverviewTab();
      case 'Market Demand':
        if (_demandForecast == null || _smartReorder == null) return const Center(child: CircularProgressIndicator(color: AC.blue500));
        return _buildInsightsTab();
      case 'Expiry Risk':
        if (_expiryTimeline == null || _discounts == null) return const Center(child: CircularProgressIndicator(color: AC.blue500));
        return _buildExpiryRiskTab();
      case 'Clearance Promos':
        if (_discounts == null) return const Center(child: CircularProgressIndicator(color: AC.blue500));
        return _buildPromosTab();
      case 'Dead Stock':
        if (_deadStockData == null) return const Center(child: CircularProgressIndicator(color: AC.blue500));
        return _buildDeadStockTab();
      case 'Integrity Audit':
        if (_anomalies == null) return const Center(child: CircularProgressIndicator(color: AC.blue500));
        return _buildAuditTab();
      default: return const SizedBox();
    }
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildLineChart(title: 'Monthly Demand Trend', subtitle: 'AI Demand Insights', data: _salesTrend, lineColor: AC.blue500),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildPieChart('Category Health Matrix', _categoryData, [AC.blue500, AC.tealFg, AC.amberFg, AC.darkBlue, AC.redFg])),
            const SizedBox(width: 24),
            Expanded(child: _buildPieChart('Top Suppliers', _supplierData, [AC.amberFg, AC.greenFg, AC.blueLt, AC.ink400, AC.redRing])),
          ],
        ),
      ],
    );
  }

  Widget _buildInsightsTab() {
    final smartReorder = _smartReorder?['reorder_products'] as List<dynamic>? ?? [];
    final topDemanded = _demandForecast?['top_demanded'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: AC.blueLt, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome, color: AC.blue500, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Market Demand Intelligence (XGBoost)', style: TextStyle(fontSize: 12, color: AC.ink400, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${(_demandForecast?['forecast_total'] as num?)?.toInt() ?? 0} Units Expected Next Month', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AC.ink900)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        const Text('Top 5 Demanded Medicines', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AC.ink900)),
        const SizedBox(height: 16),
        _buildBarChart(topDemanded.take(5).toList(), AC.blue500),
        const SizedBox(height: 32),

        const Text('Smart Reorder Engine (Q-Learning Logic)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AC.ink900)),
        const SizedBox(height: 16),
        if (smartReorder.isEmpty)
          const Text('Stock levels are optimal. No reorders needed.', style: TextStyle(color: AC.ink400))
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: smartReorder.map((p) => Container(
                    width: 300,
                    decoration: BoxDecoration(
                      color: AC.white,
                      borderRadius: AR.r10,
                      border: Border.all(color: AC.border, width: 0.5),
                      boxShadow: AS.card,
                    ),
                    child: ClipRRect(
                      borderRadius: AR.r10,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(width: 4, color: AC.amberFg), 
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p['product'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AC.blue500)),
                                    const SizedBox(height: 4),
                                    Text('Stock: ${p['current_stock']} | Velocity: ${p['avg_monthly']}/mo', style: const TextStyle(fontSize: 12, color: AC.ink400)),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${p['days_left']} Days Left', style: const TextStyle(fontWeight: FontWeight.bold, color: AC.redFg, fontSize: 12)),
                                        appBadge('REORDER: ${p['reorder_point']}', AC.ink900, AC.amberBg),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).toList(),
          ),
      ],
    );
  }

  Widget _buildExpiryRiskTab() {
    final expired = _discounts?['expired_list'] as List<dynamic>? ?? [];
    final expiring = _discounts?['expiring_list'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildLineChart(title: 'Inventory Expiry Timeline', subtitle: 'Projected financial loss if stock expires', data: _expiryTimeline, lineColor: AC.redFg),
        const SizedBox(height: 32),

        if (expired.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: AC.white, borderRadius: AR.r10, border: Border(top: BorderSide(color: AC.redFg, width: 4)), boxShadow: AS.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('EXPIRED ITEMS - REMOVE IMMEDIATELY', style: TextStyle(color: AC.redFg, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...expired.map((p) => _buildListItem(p['Product Name'], 'Value Lost: ${p['Total Inventory Value']} EGP', 'EXPIRED', AC.redFg)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        const Text('Near-Expiry Product List', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AC.ink900)),
        const SizedBox(height: 12),
        if (expiring.isEmpty)
          const Text('No near-expiry products.', style: TextStyle(color: AC.ink400))
        else
          ...expiring.map((p) => _buildListItem(p['Product Name'], 'Expires in: ${p['Days']} days', '${p['Lost_Value']} EGP', AC.amberFg)),
      ],
    );
  }

  Widget _buildPromosTab() {
    final discounts = _discounts?['promo_products'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('AI Clearance Recommendations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AC.ink900)),
        const SizedBox(height: 12),
        if (discounts.isEmpty)
          const Text('No products require discounts.', style: TextStyle(color: AC.ink400)),
        ...discounts.map((d) => _buildListItem(d['Product Name'], 'Expires in ${d['Days']} days', 'SAVE ${d['discount']}%', AC.greenFg)),
      ],
    );
  }

  Widget _buildDeadStockTab() {
    final deadStock = _deadStockData?['data'] as List<dynamic>? ?? [];

    if (deadStock.isEmpty) {
      return const Center(child: Text('Inventory is clean. No dead stock found.', style: TextStyle(color: AC.ink400)));
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Non-Moving Inventory (Dead Stock)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AC.ink900)),
        const SizedBox(height: 12),
        ...deadStock.map((item) => _buildListItem(item['Product Name'] ?? 'Unknown', 'Category: ${item['Category'] ?? 'N/A'}', 'Qty: ${item['Quantity']} | ${item['Stock_Value']} EGP', AC.ink400)),
      ],
    );
  }

  Widget _buildAuditTab() {
    final anomalies = _anomalies?['anomalies'] as List<dynamic>? ?? [];

    if (anomalies.isEmpty) {
      return const Center(child: Text('No anomalies detected by AI.', style: TextStyle(color: AC.ink400)));
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('AI Integrity Audit (Autoencoder)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AC.ink900)),
        const SizedBox(height: 16),
        ...anomalies.map((a) {
          final diff = (a['Difference'] as num?)?.toDouble() ?? 0.0;
          final isSevere = diff.abs() > 300;
          String rawDate = a['Start Date']?.toString() ?? '';
          String displayDate = rawDate.contains('T') ? rawDate.split('T')[0] : rawDate;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AC.white, borderRadius: AR.r10, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isSevere ? AC.redBg : AC.tealBg, shape: BoxShape.circle),
                  child: Icon(isSevere ? Icons.warning_rounded : Icons.info_outline_rounded, color: isSevere ? AC.redFg : AC.tealFg, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a['Shift_Name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, color: AC.ink900)),
                      Text(displayDate, style: const TextStyle(fontSize: 12, color: AC.ink400)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${diff > 0 ? '+' : ''}$diff EGP', style: TextStyle(fontWeight: FontWeight.w800, color: diff < 0 ? AC.redFg : AC.greenFg)),
                    if (isSevere) appBadge('CHECK NOW', AC.white, AC.redFg),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // REUSABLE UI COMPONENTS (Themed Properly)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildListItem(String title, String subtitle, String trailing, Color badgeColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.white, borderRadius: AR.r8, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AC.ink400)),
              ],
            ),
          ),
          appBadge(trailing, AC.white, badgeColor),
        ],
      ),
    );
  }

  Widget _buildLineChart({required String title, required String subtitle, required Map<String, dynamic>? data, required Color lineColor}) {
    final months = (data?['months'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final values = (data?['values'] as List<dynamic>? ?? []).map((e) => double.tryParse(e.toString()) ?? 0.0).toList();
    final allZero = values.every((e) => e == 0.0);

    if (months.isEmpty || allZero) {
      return Container(
        height: 350,
        decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
        child: const Center(child: Text("No historical data available", style: TextStyle(color: AC.ink400))),
      );
    }

    List<FlSpot> spots = [];
    double maxY = 0;
    for (int i = 0; i < values.length; i++) {
      if (values[i] > maxY) maxY = values[i];
      spots.add(FlSpot(i.toDouble(), values[i]));
    }
    double calculatedInterval = maxY > 0 ? math.max(1.0, (maxY / 5).ceilToDouble()) : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AC.ink900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: AC.ink400)),
        const SizedBox(height: 16),
        Container(
          height: 350,
          padding: const EdgeInsets.only(top: 24, bottom: 12, left: 12, right: 12),
          decoration: BoxDecoration(color: AC.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY * 1.2,
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: AC.ink400.withOpacity(0.1), strokeWidth: 1, dashArray: [5, 5])),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    interval: calculatedInterval,
                    getTitlesWidget: (val, meta) {
                      if (val == maxY * 1.2) return const Text('');
                      String text = val.toInt().toString();
                      if (val >= 1000) text = '${(val / 1000).toStringAsFixed(1)}k';
                      return Text(text, style: const TextStyle(fontSize: 10, color: AC.ink400));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: math.max(1, (months.length / 6).floorToDouble()),
                    getTitlesWidget: (val, meta) {
                      int idx = val.toInt();
                      if (idx >= 0 && idx < months.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(months[idx].toString().split(' ')[0], style: const TextStyle(fontSize: 10, color: AC.ink400)),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: lineColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: Colors.white, strokeWidth: 2, strokeColor: lineColor)),
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [lineColor.withOpacity(0.2), lineColor.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(List<dynamic> items, Color barColor) {
    final parsedItems = items.map((item) => {
      'name': item['name']?.toString() ?? 'Unknown',
      'units': double.tryParse(item['units']?.toString() ?? '0') ?? 0.0,
    }).toList();
    
    // 🌟 FIX: Check if all values are 0.0 to prevent the empty grid!
    final allZero = parsedItems.every((e) => (e['units'] as double) == 0.0);

    if (parsedItems.isEmpty || allZero) {
      return Container(
        height: 350,
        decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
        child: const Center(child: Text("No historical data available", style: TextStyle(color: AC.ink400))),
      );
    }

    double maxY = 0;
    for (var p in parsedItems) {
      if ((p['units'] as double) > maxY) maxY = p['units'] as double;
    }
    double calculatedInterval = maxY > 0 ? math.max(1.0, (maxY / 5).ceilToDouble()) : 1.0;

    return Container(
      height: 350,
      padding: const EdgeInsets.only(top: 24, bottom: 12, right: 12, left: 12),
      decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2,
          barTouchData: const BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (val, meta) {
                  int idx = val.toInt();
                  if (idx >= 0 && idx < parsedItems.length) {
                    String name = parsedItems[idx]['name'].toString();
                    if (name.length > 10) name = '${name.substring(0, 8)}..';
                    return Padding(padding: const EdgeInsets.only(top: 8), child: Text(name, style: const TextStyle(color: AC.ink400, fontSize: 9, fontWeight: FontWeight.bold)));
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: calculatedInterval,
                getTitlesWidget: (val, meta) {
                  if (val == maxY * 1.2) return const Text('');
                  String text = val.toInt().toString();
                  if (val >= 1000) text = '${(val / 1000).toStringAsFixed(1)}k';
                  return Text(text, style: const TextStyle(fontSize: 10, color: AC.ink400));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(parsedItems.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: parsedItems[i]['units'] as double, color: barColor, width: 28, borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildPieChart(String title, Map<String, dynamic>? data, List<Color> colors) {
    final labels = (data?['categories'] ?? data?['suppliers'] ?? []).map((e) => e.toString()).toList();
    final values = (data?['values'] as List<dynamic>? ?? []).map((e) => double.tryParse(e.toString()) ?? 0.0).toList();
    final allZero = values.every((e) => e == 0.0);

    if (labels.isEmpty || values.isEmpty || allZero) {
      return Container(
        height: 250,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
        child: const Center(child: Text("No historical data available", style: TextStyle(color: AC.ink400))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AC.ink900)),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 35,
                      sections: List.generate(
                        labels.length,
                        (i) => PieChartSectionData(color: colors[i % colors.length], value: values[i], title: '', radius: 25),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: ListView.builder(
                    itemCount: labels.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(labels[i], style: const TextStyle(fontSize: 11, color: AC.ink600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
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
}