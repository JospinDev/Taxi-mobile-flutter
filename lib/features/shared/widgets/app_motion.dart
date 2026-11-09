import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../app/theme/app_colors.dart';

/// Motion tokens — every animation in the app picks its timing from here.
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 520);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;

  /// Delay between two items of a staggered list.
  static const Duration stagger = Duration(milliseconds: 45);
}

/// Entrance animations: `child.entrance(index: i)` fades & slides items in,
/// staggered by their position. Capped so long lists don't wait forever.
extension EntranceAnimation on Widget {
  Widget entrance({int index = 0, double dy = .08, Duration? delay}) {
    final d = delay ?? AppMotion.stagger * math.min(index, 10);
    return animate(delay: d)
        .fadeIn(duration: AppMotion.medium, curve: AppMotion.curve)
        .slideY(begin: dy, end: 0, duration: AppMotion.medium, curve: AppMotion.curve);
  }

  /// Pop-in for hero elements (icons, badges, success marks).
  Widget popIn({Duration delay = Duration.zero}) => animate(delay: delay)
      .fadeIn(duration: AppMotion.fast)
      .scale(
        begin: const Offset(.6, .6),
        end: const Offset(1, 1),
        duration: AppMotion.slow,
        curve: Curves.elasticOut,
      );
}

/// Expanding rings — "searching for a driver" radar, live markers, CTA halo.
class PulseRings extends StatefulWidget {
  const PulseRings({
    super.key,
    this.color = AppColors.brand,
    this.size = 220,
    this.rings = 3,
    this.duration = const Duration(milliseconds: 2400),
    this.child,
  });

  final Color color;
  final double size;
  final int rings;
  final Duration duration;
  final Widget? child;

  @override
  State<PulseRings> createState() => _PulseRingsState();
}

class _PulseRingsState extends State<PulseRings> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration)
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < widget.rings; i++)
                _ring((_c.value + i / widget.rings) % 1),
              ?child,
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }

  Widget _ring(double t) {
    final eased = Curves.easeOut.transform(t);
    return Container(
      width: widget.size * (.18 + .82 * eased),
      height: widget.size * (.18 + .82 * eased),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.color.withValues(alpha: .22 * (1 - t)),
        border: Border.all(color: widget.color.withValues(alpha: .5 * (1 - t)), width: 1.5),
      ),
    );
  }
}

/// Rotating sweep line on top of [PulseRings] for a radar feel.
class RadarSweep extends StatefulWidget {
  const RadarSweep({super.key, this.size = 220, this.color = AppColors.brand});

  final double size;
  final Color color;

  @override
  State<RadarSweep> createState() => _RadarSweepState();
}

class _RadarSweepState extends State<RadarSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              widget.color.withValues(alpha: 0),
              widget.color.withValues(alpha: 0),
              widget.color.withValues(alpha: .35),
            ],
            stops: const [0, .75, 1],
          ),
        ),
      ),
    );
  }
}

/// Number that counts up/down smoothly when its value changes (fares, km…).
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = AppMotion.slow,
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: AppMotion.curve,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}

/// Small blinking "live" dot.
class LiveDot extends StatelessWidget {
  const LiveDot({super.key, this.color = AppColors.emerald, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 1, end: .25, duration: 700.ms);
  }
}

/// Circular countdown (driver ride offer): drains from full to empty.
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.total,
    required this.remaining,
    this.size = 56,
    this.color = AppColors.brand,
  });

  final Duration total;
  final Duration remaining;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total.inMilliseconds == 0
        ? 0.0
        : (remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final urgent = remaining.inSeconds <= 5;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: ratio),
            duration: const Duration(milliseconds: 250),
            builder: (context, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: .15),
              color: urgent ? AppColors.danger : color,
            ),
          ),
          Text(
            '${remaining.inSeconds}',
            style: TextStyle(
              fontSize: size * .34,
              fontWeight: FontWeight.w800,
              color: urgent ? AppColors.danger : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
