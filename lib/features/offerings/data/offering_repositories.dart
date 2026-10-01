import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar/tibetan_calendar.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/clock.dart';
import '../domain/offering.dart';
import 'fake_offering_repository.dart';

/// Which implementation backs this feature's repository. Swap the fake for
/// the Firebase implementation here; nothing above the data layer changes.
final offeringRepositoryProvider = Provider<OfferingRepository>(
  (ref) => FakeOfferingRepository(
    ref.watch(appConfigProvider).fakeLatency,
    ref.watch(clockProvider),
    ref.watch(tibetanCalendarProvider),
  ),
);
