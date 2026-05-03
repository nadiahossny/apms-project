// lib/theme/tokens.dart
// ── Shared design tokens for all APMS screens ──────────────────────────────
// Import this in every file: import '../theme/tokens.dart';
// (or 'theme/tokens.dart' from lib root)
//
// PLACE THIS FILE AT: lib/theme/tokens.dart
// ────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

// ── Colours ──────────────────────────────────────────────────────────────────
class AC {
  AC._();
  static const blue500 = Color(0xFF4A90D9);
  static const blueLt = Color(0xFFEBF4FF);
  static const blueMd = Color(0xFFDBEAFE);
  static const blueXlt = Color(0xFFF4F9FF);
  static const darkBlue = Color(0xFF004187); // Professional deep navy
  static const darkBlueLt = Color(0xFFE8F1F9); // Light background for dark blue
  static const page = Color(0xFFF0F4F8);
  static const white = Color(0xFFFFFFFF);
  static const ink900 = Color(0xFF111827);
  static const ink600 = Color(0xFF374151);
  static const ink400 = Color(0xFF6B7280);
  static const ink300 = Color(0xFF9CA3AF);
  static const ink200 = Color(0xFFD1D5DB);
  static const tealFg = Color(0xFF0D9488);
  static const tealBg = Color(0xFFF0FDFA);
  static const amberFg = Color(0xFFD97706);
  static const amberBg = Color(0xFFFFFBEB);
  static const amberRing = Color(0xFFFDE68A);
  static const redFg = Color(0xFFDC2626);
  static const redBg = Color(0xFFFFF1F2);
  static const redRing = Color(0xFFFECACA);
  static const greenFg = Color(0xFF059669);
  static const greenBg = Color(0xFFF0FDF4);
  static const greenRing = Color(0xFFA7F3D0);
  static const violetFg = Color(0xFF7C3AED);
  static const violetBg = Color(0xFFF5F3FF);
  static const border = Color(0xFFE5E9EE);
  static const borderMd = Color(0xFFD1D5DB);
}

// ── Shadows ───────────────────────────────────────────────────────────────────
class AS {
  AS._();
  static const card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x08000000), blurRadius: 24, offset: Offset(0, 10)),
  ];
  static const sidebar = [
    BoxShadow(color: Color(0x06000000), blurRadius: 0, offset: Offset(1, 0)),
    BoxShadow(color: Color(0x0A4A90D9), blurRadius: 16, offset: Offset(4, 0)),
  ];
  static const navActive = [
    BoxShadow(color: Color(0x264A90D9), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x1A4A90D9), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const button = [
    BoxShadow(color: Color(0x4D4A90D9), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const kpi = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4)),
  ];
  static const kpiHover = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const chatPanel = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4)),
  ];
  static const panel = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4)),
  ];
}

// ── Border radii ───────────────────────────────────────────────────────────────
class AR {
  AR._();
  static const r8 = BorderRadius.all(Radius.circular(8));
  static const r10 = BorderRadius.all(Radius.circular(10));
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r14 = BorderRadius.all(Radius.circular(14));
  static const pill = BorderRadius.all(Radius.circular(100));
}

// ── Typography ─────────────────────────────────────────────────────────────────
class AppType {
  AppType._();

  static const pageTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AC.ink900,
    letterSpacing: -0.3,
  );

  static const sectionTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AC.ink900,
  );

  static const cardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AC.ink900,
  );

  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AC.ink600,
  );

  static const muted = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AC.ink400,
  );

  static const caps = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AC.ink400,
    letterSpacing: 0.8,
  );

  static const value = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AC.ink900,
    letterSpacing: -0.5,
  );

  static const badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AC.white,
  );
}
