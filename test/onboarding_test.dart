import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/storage/token_storage.dart';
import 'package:my_app/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:my_app/features/onboarding/providers/onboarding_provider.dart';
import 'package:my_app/features/shared/providers/repository_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final storage = await TokenStorage.init();
  final container = ProviderContainer(overrides: [tokenStorageProvider.overrideWithValue(storage)]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(home: OnboardingScreen()),
  ));
  await tester.pump(const Duration(milliseconds: 600));
  return container;
}

void main() {
  testWidgets('Skip (top-right) completes onboarding and persists it', (tester) async {
    final container = await _pump(tester);
    expect(container.read(onboardingDoneProvider), isFalse);
    expect(find.text('Passer'), findsOneWidget);

    await tester.tap(find.text('Passer'));
    await tester.pump();

    expect(container.read(onboardingDoneProvider), isTrue);
    expect(container.read(tokenStorageProvider).onboardingDone, isTrue);
  });

  testWidgets('Next walks through all 4 slides, last one offers "Commencer"', (tester) async {
    final container = await _pump(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700)); // rebuild after the last scroll tick
    }
    expect(find.text('Commencer'), findsOneWidget);
    await tester.tap(find.text('Commencer'));
    await tester.pump();
    expect(container.read(onboardingDoneProvider), isTrue);
    await tester.pump(const Duration(seconds: 2)); // let entrance delays elapse
  });
}
