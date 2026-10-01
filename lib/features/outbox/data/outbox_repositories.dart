import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../domain/outbox.dart';
import 'fake_outbox_repository.dart';

/// Which implementation backs this feature's repository. Swap the fake for
/// the Firebase implementation here; nothing above the data layer changes.
final outboxRepositoryProvider = Provider<OutboxRepository>(
  (ref) => FakeOutboxRepository(ref.watch(appConfigProvider).fakeLatency),
);
