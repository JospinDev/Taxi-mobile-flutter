import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/storage/token_storage.dart';
import 'features/shared/providers/repository_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Session storage must be ready before the first frame (router bootstrap).
  final storage = await TokenStorage.init();

  runApp(
    ProviderScope(
      overrides: [tokenStorageProvider.overrideWithValue(storage)],
      child: const TaxiDrivingApp(),
    ),
  );
}
