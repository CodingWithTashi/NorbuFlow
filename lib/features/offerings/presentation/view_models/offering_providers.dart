import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../temple/presentation/view_models/temple_session.dart';
import '../../data/offering_repositories.dart';
import '../../domain/offering.dart';

final ceremoniesProvider = FutureProvider.autoDispose<List<Ceremony>>((ref) {
  final templeId = ref.watch(activeTempleIdProvider);
  return ref.watch(offeringRepositoryProvider).fetchCeremonies(templeId);
});

/// Route value that means "the most recent receipt" rather than a number.
const latestReceiptKey = 'latest';

/// A receipt by number, or the newest one for [latestReceiptKey]. Null only
/// when the temple has issued no receipts yet.
final receiptProvider = FutureProvider.autoDispose.family<Receipt?, String>((
  ref,
  number,
) {
  final templeId = ref.watch(activeTempleIdProvider);
  final repository = ref.watch(offeringRepositoryProvider);
  return number == latestReceiptKey
      ? repository.fetchLatestReceipt(templeId)
      : repository.fetchReceipt(templeId, number);
});

final prayerListsProvider = FutureProvider.autoDispose<List<PrayerList>>((ref) {
  final templeId = ref.watch(activeTempleIdProvider);
  return ref.watch(offeringRepositoryProvider).fetchPrayerLists(templeId);
});
