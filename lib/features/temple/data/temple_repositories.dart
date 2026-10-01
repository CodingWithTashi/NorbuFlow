import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../domain/temple.dart';
import 'fake_temple_repository.dart';

final templeRepositoryProvider = Provider<TempleRepository>(
  (ref) => FakeTempleRepository(ref.watch(appConfigProvider).fakeLatency),
);

final teamRepositoryProvider = Provider<TeamRepository>(
  (ref) => FakeTeamRepository(ref.watch(appConfigProvider).fakeLatency),
);
