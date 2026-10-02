import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/backend.dart';
import '../../../core/services/file_cache.dart';
import '../../../core/utils/clock.dart';
import '../domain/card.dart';
import '../domain/member.dart';
import 'fake_card_repository.dart';
import 'fake_member_repository.dart';
import 'firebase_card_repository.dart';
import 'firebase_member_repository.dart';

// One set of demo members, shared by the two fakes: a card issued to one
// shows in the list.
final _fakeMembersProvider = Provider<FakeMemberRepository>(
  (ref) => FakeMemberRepository(
    ref.watch(appConfigProvider).fakeLatency,
    ref.watch(clockProvider),
  ),
);

/// Which implementation backs this feature's repositories. Nothing above
/// the data layer changes when one is swapped.
final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  if (!ref.watch(appConfigProvider).useFirebase) {
    return ref.watch(_fakeMembersProvider);
  }
  return FirebaseMemberRepository(
    ref.watch(backendProvider),
    ref.watch(clockProvider),
  );
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useFirebase) {
    return FakeCardRepository(
      config.fakeLatency,
      ref.watch(clockProvider),
      ref.watch(_fakeMembersProvider),
    );
  }
  return FirebaseCardRepository(
    ref.watch(backendProvider),
    ref.watch(fileCacheProvider),
  );
});
