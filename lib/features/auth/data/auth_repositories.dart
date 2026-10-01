import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../domain/auth_repository.dart';
import 'fake_auth_repository.dart';

/// Swap the body for the Firebase implementation when it exists.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FakeAuthRepository(ref.watch(appConfigProvider).fakeLatency),
);
