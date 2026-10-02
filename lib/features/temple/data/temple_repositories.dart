import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/backend.dart';
import '../domain/temple.dart';
import 'fake_temple_repository.dart';
import 'firebase_temple_repository.dart';

final templeRepositoryProvider = Provider<TempleRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useFirebase) return FakeTempleRepository(config.fakeLatency);
  return FirebaseTempleRepository(ref.watch(backendProvider));
});

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => FakeTeamRepository(ref.watch(appConfigProvider).fakeLatency),
);
