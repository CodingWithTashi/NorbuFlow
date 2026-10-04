import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/backend.dart';
import '../../../core/services/file_cache.dart';
import '../../../core/utils/clock.dart';
import '../domain/letter.dart';
import 'fake_letter_repository.dart';
import 'firebase_letter_repository.dart';
import 'letter_draft_store.dart';

/// Which implementation backs this feature's repository. Nothing above the
/// data layer changes when it is swapped.
final letterRepositoryProvider = Provider<LetterRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useFirebase) {
    return FakeLetterRepository(config.fakeLatency, ref.watch(clockProvider));
  }
  return FirebaseLetterRepository(
    ref.watch(backendProvider),
    ref.watch(fileCacheProvider),
  );
});

/// Where a half-written letter waits: on the device, or in memory when
/// everything is faked.
final letterDraftStoreProvider = Provider<LetterDraftStore>(
  (ref) => ref.watch(appConfigProvider).useFirebase
      ? DeviceLetterDraftStore()
      : MemoryLetterDraftStore(),
);
