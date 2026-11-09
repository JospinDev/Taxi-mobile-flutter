import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/repository_providers.dart';

/// Whether the first-launch onboarding was completed or skipped.
class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(tokenStorageProvider).onboardingDone;

  Future<void> complete() async {
    await ref.read(tokenStorageProvider).setOnboardingDone();
    state = true;
  }
}

final onboardingDoneProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
