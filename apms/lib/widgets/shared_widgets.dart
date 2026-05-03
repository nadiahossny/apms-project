import 'package:flutter/material.dart';
import '../theme/tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class ScreenTopbar extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  const ScreenTopbar({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AC.white,
        border: Border(bottom: BorderSide(color: AC.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AC.ink900,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AC.ink300),
              ),
            ],
          ),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

Widget appCard({required Widget child, EdgeInsetsGeometry? padding}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AC.white,
      borderRadius: AR.r14,
      border: Border.all(color: AC.border, width: 0.5),
      boxShadow: AS.card,
    ),
    child: child,
  );
}

Widget appBadge(String label, Color fg, Color bg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: bg, borderRadius: AR.pill),
  child: Text(
    label,
    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
  ),
);

Widget appBtn(
  String label, {
  IconData? icon,
  Color? bg,
  Color? fg,
  VoidCallback? onTap,
}) {
  return ElevatedButton.icon(
    onPressed: onTap,
    icon: icon != null ? Icon(icon, size: 16) : const SizedBox.shrink(),
    label: Text(
      label, 
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: bg ?? AC.blue500,     // Defaults to the blue500
      foregroundColor: fg ?? AC.white,       // Defaults to white text/icon
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AR.r10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}

Widget appDivider({EdgeInsetsGeometry? margin}) =>
    Container(height: 0.5, color: AC.border, margin: margin);

// ── Offline / connection warning banner ──────────────────────────────────────
class OfflineBanner extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  const OfflineBanner({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: const Color(0xFFD97706),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null)
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class BgPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..style = PaintingStyle.fill;
    p.color = const Color(0x0FFFFFFF);
    c.drawCircle(Offset(s.width * 0.92, s.height * -0.1), 260, p);
    p.color = const Color(0x0DFFFFFF);
    c.drawCircle(Offset(s.width * 0.05, s.height * 1.1), 200, p);
    p.color = const Color(0x0AFFFFFF);
    c.drawCircle(const Offset(-40, 100), 140, p);
  }

  @override
  bool shouldRepaint(_) => false;
}
