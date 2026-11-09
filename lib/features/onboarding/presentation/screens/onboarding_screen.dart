import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../providers/onboarding_provider.dart';

class _Slide {
  const _Slide({
    required this.title,
    required this.text,
    required this.icon,
    required this.accent,
    required this.background,
    required this.chips,
  });

  final String title;
  final String text;
  final IconData icon;
  final Color accent;
  final List<Color> background;

  /// Floating benefit chips around the illustration.
  final List<(IconData, String)> chips;
}

const _slides = [
  _Slide(
    title: 'Un taxi en\nquelques secondes',
    text: 'Choisissez votre destination, voyez les taxis disponibles autour de vous '
        'sur une vraie carte et commandez en un geste.',
    icon: Icons.local_taxi_rounded,
    accent: AppColors.brand,
    background: [Color(0xFF16233F), Color(0xFF0F172A)],
    chips: [(Icons.timer_rounded, '~3 min'), (Icons.near_me_rounded, 'Taxis proches'), (Icons.touch_app_rounded, '1 geste')],
  ),
  _Slide(
    title: 'Suivez votre chauffeur\nen temps réel',
    text: 'Position en direct sur la carte, notifications dès qu\'il arrive '
        'et messages WhatsApp à chaque étape.',
    icon: Icons.share_location_rounded,
    accent: Color(0xFF60A5FA),
    background: [Color(0xFF0C2340), Color(0xFF0B1324)],
    chips: [(Icons.notifications_active_rounded, 'Alertes'), (Icons.chat_rounded, 'WhatsApp'), (Icons.gps_fixed_rounded, 'GPS live')],
  ),
  _Slide(
    title: 'Un prix juste\net transparent',
    text: 'Estimation avant de commander. Facture finale calculée sur les vrais '
        'kilomètres parcourus, sans surprise.',
    icon: Icons.receipt_long_rounded,
    accent: Color(0xFF34D399),
    background: [Color(0xFF0B2E25), Color(0xFF0A1A17)],
    chips: [(Icons.straighten_rounded, 'Km réels'), (Icons.payments_rounded, 'Espèces'), (Icons.phone_android_rounded, 'Mobile money')],
  ),
  _Slide(
    title: 'Chauffeur ?\nConduisez et gagnez',
    text: 'Recevez des courses près de vous, suivez vos gains du jour et votre '
        'portefeuille directement dans l\'application.',
    icon: Icons.account_balance_wallet_rounded,
    accent: Color(0xFFFBBF24),
    background: [Color(0xFF2B1E07), Color(0xFF140F05)],
    chips: [(Icons.trending_up_rounded, 'Gains'), (Icons.star_rounded, 'Notes'), (Icons.bolt_rounded, 'Offres live')],
  ),
];

/// First-launch "why use the app" screens, with a Skip button top-right.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pager = PageController();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pager.addListener(() => setState(() => _page = _pager.page ?? 0));
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  int get _index => _page.round();
  bool get _isLast => _index == _slides.length - 1;

  void _finish() {
    HapticFeedback.mediumImpact();
    ref.read(onboardingDoneProvider.notifier).complete();
  }

  void _next() {
    if (_isLast) return _finish();
    HapticFeedback.selectionClick();
    _pager.nextPage(duration: const Duration(milliseconds: 480), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];
    return AnnotatedRegion(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: slide.background,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── Top bar: brand + Skip (top-right) ───────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.sm, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: AppRadius.rSm),
                        child: const Icon(Icons.local_taxi_rounded, size: 18, color: AppColors.ink),
                      ),
                      const SizedBox(width: 8),
                      Text('Taxi Driving', style: AppTypography.bodyLg.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      AnimatedOpacity(
                        duration: AppMotion.medium,
                        opacity: _isLast ? 0 : 1,
                        child: TextButton(
                          onPressed: _isLast ? null : _finish,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: .1),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text('Passer'),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Pages ───────────────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pager,
                    itemCount: _slides.length,
                    itemBuilder: (context, i) => _SlideView(slide: _slides[i], offset: _page - i),
                  ),
                ),

                // ── Dots + CTA ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
                  child: Row(
                    children: [
                      for (var i = 0; i < _slides.length; i++)
                        AnimatedContainer(
                          duration: AppMotion.medium,
                          curve: AppMotion.curve,
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _index ? 26 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index ? slide.accent : Colors.white24,
                            borderRadius: AppRadius.rPill,
                          ),
                        ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _next,
                        child: AnimatedContainer(
                          duration: AppMotion.medium,
                          curve: AppMotion.curve,
                          height: 58,
                          width: _isLast ? 170 : 58,
                          decoration: BoxDecoration(
                            color: slide.accent,
                            borderRadius: AppRadius.rPill,
                            boxShadow: [
                              BoxShadow(color: slide.accent.withValues(alpha: .45), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -6),
                            ],
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: AppMotion.fast,
                              child: _isLast
                                  ? Text(
                                      'Commencer',
                                      key: const ValueKey('start'),
                                      maxLines: 1,
                                      style: AppTypography.button.copyWith(color: AppColors.ink),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded, key: ValueKey('next'), color: AppColors.ink),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.offset});

  final _Slide slide;

  /// -1..1 distance from the centred page — drives the parallax.
  final double offset;

  @override
  Widget build(BuildContext context) {
    final fade = (1 - offset.abs()).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
      child: Column(
        children: [
          Expanded(
            child: Transform.translate(
              offset: Offset(offset * -120, 0),
              child: Opacity(opacity: fade, child: _Illustration(slide: slide)),
            ),
          ),
          Transform.translate(
            offset: Offset(offset * 60, 0),
            child: Opacity(
              opacity: fade,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(slide.title, style: AppTypography.display.copyWith(color: Colors.white, fontSize: 32)),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    slide.text,
                    style: AppTypography.bodyLg.copyWith(color: Colors.white70, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: AppSpace.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated hero: pulsing halo, floating icon, orbiting benefit chips.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = math.min(c.maxWidth, c.maxHeight) * .9;
        return Center(
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PulseRings(color: slide.accent, size: size, rings: 3, duration: const Duration(milliseconds: 3200)),
                Container(
                      width: size * .42,
                      height: size * .42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [slide.accent, Color.lerp(slide.accent, Colors.black, .35)!],
                        ),
                        boxShadow: [
                          BoxShadow(color: slide.accent.withValues(alpha: .55), blurRadius: 50, spreadRadius: -4),
                        ],
                      ),
                      child: Icon(slide.icon, size: size * .2, color: AppColors.ink),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: -6, end: 6, duration: 2200.ms, curve: Curves.easeInOut),
                for (var i = 0; i < slide.chips.length; i++)
                  Align(
                    alignment: [const Alignment(-.95, -.55), const Alignment(.95, -.1), const Alignment(-.6, .85)][i],
                    child: _Chip(icon: slide.chips[i].$1, label: slide.chips[i].$2, accent: slide.accent)
                        .animate(delay: (250 + i * 150).ms)
                        .fadeIn(duration: 400.ms)
                        .scale(begin: const Offset(.6, .6), curve: Curves.easeOutBack, duration: 500.ms)
                        .then()
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .moveY(begin: 0, end: i.isEven ? -8 : 8, duration: (1800 + i * 300).ms, curve: Curves.easeInOut),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.accent});

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: AppRadius.rPill,
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
