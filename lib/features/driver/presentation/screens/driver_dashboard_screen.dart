import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:my_app/core/config/app_config.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_space.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/data/models/driver_profile_model.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/stylized_map.dart';

/// DRIVER dashboard — map, big Disponible/Hors ligne toggle, stats.
///
/// While `available`, the app pushes the GPS position to
/// `PATCH /accounts/drivers/me/location/` every [AppConfig.locationPushInterval]
/// (spec: 5–10 s). Permission is requested once when going online; if denied
/// the driver stays online but sees a warning (position not shared).
class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() =>
      _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends ConsumerState<DriverDashboardScreen> {
  Timer? _gpsTimer;
  bool _toggling = false;
  bool _locationDenied = false;

  DriverProfile? get _profile => ref.read(currentDriverProfileProvider);
  bool get _online => _profile?.status == DriverStatus.available;

  @override
  void initState() {
    super.initState();
    // Refresh profile/stats when landing on the dashboard.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).refreshDriverProfile();
    });
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleOnline() async {
    if (_toggling) return;
    final goingOnline = !_online;

    if (goingOnline) {
      final granted = await _ensureLocationPermission();
      if (!granted) {
        setState(() => _locationDenied = true);
        if (!mounted) return;
        final continueAnyway = await confirmDialog(
          context,
          title: 'Position indisponible',
          message:
              'Sans localisation, les clients ne pourront pas vous '
              'trouver. Rendre le GPS activé ?',
          confirmLabel: 'Réessayer',
          cancelLabel: 'Continuer quand même',
          icon: Icons.location_off_rounded,
        );
        if (!continueAnyway && mounted) setState(() => _locationDenied = false);
      } else {
        setState(() => _locationDenied = false);
      }
    }

    setState(() => _toggling = true);
    try {
      final status = await ref
          .read(authRepositoryProvider)
          .updateStatus(goingOnline ? 'available' : 'offline');
      await ref.read(authControllerProvider.notifier).refreshDriverProfile();
      if (!mounted) return;
      AppToast.success(
        context,
        status == 'available'
            ? 'Vous êtes maintenant disponible 🟢'
            : 'Vous êtes hors ligne.',
      );
      _syncGpsLoop();
    } catch (e) {
      if (mounted) AppToast.apiError(context, e);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<bool> _ensureLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  /// Starts/stops the GPS push loop according to the driver status.
  void _syncGpsLoop() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
    if (!_online) return;
    _pushLocation(); // immediate first push
    _gpsTimer = Timer.periodic(AppConfig.locationPushInterval, (_) {
      _pushLocation();
    });
  }

  Future<void> _pushLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await ref
          .read(authRepositoryProvider)
          .updateLocation(lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      // Position push must never crash the dashboard; next tick retries.
    }
  }

  bool _gpsStarted = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentDriverProfileProvider);
    final user = ref.watch(currentUserProvider);
    final online = profile?.status == DriverStatus.available;
    final top = MediaQuery.of(context).padding.top;

    // Keep the GPS loop in sync with status (e.g. approval granted elsewhere).
    if (!_gpsStarted && online) {
      _gpsStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncGpsLoop());
    } else if (!online && _gpsStarted) {
      _gpsStarted = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncGpsLoop());
    }

    return Scaffold(
      body: Stack(
        children: [
          StylizedMap(
            accent: online ? AppColors.emerald : AppColors.muted,
            label: online
                ? 'En ligne · position partagée'
                : 'Hors ligne · vous ne recevez pas de courses',
          ),

          // ── Top: greeting + online badge ──────────────────────────
          Positioned(
            top: top + 12,
            left: AppSpace.md,
            right: AppSpace.md,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Salut${user != null ? ', ${user.firstName ?? user.username}' : ''} 👋',
                        style: AppTypography.h2.copyWith(fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        online
                            ? 'Vous êtes en ligne, bonne route !'
                            : 'Passez en ligne pour recevoir des courses.',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                _StatusBadge(online: online),
              ],
            ),
          ),

          // ── Bottom: control panel ────────────────────────────────
          Positioned(
            left: AppSpace.md,
            right: AppSpace.md,
            bottom: AppSpace.md,
            child: _ControlPanel(
              online: online,
              profile: profile,
              toggling: _toggling,
              locationDenied: _locationDenied,
              onToggle: _toggleOnline,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: online ? AppColors.emerald : AppColors.surface,
        borderRadius: AppRadius.rPill,
        boxShadow: online
            ? const [
                BoxShadow(
                  color: Color(0x66059669),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ]
            : AppShadow.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: online ? Colors.white : AppColors.faint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            online ? 'EN LIGNE' : 'HORS LIGNE',
            style: AppTypography.overline.copyWith(
              color: online ? Colors.white : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet-like panel: stats (rating, rides, revenue) + big online toggle.
class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.online,
    required this.profile,
    required this.toggling,
    required this.locationDenied,
    required this.onToggle,
  });

  final bool online;
  final DriverProfile? profile;
  final bool toggling;
  final bool locationDenied;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpace.card,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rXl,
        boxShadow: AppShadow.floating,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stats row
          Row(
            children: [
              _stat(
                Icons.star_rounded,
                Formatters.rating(profile?.rating),
                'Note',
                AppColors.brandDeep,
                AppColors.brandSoft,
              ),
              const SizedBox(width: 10),
              _stat(
                Icons.route_rounded,
                '${profile?.totalRides ?? 0}',
                'Courses',
                AppColors.info,
                AppColors.infoSoft,
              ),
              const SizedBox(width: 10),
              _stat(
                Icons.payments_outlined,
                '—',
                'Revenus du jour',
                AppColors.emeraldDeep,
                AppColors.emeraldSoft,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),

          if (locationDenied) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: AppSpace.sm),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: AppRadius.rMd,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_off_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Position non partagée — activez la localisation.',
                      style: AppTypography.caption.copyWith(
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Big toggle
          GestureDetector(
            onTap: toggling ? null : onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              height: 60,
              decoration: BoxDecoration(
                gradient: online ? AppColors.emeraldGradient : null,
                color: online ? null : AppColors.ink,
                borderRadius: AppRadius.rMd,
                boxShadow: online
                    ? const [
                        BoxShadow(
                          color: Color(0x59059669),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ]
                    : const [
                        BoxShadow(
                          color: Color(0x330F172A),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (toggling)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(
                      online
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  const SizedBox(width: 10),
                  Text(
                    toggling
                        ? 'Mise à jour…'
                        : online
                        ? 'Je me déconnecte'
                        : 'Je suis disponible',
                    style: AppTypography.button.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    IconData icon,
    String value,
    String label,
    Color color,
    Color bg,
  ) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.rMd),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTypography.h3.copyWith(
              fontSize: 17,
              color: AppColors.ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}
