import 'dart:async';
import 'package:apms/rx_scanner_screen.dart';
import 'package:apms/widgets/shared_widgets.dart';
import 'package:apms/screens/ai_chatbot_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:apms/widgets/DashboardKpiRow.dart';
import 'dart:math' as math;
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'theme/tokens.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});
  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _dbLoaded = false;
  String? _offlineMsg;
  DashboardMetricsDto? _dbData;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDataFast();
  }

  Future<void> _loadDataFast() async {
    setState(() { _dbLoaded = false; _offlineMsg = null; });
    try {
      final dbDataRaw = await ApiService.reports.getDashboardMetrics();
      final pendingRx = await ApiService.getPendingPrescriptions();
      
      if (mounted) {
        setState(() {
          _dbData = dbDataRaw;
          _pendingCount = pendingRx.length;
          _dbLoaded = true;
        });
      }
    } on NetworkException catch (e) {
      if (mounted) setState(() {
        _offlineMsg = e.isOffline ? 'Backend offline — showing cached data.' : 'Connection error: ${e.message}';
        _dbLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _dbLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;
        final isTablet = constraints.maxWidth >= 600;
        return Scaffold(
          backgroundColor: AC.page,
          body: Column(
            children: [
              if (!_dbLoaded) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: _DashboardBody(
                  isDesktop: isDesktop, 
                  isTablet: isTablet,
                  dbData: _dbData, 
                  pendingCount: _pendingCount,
                  offlineMsg: _offlineMsg, 
                  onRetry: _loadDataFast,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;
  final DashboardMetricsDto? dbData;
  final String? offlineMsg;
  final VoidCallback onRetry;
  final int pendingCount; 

  const _DashboardBody({
    required this.isDesktop, required this.isTablet,
    this.dbData, this.offlineMsg, required this.onRetry, required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    final kpis = dbData?.kpis ?? <String, dynamic>{};
    final double stockValue = double.tryParse(kpis['stock']?.toString() ?? '0') ?? 0.0;
    final int expiringSoon = int.tryParse(kpis['expiringSoon']?.toString() ?? '0') ?? 0;

    return Column(
      children: [
        const DashboardTopbar(),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.all(isDesktop ? 24 : 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (offlineMsg != null) ...[
                      _OfflineWarningBanner(message: offlineMsg!, onRetry: onRetry),
                      const SizedBox(height: 16),
                    ],

                    DashboardKpiRow(
                      isTablet: isTablet, 
                      isManager: AuthService.isManager,
                      pendingCount: pendingCount,
                      expiringCount: expiringSoon, 
                      stockValue: stockValue, 
                    ),
                    const SizedBox(height: 16),

                    if (isTablet)
                      SizedBox(
                        height: 400, 
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (AuthService.isManager) ...[
                              Expanded(flex: 7, child: SalesChartCard(dbData: dbData)), 
                              const SizedBox(width: 16),
                            ],
                            Expanded(flex: 5, child: StockHighlightsCard(dbData: dbData)), 
                          ],
                        ),
                      )
                    else ...[
                      if (AuthService.isManager) ...[
                        SalesChartCard(dbData: dbData),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(height: 400, child: StockHighlightsCard(dbData: dbData)),
                    ],
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class DashboardTopbar extends StatelessWidget {
  const DashboardTopbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62, padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AC.white, 
        border: Border(bottom: BorderSide(color: AC.border, width: 0.5)), 
        boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))]
      ),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Dashboard', style: AppType.pageTitle),
              Text('Good morning — here\'s what\'s happening today', style: AppType.muted),
            ],
          ),
          const Spacer(),
          appBtn(
            'Ask AI',
            bg: AC.blueLt,
          fg: AC.ink600,
            icon: Icons.auto_awesome,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiChatbotScreen())
              );
            },
          ),
          const SizedBox(width: 12),
          appBtn(
            'Scan Prescription',
            bg: AC.blueLt,
            fg: AC.ink600,
            icon: Icons.document_scanner_rounded,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RxScannerScreen())
              );
            },
          ),
        ],
      ),
    );
  }
}


class _OfflineWarningBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _OfflineWarningBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: AR.r10, border: Border.all(color: const Color(0xFFFDE68A), width: 1)),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFF92400E), size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.w600))),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AC.white, borderRadius: AR.r8, border: Border.all(color: const Color(0xFFFDE68A))),
              child: const Text('Retry Connection', style: TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// 🌟 THE GRAPH WITH THE TOGGLE!
class SalesChartCard extends StatefulWidget {
  final DashboardMetricsDto? dbData;
  const SalesChartCard({super.key, this.dbData});

  @override
  State<SalesChartCard> createState() => _SalesChartCardState();
}
// 🌟 BULLETPROOF GRAPH FIX

class _SalesChartCardState extends State<SalesChartCard> {
  bool _isDaily = true; // Toggle state

  @override
  Widget build(BuildContext context) {
    List<String> labels = [];
    List<double> values = [];
    
    if (widget.dbData != null) {
      if (_isDaily) {
        labels = ['D-6', 'D-5', 'D-4', 'D-3', 'D-2', 'Yest.', 'Today'];
        List<double> rawVals = widget.dbData!.dailyRevenue;
        
        // 🌟 BULLETPROOFING: If backend sends 6 items, pad it to 7 so the chart never breaks!
        if (rawVals.length >= 7) {
          values = rawVals.sublist(rawVals.length - 7);
        } else {
          values = List.filled(7, 0.0);
          int offset = 7 - rawVals.length;
          for (int i = 0; i < rawVals.length; i++) {
            values[offset + i] = rawVals[i];
          }
        }
      } else {
        // Last 7 months
        if (widget.dbData!.salesData.isNotEmpty) {
          labels = widget.dbData!.salesData.map((e) => e['label'].toString().split(' ')[0]).toList();
          values = widget.dbData!.salesData.map((e) => double.tryParse(e['value'].toString()) ?? 0.0).toList();
        }
      }
    }

    // Failsafe if data is totally empty
    if (labels.isEmpty) {
      labels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul'];
      values = [0, 0, 0, 0, 0, 0, 0];
    }

    double maxY = 0;
    List<FlSpot> spots = [];
    for (int i = 0; i < values.length; i++) {
      if (values[i] > maxY) maxY = values[i];
      spots.add(FlSpot(i.toDouble(), values[i]));
    }
    
    // Prevent UI crash if all sales are exactly 0
    if (maxY == 0) maxY = 10; 
    double calculatedInterval = math.max(1.0, (maxY / 5).ceilToDouble());

    return Container(
      height: 400, 
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pharmacy Revenue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.ink900)),
                    SizedBox(height: 4),
                    Text('Real-time operational cash flow', style: TextStyle(fontSize: 13, color: AC.ink400)),
                  ],
                ),
              ),
              Container(
                height: 32,
                decoration: BoxDecoration(color: const Color(0xFFF3F6FA), borderRadius: AR.pill, border: Border.all(color: AC.border)),
                child: Row(
                  children: [
                    _buildToggleBtn('7 Days', _isDaily, () => setState(() => _isDaily = true)),
                    _buildToggleBtn('7 Months', !_isDaily, () => setState(() => _isDaily = false)),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          if (widget.dbData == null) 
             const Expanded(child: Center(child: CircularProgressIndicator(color: AC.blue500)))
          else 
            Expanded(
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (labels.length - 1).toDouble(), // 🌟 FORCES the grid to draw 7 columns no matter what!
                  minY: 0, 
                  maxY: maxY * 1.2,
                  gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: AC.border, strokeWidth: 1, dashArray: [5, 5])),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, reservedSize: 30, interval: 1,
                        getTitlesWidget: (value, meta) {
                          int index = value.toInt();
                          if (index >= 0 && index < labels.length) {
                            return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(labels[index], style: const TextStyle(fontSize: 10, color: AC.ink400)));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, reservedSize: 46, interval: calculatedInterval, 
                        getTitlesWidget: (value, meta) {
                          if (value == maxY * 1.2) return const Text(''); 
                          String text = value.toInt().toString();
                          if (value >= 1000) text = '${(value/1000).toStringAsFixed(1)}k';
                          return Text(text, style: const TextStyle(fontSize: 10, color: AC.ink400));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots, isCurved: true, curveSmoothness: 0.35, color: AC.blue500, barWidth: 3, isStrokeCapRound: true,
                      dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: AC.blue500)),
                      belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [AC.blue500.withOpacity(0.2), AC.blue500.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: isActive ? AC.white : Colors.transparent, borderRadius: AR.pill, boxShadow: isActive ? AS.navActive : null),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: isActive ? AC.ink900 : AC.ink400)),
      ),
    );
  }
}
class StockHighlightsCard extends StatelessWidget {
  final DashboardMetricsDto? dbData;

  const StockHighlightsCard({super.key, this.dbData});

  @override
  Widget build(BuildContext context) {
    final highlightItems = <Widget>[];

    if (dbData != null && dbData!.frequentItems.isNotEmpty) {
      for (var item in dbData!.frequentItems) {
        highlightItems.add(_buildStockItem(
          icon: Icons.trending_up_rounded, title: item['name']?.toString() ?? 'Unknown',
          subtitle: 'Requested ${item['units']} times recently', status: 'High Demand', statusColor: AC.greenFg,
        ));
      }
    }

    if (dbData != null && dbData!.lowStockItems.isNotEmpty) {
      for (var item in dbData!.lowStockItems.take(2)) {
        highlightItems.add(_buildStockItem(
          icon: Icons.inventory_2_outlined, title: item['name']?.toString() ?? 'Unknown',
          subtitle: 'Stock: ${item['stock']} (Reorder: ${item['reorder_level']})', status: 'Low Stock', statusColor: AC.redFg,
        ));
      }
    }

    if (dbData != null && dbData!.expiringItems.isNotEmpty) {
      for (var item in dbData!.expiringItems.take(1)) { 
        highlightItems.add(_buildStockItem(
            icon: Icons.timer_off_rounded, title: item['name']?.toString() ?? 'Unknown',
            subtitle: '${item['stock']} units expiring in ${item['days_left']} days', status: 'Expiring', statusColor: AC.amberFg
        ));
      }
    }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card), // FIXED THEME
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Inventory Action Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.ink900)),
          const SizedBox(height: 16),
          
          Expanded(
            child: dbData == null
              ? const Center(child: CircularProgressIndicator(color: AC.blue500))
              : ListView(
                  padding: EdgeInsets.zero,
                  children: highlightItems.isEmpty 
                    ? [const Center(child: Text("All shelves fully stocked and healthy.", style: AppType.muted))] 
                    : highlightItems,
                ),
          ),
              
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/inventory'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF3F6FA), foregroundColor: AC.ink900, elevation: 0, shape: const RoundedRectangleBorder(borderRadius: AR.r8)),
            child: const Text('View Inventory', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          )
        ],
      ),
    );
  }

  Widget _buildStockItem({required IconData icon, required String title, required String subtitle, required String status, required Color statusColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.white, borderRadius: AR.r10, border: Border.all(color: AC.border, width: 0.5)),
      child: Row(
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: statusColor, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.ink900), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AC.ink400), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}