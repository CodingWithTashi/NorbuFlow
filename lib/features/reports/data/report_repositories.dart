import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../domain/report.dart';
import 'fake_report_repository.dart';

/// Which implementation backs this feature's repository. Swap the fake for
/// the Firebase implementation here; nothing above the data layer changes.
final reportRepositoryProvider = Provider<ReportRepository>(
  (ref) => FakeReportRepository(ref.watch(appConfigProvider).fakeLatency),
);
