import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calendar/tibetan_calendar.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/clock.dart';
import '../domain/announcement.dart';
import 'fake_announcement_repository.dart';

/// Which implementation backs this feature's repository. Swap the fake for
/// the Firebase implementation here; nothing above the data layer changes.
final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (ref) => FakeAnnouncementRepository(
    ref.watch(appConfigProvider).fakeLatency,
    ref.watch(clockProvider),
    ref.watch(tibetanCalendarProvider),
  ),
);
