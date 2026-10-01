import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/command.dart';
import '../../../../core/utils/clock.dart';
import '../../../assistant/data/assistant_repositories.dart';
import '../../../assistant/domain/writing_assistant.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../domain/letter_composer.dart';
import '../../domain/volunteer.dart';
import 'calendar_view_model.dart';

@immutable
class LetterState {
  const LetterState({
    required this.volunteers,
    required this.volunteer,
    required this.type,
    required this.text,
    this.improving = false,
  });

  final List<Volunteer> volunteers;
  final Volunteer volunteer;
  final LetterType type;

  /// The draft, editable by the coordinator.
  final String text;
  final bool improving;

  LetterState copyWith({
    Volunteer? volunteer,
    LetterType? type,
    String? text,
    bool? improving,
  }) {
    return LetterState(
      volunteers: volunteers,
      volunteer: volunteer ?? this.volunteer,
      type: type ?? this.type,
      text: text ?? this.text,
      improving: improving ?? this.improving,
    );
  }
}

/// Drafts a volunteer letter. [_volunteerId] preselects a volunteer when the
/// screen is opened from their row in Volunteer Hours.
class LetterViewModel extends AsyncNotifier<LetterState> {
  LetterViewModel(this._volunteerId);

  final String? _volunteerId;

  @override
  Future<LetterState> build() async {
    final volunteers = await ref.watch(volunteersProvider.future);
    final volunteer = volunteers.firstWhere(
      (v) => v.id == _volunteerId,
      orElse: () => volunteers.first,
    );
    return LetterState(
      volunteers: volunteers,
      volunteer: volunteer,
      type: LetterType.thanks,
      text: _compose(LetterType.thanks, volunteer),
    );
  }

  LetterState get _state => state.requireValue;

  String _compose(LetterType type, Volunteer volunteer) {
    final temple = ref.read(currentTempleProvider);
    if (temple == null) throw const NoTempleSelectedFailure();
    return LetterComposer.compose(
      type: type,
      volunteer: volunteer,
      temple: temple,
      today: ref.read(todayProvider),
    );
  }

  /// Choosing a volunteer or type starts a fresh draft for them.
  void selectVolunteer(Volunteer volunteer) => state = AsyncData(
    _state.copyWith(
      volunteer: volunteer,
      text: _compose(_state.type, volunteer),
    ),
  );

  void selectType(LetterType type) => state = AsyncData(
    _state.copyWith(type: type, text: _compose(type, _state.volunteer)),
  );

  void setText(String text) => state = AsyncData(_state.copyWith(text: text));

  /// Returns whether the wording was improved. On failure the draft is left
  /// exactly as it was.
  Future<bool> improve() async {
    if (_state.improving) return false;
    state = AsyncData(_state.copyWith(improving: true));
    final draft = _state.text;
    final result = await runCommand(
      ref,
      () => ref
          .read(writingAssistantProvider)
          .improve(draft, WritingKind.volunteerLetter),
      source: 'letter.improve',
    );
    if (!ref.mounted) return false;
    state = AsyncData(
      _state.copyWith(improving: false, text: result.valueOrNull),
    );
    return result.isOk;
  }
}

final letterViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<LetterViewModel, LetterState, String?>(LetterViewModel.new);

/// Volunteers ranked by hours given this year, for Volunteer Hours.
@immutable
class HoursSummary {
  const HoursSummary({required this.ranked, required this.total});

  final List<Volunteer> ranked;
  final int total;

  int get top => ranked.isEmpty ? 0 : ranked.first.hoursThisYear;
}

final hoursSummaryProvider = Provider.autoDispose<AsyncValue<HoursSummary>>((
  ref,
) {
  return ref.watch(volunteersProvider).whenData((volunteers) {
    final ranked = [...volunteers]
      ..sort((a, b) => b.hoursThisYear.compareTo(a.hoursThisYear));
    return HoursSummary(
      ranked: ranked,
      total: ranked.fold(0, (sum, v) => sum + v.hoursThisYear),
    );
  });
});
