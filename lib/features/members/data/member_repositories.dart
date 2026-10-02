import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/backend.dart';
import '../../../core/utils/clock.dart';
import '../domain/card.dart';
import '../domain/member.dart';
import 'fake_card_repository.dart';
import 'fake_member_repository.dart';
import 'firebase_card_repository.dart';

/// Which implementation backs this feature's repository. Swap the fake for
/// the Firebase implementation here; nothing above the data layer changes.
final memberRepositoryProvider = Provider<MemberRepository>(
  (ref) => FakeMemberRepository(
    ref.watch(appConfigProvider).fakeLatency,
    ref.watch(clockProvider),
  ),
);

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useFirebase) {
    return FakeCardRepository(config.fakeLatency, ref.watch(clockProvider));
  }
  return FirebaseCardRepository(ref.watch(backendProvider));
});
