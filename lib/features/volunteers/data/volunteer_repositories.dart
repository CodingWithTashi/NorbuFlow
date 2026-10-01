import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar/tibetan_calendar.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/clock.dart';
import '../domain/volunteer.dart';
import 'fake_volunteer_repository.dart';

/// Which implementation backs this feature's repository. Swap the fake for
/// the Firebase implementation here; nothing above the data layer changes.
final volunteerRepositoryProvider = Provider<VolunteerRepository>(
  (ref) => FakeVolunteerRepository(
    ref.watch(appConfigProvider).fakeLatency,
    ref.watch(clockProvider),
    ref.watch(tibetanCalendarProvider),
  ),
);
