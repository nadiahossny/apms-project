import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NAV ITEMS
// ─────────────────────────────────────────────────────────────────────────────
class NavItem {
  final IconData icon;
  final String label;
  final int badge;
  final String route;
  const NavItem({
    required this.icon,
    required this.label,
    required this.route,
    this.badge = 0,
  });
}

const navItemsList = [
  NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/dashboard'),
  NavItem(icon: Icons.inventory_2_rounded, label: 'Inventory', route: '/inventory'),
  NavItem(icon: Icons.receipt_outlined, label: 'Invoices', route: '/invoices'),
  NavItem(icon: Icons.receipt_long_rounded, label: 'Prescriptions', route: '/prescriptions'),
  NavItem(icon: Icons.precision_manufacturing_rounded, label: 'Robot panel', route: '/robot'),
  
  // 🌟 Screen 1: The standard 365-day financial report
  NavItem(icon: Icons.bar_chart_rounded, label: 'Operational Reports', route: '/reports'),
  
  // 🌟 Screen 2: Ghada's predictive AI models
  NavItem(icon: Icons.auto_awesome, label: 'AI Command Center', route: '/ai_center'),
  
  NavItem(icon: Icons.settings_outlined, label: 'Settings', route: '/settings'),
];

class AppShell extends StatelessWidget {
  final int index;
  final Widget child;
  const AppShell({super.key, required this.index, required this.child});

  // 🌟 Filter items dynamically based on role (Hide both from normal staff)
  List<NavItem> get visibleItems => navItemsList.where((item) {
    if (!AuthService.isManager && (item.route == '/reports' || item.route == '/ai_center')) {
      return false;
    }
    return true;
  }).toList();
  

  // 🌟 Safe active index calculation
  int get activeVisibleIndex {
    final currentRoute = navItemsList[index].route;
    return visibleItems.indexWhere((e) => e.route == currentRoute);
  }

  void _go(BuildContext ctx, int visibleIdx) {
    if (visibleIdx < 0 || visibleIdx >= visibleItems.length) return;
    final targetRoute = visibleItems[visibleIdx].route;
    if (navItemsList[index].route == targetRoute) return;
    Navigator.of(ctx).pushReplacementNamed(targetRoute);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 960;
    return Scaffold(
      backgroundColor: AC.page,
      body: isDesktop
          ? Row(
              children: [
                _Sidebar(
                  items: visibleItems,
                  selected: activeVisibleIndex,
                  onSelect: (i) => _go(context, i),
                ),
                Expanded(child: child),
              ],
            )
          : child,
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: activeVisibleIndex >= 0 && activeVisibleIndex < 5
                  ? activeVisibleIndex
                  : 0,
              onDestinationSelected: (i) => _go(context, i),
              backgroundColor: AC.white,
              indicatorColor: AC.blueLt,
              destinations: visibleItems
                  .take(5)
                  .map(
                    (e) => NavigationDestination(
                      icon: Icon(e.icon, color: AC.ink300),
                      selectedIcon: Icon(e.icon, color: AC.blue500),
                      label: e.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  const _Sidebar({
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      decoration: const BoxDecoration(color: AC.white, boxShadow: AS.sidebar),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 22),
          // Brand
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AC.blue500,
                    borderRadius: AR.r10,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x594A90D9),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_pharmacy_rounded,
                    color: AC.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'PharmaSys',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AC.ink900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'MAIN MENU',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AC.ink300,
                letterSpacing: 1.4,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: items.length,
              itemBuilder: (_, i) => _SidebarTile(
                item: items[i],
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            ),
          ),
          Container(
            height: 0.5,
            color: AC.border,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const SizedBox(height: 8),
          // User chip
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AC.blue500,
                    borderRadius: AR.pill,
                  ),
                  child: Center(
                    child: Text(
                      Session.current?.initials ?? 'PM',
                      style: const TextStyle(
                        color: AC.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Session.current?.name ?? 'User',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AC.ink600,
                      ),
                    ),
                    Text(
                      Session.current?.roleLabel ?? 'Account',
                      style: const TextStyle(fontSize: 10, color: AC.ink300),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 🌟 زرار تقفيل الشيفت 🌟
          
        ],
      ),
    );
  }
}

class _SidebarTile extends StatefulWidget {
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  @override
  State<_SidebarTile> createState() => _STState();
}

class _STState extends State<_SidebarTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: s
                ? AC.blueLt
                : _h
                ? const Color(0xFFF8FAFC)
                : Colors.transparent,
            borderRadius: AR.r10,
            boxShadow: s ? AS.navActive : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.item.icon,
                size: 16,
                color: s ? AC.blue500 : AC.ink400,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.item.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: s ? FontWeight.w600 : FontWeight.w500,
                    color: s ? AC.blue500 : AC.ink400,
                  ),
                ),
              ),
              if (widget.item.badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: AC.amberFg,
                    borderRadius: AR.pill,
                  ),
                  child: Text(
                    '${widget.item.badge}',
                    style: const TextStyle(
                      color: AC.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
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
