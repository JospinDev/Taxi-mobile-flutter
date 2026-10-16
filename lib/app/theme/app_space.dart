import 'package:flutter/material.dart';

/// Spacing scale, corner radii and elevation styles.
/// Grid unit = 4pt; all paddings in the app should come from [AppSpace].
class AppSpace {
  const AppSpace._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: 20);
  static const EdgeInsets card = EdgeInsets.all(16);
}

class AppRadius {
  const AppRadius._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pill = 999;

  static final BorderRadius rSm = BorderRadius.circular(sm);
  static final BorderRadius rMd = BorderRadius.circular(md);
  static final BorderRadius rLg = BorderRadius.circular(lg);
  static final BorderRadius rXl = BorderRadius.circular(xl);
  static final BorderRadius rXxl = BorderRadius.circular(xxl);
  static final BorderRadius rPill = BorderRadius.circular(pill);
}

/// Soft, layered shadows — the signature of the premium look.
class AppShadow {
  const AppShadow._();

  static List<BoxShadow> get card => const [
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -4,
    ),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static List<BoxShadow> get soft => const [
    BoxShadow(
      color: Color(0x140F172A),
      blurRadius: 16,
      offset: Offset(0, 4),
      spreadRadius: -2,
    ),
  ];

  static List<BoxShadow> get brand => const [
    BoxShadow(
      color: Color(0x59E8A400),
      blurRadius: 20,
      offset: Offset(0, 8),
      spreadRadius: -4,
    ),
  ];

  static List<BoxShadow> get floating => const [
    BoxShadow(
      color: Color(0x260F172A),
      blurRadius: 30,
      offset: Offset(0, 12),
      spreadRadius: -6,
    ),
  ];
}
