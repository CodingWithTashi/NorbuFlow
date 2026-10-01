import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/clock.dart';
import '../domain/member.dart';
import 'fake_member_repository.dart';

/// Which implementation backs this feature's repository. Swap the fake for
/// the Firebase implementation here; nothing above the data layer changes.
final memberRepositoryProvider = Provider<MemberRepository>(
  (ref) => FakeMemberRepository(
    ref.watch(appConfigProvider).fakeLatency,
    ref.watch(clockProvider),
  ),
);
