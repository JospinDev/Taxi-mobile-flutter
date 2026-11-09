import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_space.dart';
import '../../../app/theme/app_typography.dart';

/// "Slide to confirm" — used for irreversible driver actions (start, finish)
/// so they can't be triggered by an accidental tap while driving.
class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.icon = Icons.arrow_forward_rounded,
    this.color = AppColors.brand,
    this.foreground = AppColors.ink,
    this.loading = false,
  });

  final String label;
  final Future<void> Function() onConfirmed;
  final IconData icon;
  final Color color;
  final Color foreground;
  final bool loading;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> with SingleTickerProviderStateMixin {
  static const _height = 62.0;
  static const _thumb = 54.0;
  double _drag = 0;
  bool _confirmed = false;
  late final AnimationController _back = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))
    ..addListener(() => setState(() => _drag = _drag * (1 - _back.value)));

  @override
  void didUpdateWidget(covariant SlideToConfirm old) {
    super.didUpdateWidget(old);
    // Reset when the label changes (next step) or after a failed action.
    if (old.label != widget.label || (old.loading && !widget.loading)) {
      _confirmed = false;
      _drag = 0;
    }
  }

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final max = c.maxWidth - _thumb - 8;
        final ratio = max <= 0 ? 0.0 : (_drag / max).clamp(0.0, 1.0);
        return Container(
          height: _height,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: .18),
            borderRadius: AppRadius.rPill,
            border: Border.all(color: widget.color.withValues(alpha: .5)),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Fill behind the thumb.
              Container(
                width: _thumb + 8 + _drag,
                decoration: BoxDecoration(color: widget.color.withValues(alpha: .35 + .4 * ratio), borderRadius: AppRadius.rPill),
              ),
              Center(
                child: Opacity(
                  opacity: 1 - ratio,
                  child: Text(
                    widget.label,
                    style: AppTypography.button.copyWith(color: Colors.white),
                  ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1800.ms, color: widget.color),
                ),
              ),
              Positioned(
                left: 4 + _drag,
                child: GestureDetector(
                  onHorizontalDragUpdate: widget.loading || _confirmed
                      ? null
                      : (d) => setState(() => _drag = (_drag + d.delta.dx).clamp(0, max)),
                  onHorizontalDragEnd: widget.loading || _confirmed
                      ? null
                      : (_) async {
                          if (ratio > .85) {
                            HapticFeedback.heavyImpact();
                            setState(() {
                              _confirmed = true;
                              _drag = max;
                            });
                            await widget.onConfirmed();
                          } else {
                            _back.forward(from: 0);
                          }
                        },
                  child: Container(
                    width: _thumb,
                    height: _thumb,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: widget.color.withValues(alpha: .5), blurRadius: 14)],
                    ),
                    child: widget.loading || _confirmed
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: widget.foreground),
                          )
                        : Icon(widget.icon, color: widget.foreground),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
