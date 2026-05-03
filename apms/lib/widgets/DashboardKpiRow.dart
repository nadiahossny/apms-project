import 'package:flutter/material.dart';
import '../theme/tokens.dart';

class DashboardKpiRow extends StatelessWidget {
  final bool isTablet;
  final bool isManager;
  final int pendingCount;
  final int expiringCount; 
  final double stockValue; 

  const DashboardKpiRow({
    super.key, 
    required this.isTablet, 
    required this.isManager,
    this.pendingCount = 0,
    this.expiringCount = 0,
    this.stockValue = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _PendingKpiCard(count: pendingCount), 
      _ExpiringKpiCard(count: expiringCount), // 🌟 Now includes the action button!
      if (isManager) 
         _InventoryValueCard(stockValue: stockValue) 
      else 
         const _ShiftWelcomeCard(),
    ];

    if (isTablet) {
      return SizedBox(
        height: 165,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cards.asMap().entries.map((e) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: e.key < cards.length - 1 ? 14 : 0),
              child: e.value,
            ),
          )).toList(),
        ),
      );
    }
    
    return SizedBox(
      height: 165, 
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => SizedBox(width: 240, child: cards[i]),
      ),
    );
  }
}

class _PendingKpiCard extends StatelessWidget {
  final int count;
  const _PendingKpiCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 36, height: 36, decoration: const BoxDecoration(color: AC.blueLt, borderRadius: AR.r10), child: const Icon(Icons.receipt_long_rounded, color: AC.blue500, size: 18)),
              const Spacer(),
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: AC.blue500, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text("ACTION REQUIRED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AC.blue500)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('PENDING PRESCRIPTIONS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AC.ink300, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('$count', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AC.ink900, letterSpacing: -0.4))),
          const Spacer(),
          SizedBox(
            width: double.infinity, height: 26, 
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/prescriptions'),
              style: ElevatedButton.styleFrom(backgroundColor: AC.blue500, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              child: const Text('View Prescriptions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          )
        ],
      ),
    );
  }
}

// Inside lib/widgets/DashboardKpiRow.dart

class _ExpiringKpiCard extends StatelessWidget {
  final int count;
  const _ExpiringKpiCard({required this.count});

  @override
  Widget build(BuildContext context) {
    final isDanger = count > 0;
    final themeColor = isDanger ? AC.redFg : AC.amberFg;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.white, 
        borderRadius: AR.r14, 
        border: Border.all(color: isDanger ? AC.redRing : AC.border, width: isDanger ? 1 : 0.5), 
        boxShadow: AS.card
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // 🌟 Added for safe spacing
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36, 
                decoration: BoxDecoration(color: isDanger ? AC.redBg : AC.amberBg, borderRadius: AR.r10), 
                child: Icon(Icons.timer_off_rounded, color: themeColor, size: 18)
              ),
              const Spacer(),
              Container(width: 7, height: 7, decoration: BoxDecoration(color: isDanger ? AC.redFg : AC.ink400, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(isDanger ? "RISK DETECTED" : "ALL CLEAR", 
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isDanger ? AC.redFg : AC.ink400)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('EXPIRING SOON (30 DAYS)', 
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AC.ink300, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, 
                child: Text('$count', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AC.ink900, letterSpacing: -0.4))),
            ],
          ),
          SizedBox(
            width: double.infinity, height: 26, 
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/inventory'), 
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor, 
                foregroundColor: Colors.white, 
                elevation: 0, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
              ),
              child: const Text('Review Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          )
        ],
      ),
    );
  }
}
class _InventoryValueCard extends StatelessWidget {
  final double stockValue;
  const _InventoryValueCard({required this.stockValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AC.white, borderRadius: AR.r14, border: Border.all(color: AC.border, width: 0.5), boxShadow: AS.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 36, height: 36, decoration: const BoxDecoration(color: AC.greenBg, borderRadius: AR.r10), child: const Icon(Icons.account_balance_wallet_outlined, color: AC.greenFg, size: 18)),
              const Spacer(),
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: AC.greenFg, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text("CAPITAL ASSET", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AC.greenFg)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('CURRENT INVENTORY VALUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AC.ink300, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('EGP ${stockValue.toStringAsFixed(0)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AC.ink900, letterSpacing: -0.4))),
          const Spacer(),
          SizedBox(
            width: double.infinity, height: 26, 
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pushReplacementNamed('/reports'), 
              style: ElevatedButton.styleFrom(backgroundColor: AC.greenFg, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              child: const Text('View Reports', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), 
            ),
          )
        ],
      ),
    );
  }
}

class _ShiftWelcomeCard extends StatelessWidget {
  const _ShiftWelcomeCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AC.blue500, borderRadius: AR.r14, boxShadow: AS.card),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.waving_hand_rounded, color: AC.white, size: 28),
          SizedBox(height: 12),
          Text('Welcome to your shift!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.white)),
          SizedBox(height: 4),
          Text('Review tasks from the sidebar.', style: TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }
}