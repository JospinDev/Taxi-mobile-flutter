import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notifications/presentation/widgets/in_app_notification_host.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget — wires theme, router and animated page transitions.
///
/// The `ProviderScope` (with the [TokenStorage] override) lives in `main.dart`.
class TaxiDrivingApp extends ConsumerWidget {
  const TaxiDrivingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Taxi Driving',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: MediaQuery(
            // Predictable typography across devices (Android font scaling).
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1)),
            // In-app popups float above every screen.
            child: InAppNotificationHost(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
