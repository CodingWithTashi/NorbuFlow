import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_preferences.dart';
import 'in_memory_preferences_repository.dart';

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => InMemoryPreferencesRepository(),
);
