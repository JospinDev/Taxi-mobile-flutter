import 'package:flutter/material.dart';

/// Typography scale — tight, modern, high-contrast.
/// Headings use w800 with slight negative letter-spacing for a premium feel.
class AppTypography {
  const AppTypography._();

  static const String? fontFamily = null; // system font (SF Pro / Roboto)

  static const TextStyle display = TextStyle(
    fontSize: 34,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    color: Color(0xFF0F172A),
  );

  static const TextStyle h1 = TextStyle(
    fontSize: 28,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: Color(0xFF0F172A),
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 22,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: Color(0xFF0F172A),
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: Color(0xFF0F172A),
  );

  static const TextStyle bodyLg = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w500,
    color: Color(0xFF334155),
  );

  static const TextStyle body = TextStyle(
    fontSize: 14.5,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: Color(0xFF334155),
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w500,
    color: Color(0xFF64748B),
  );

  static const TextStyle overline = TextStyle(
    fontSize: 11.5,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: Color(0xFF64748B),
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: Color(0xFF0F172A),
  );
}
