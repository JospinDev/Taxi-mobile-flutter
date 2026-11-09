import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../app/theme/app_colors.dart';
import 'app_motion.dart';

/// Top-down taxi marker, rotated to its heading, with a soft glow.
class TaxiMarker extends StatelessWidget {
  const TaxiMarker({
    super.key,
    this.heading = 0,
    this.highlighted = false,
    this.size = 44,
  });

  /// Degrees, 0 = north, clockwise.
  final double heading;

  /// The assigned driver: bigger, with pulse rings.
  final bool highlighted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final car = AnimatedRotation(
      turns: heading / 360,
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      child: Container(
        width: size * .62,
        height: size * .62,
        decoration: BoxDecoration(
          color: AppColors.ink,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.brand, width: 2.4),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Icon(
          Icons.navigation_rounded,
          size: size * .34,
          color: AppColors.brand,
        ),
      ),
    );
    if (!highlighted) return Center(child: car);
    return PulseRings(color: AppColors.brand, size: size, rings: 2, child: car);
  }
}

/// Pickup / dropoff pin that drops in with a bounce.
class LocationPin extends StatelessWidget {
  const LocationPin.pickup({super.key, this.label})
    : color = AppColors.emerald,
      icon = Icons.person_pin_circle_rounded;

  const LocationPin.dropoff({super.key, this.label})
    : color = AppColors.ink,
      icon = Icons.flag_rounded;

  final Color color;
  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8)],
            ),
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 4)),
            ],
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        Container(width: 3, height: 10, color: color),
      ],
    ).animate().moveY(begin: -28, end: 0, duration: 500.ms, curve: Curves.bounceOut).fadeIn(
      duration: 200.ms,
    );
  }
}

/// Fixed centre pin used while the user drags the map to choose a point.
class CenterPin extends StatelessWidget {
  const CenterPin({super.key, required this.lifted, this.color = AppColors.emerald});

  /// True while the map is moving: the pin floats up and its shadow shrinks.
  final bool lifted;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSlide(
          offset: Offset(0, lifted ? -.25 : 0),
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 12)],
            ),
            child: const Icon(Icons.circle, size: 10, color: Colors.white),
          ),
        ),
        Container(width: 3, height: 14, color: color),
        AnimatedContainer(
          duration: AppMotion.fast,
          width: lifted ? 6 : 12,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .25),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

/// Interpolates between two headings the short way round (359° → 1°).
double lerpHeading(double from, double to, double t) {
  var delta = (to - from) % 360;
  if (delta > 180) delta -= 360;
  return (from + delta * t) % 360;
}

/// Helper: angle in radians for [Transform.rotate].
double headingToRadians(double heading) => heading * math.pi / 180;
