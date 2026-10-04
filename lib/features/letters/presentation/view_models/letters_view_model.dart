import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/command.dart';
import '../../../../core/error/result.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../data/letter_repositories.dart';
import '../../domain/letter.dart';

/// The current temple's support letters, the newest first. The list and the
/// form both read from here, so a letter just issued shows at once.
class LettersViewModel extends AsyncNotifier<List<Letter>> {
  late String _templeId;

  @override
  Future<List<Letter>> build() {
    _templeId = ref.watch(activeTempleIdProvider);
    return ref.watch(letterRepositoryProvider).fetchLetters(_templeId);
  }

  /// Fetches the list again: another admin may have issued one. If that
  /// fails, what is shown stays and the failure is a toast.
  Future<void> refresh() async {
    final result = await runCommand(
      ref,
      () => ref.read(letterRepositoryProvider).fetchLetters(_templeId),
      source: 'letters.refresh',
    );
    if (result case Ok(:final value) when ref.mounted) {
      state = AsyncData(value);
    }
  }

  /// Takes in a letter issued on the form, as the newest.
  void put(Letter letter) {
    // Not loaded yet: the list will include it when it is.
    if (!state.hasValue) {
      ref.invalidateSelf();
      return;
    }
    state = AsyncData([
      letter,
      for (final existing in state.requireValue)
        if (existing.id != letter.id) existing,
    ]);
  }
}

final lettersProvider = AsyncNotifierProvider<LettersViewModel, List<Letter>>(
  LettersViewModel.new,
);

/// One letter by id, or null if the current temple has none with it.
final letterProvider = Provider.autoDispose.family<AsyncValue<Letter?>, String>(
  (ref, letterId) => ref
      .watch(lettersProvider)
      .whenData(
        (letters) => letters.where((l) => l.id == letterId).firstOrNull,
      ),
);

/// Search text on the letters list.
class LetterSearchViewModel extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final letterSearchProvider =
    NotifierProvider.autoDispose<LetterSearchViewModel, String>(
      LetterSearchViewModel.new,
    );

@immutable
class LetterListState {
  const LetterListState({
    required this.query,
    required this.total,
    required this.visible,
  });

  final String query;

  /// Letters the temple has issued, before filtering.
  final int total;
  final List<Letter> visible;

  bool get isSearching => query.trim().isNotEmpty;
}

final letterListProvider = Provider.autoDispose<AsyncValue<LetterListState>>((
  ref,
) {
  final query = ref.watch(letterSearchProvider);
  return ref
      .watch(lettersProvider)
      .whenData(
        (letters) => LetterListState(
          query: query,
          total: letters.length,
          visible: letters.where((l) => l.matches(query)).toList(),
        ),
      );
});

/// On tablets the letters screen shows the chosen letter beside the list
/// instead of navigating to it.
class SelectedLetterViewModel extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(currentTempleIdProvider);
    return null;
  }

  void select(String letterId) => state = letterId;
}

final selectedLetterProvider =
    NotifierProvider<SelectedLetterViewModel, String?>(
      SelectedLetterViewModel.new,
    );
