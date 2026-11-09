import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'core/storage/token_storage.dart';
import 'features/shared/providers/repository_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // French dates everywhere ("lundi 6 novembre", "6 nov. · 14:32").
  Intl.defaultLocale = 'fr_FR';
  await initializeDateFormatting('fr_FR');

  // Session storage must be ready before the first frame (router bootstrap).
  final storage = await TokenStorage.init();

  runApp(
    ProviderScope(
      overrides: [tokenStorageProvider.overrideWithValue(storage)],
      child: const TaxiDrivingApp(),
    ),
  );
}
