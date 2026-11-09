import 'package:flutter/material.dart';

/// Design tokens: taxi-yellow brand + emerald accents on an ink-navy base.
///
/// Never hardcode colors in widgets — always pull them from here so the whole
/// app stays visually consistent and themeable.
class AppColors {
  const AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────────
  /// Primary taxi yellow — CTAs, highlights, active states.
  static const Color brand = Color(0xFFF7C948);
  static const Color brandDeep = Color(0xFFE8A400);
  static const Color brandSoft = Color(0xFFFFF6DC);

  /// Emerald accent — online drivers, success, "available".
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDeep = Color(0xFF059669);
  static const Color emeraldSoft = Color(0xFFD9F7EC);

  // ── Ink / neutrals ─────────────────────────────────────────────────────────
  static const Color ink = Color(0xFF0F172A); // primary text
  static const Color inkSoft = Color(0xFF334155); // secondary text
  static const Color muted = Color(0xFF64748B); // hints, captions
  static const Color faint = Color(0xFF94A3B8);
  static const Color line = Color(0xFFE7EAF0); // borders / dividers

  // ── Surfaces ───────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF9FAFC);
  static const Color surfaceDark = Color(0xFF111C33); // dark cards (driver HUD)
  static const Color scrim = Color(0x99000000);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFE3F9F0);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFFF3DC);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSoft = Color(0xFFFEECEC);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoSoft = Color(0xFFE8F1FE);

  // ── Gradients ──────────────────────────────────────────────────────────────
  /// Hero gradient used on primary buttons & the auth screen header.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF9D423), Color(0xFFF7C948), Color(0xFFE8A400)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF16233F), Color(0xFF0F172A)],
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF059669)],
  );

  /// Indigo → violet gradient — admin portal header (home hero).
  static const LinearGradient portalGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F5BEA), Color(0xFF7C3AED)],
  );

  /// Status color mapping shared by chips/badges across the app.
  static Color status(String key) => switch (key) {
    'available' || 'active' || 'validated' || 'approved' || 'online' => success,
    'pending' || 'waiting' || 'offline_pending' || 'expiring' => warning,
    'busy' || 'in_progress' => info,
    'inactive' ||
    'suspended' ||
    'rejected' ||
    'refused' ||
    'disabled' => danger,
    _ => muted,
  };
}
