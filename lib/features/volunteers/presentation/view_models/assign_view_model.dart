import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/command.dart';
import '../../../../core/utils/async_combine.dart';
import '../../../../core/utils/clock.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../data/volunteer_repositories.dart';
import '../../domain/volunteer.dart';
import 'calendar_view_model.dart';

/// A completed assignment, shown on the confirmation.
@immutable
class Assignment {
  const Assignment({required this.shift, required this.names});

  final Shift shift;
  final List<String> names;
}

@immutable
class AssignState {
  const AssignState({
    this.shiftId,
    this.picked = const {},
    this.query = '',
    this.submitting = false,
    this.done,
  });

  /// The shift being filled; null means "the first one with space".
  final String? shiftId;

  /// Ids of the volunteers ticked so far.
  final Set<String> picked;
  final String query;
  final bool submitting;
  final Assignment? done;

  AssignState copyWith({
    Set<String>? picked,
    String? query,
    bool? submitting,
    Assignment? done,
  }) {
    return AssignState(
      shiftId: shiftId,
      picked: picked ?? this.picked,
      query: query ?? this.query,
      submitting: submitting ?? this.submitting,
      done: done ?? this.done,
    );
  }
}

/// Why a tap on a volunteer did or did not tick them.
enum PickOutcome { changed, away, alreadyOnShift, shiftFull }

/// A volunteer as shown in the assign list.
@immutable
class VolunteerChoice {
  const VolunteerChoice({
    required this.volunteer,
    required this.availability,
    required this.alreadyOnShift,
    required this.picked,
  });

  final Volunteer volunteer;

  /// Their availability for this shift (busy if they are already on it).
  final Availability availability;
  final bool alreadyOnShift;
  final bool picked;

  bool get selectable => !alreadyOnShift && availability != Availability.away;
}

/// Everything the Assign screen shows for one day.
@immutable
class AssignBoard {
  const AssignBoard({
    required this.openShifts,
    required this.current,
    required this.choices,
  });

  /// Shifts on the day that still need people.
  final List<Shift> openShifts;

  /// The shift being filled, or null if every shift is full.
  final Shift? current;
  final List<VolunteerChoice> choices;
}

class AssignViewModel extends Notifier<AssignState> {
  AssignViewModel(this._day);

  final DateTime _day;

  @override
  AssignState build() => const AssignState();

  void selectShift(String shiftId) =>
      state = AssignState(shiftId: shiftId, query: state.query);

  void setQuery(String query) => state = state.copyWith(query: query);

  /// Ticks or unticks a volunteer, explaining via the outcome when the tap
  /// could not be honoured.
  PickOutcome toggle(VolunteerChoice choice, Shift shift) {
    if (choice.availability == Availability.away) return PickOutcome.away;
    if (choice.alreadyOnShift) return PickOutcome.alreadyOnShift;

    final id = choice.volunteer.id;
    if (state.picked.contains(id)) {
      state = state.copyWith(picked: {...state.picked}..remove(id));
    } else if (state.picked.length >= shift.open) {
      return PickOutcome.shiftFull;
    } else {
      state = state.copyWith(picked: {...state.picked, id});
    }
    return PickOutcome.changed;
  }

  Future<void> confirm(AssignBoard board) async {
    final shift = board.current;
    if (shift == null || state.picked.isEmpty || state.submitting) return;

    final names = [
      for (final choice in board.choices)
        if (state.picked.contains(choice.volunteer.id)) choice.volunteer.name,
    ];
    state = state.copyWith(submitting: true);
    final templeId = ref.read(activeTempleIdProvider);
    final result = await runCommand(
      ref,
      () => ref
          .read(volunteerRepositoryProvider)
          .assign(templeId, shift.id, state.picked.toList()),
      source: 'volunteers.assign',
    );
    if (!ref.mounted) return;
    if (result.valueOrNull case final updated?) {
      // The calendar and plan read the month; make them refetch.
      ref.invalidate(monthShiftsProvider(_day.firstOfMonth));
      state = AssignState(
        done: Assignment(shift: updated, names: names),
      );
    } else {
      state = state.copyWith(submitting: false);
    }
  }
}

final assignViewModelProvider = NotifierProvider.autoDispose
    .family<AssignViewModel, AssignState, DateTime>(AssignViewModel.new);

final assignBoardProvider = Provider.autoDispose
    .family<AsyncValue<AssignBoard>, DateTime>((ref, day) {
      final state = ref.watch(assignViewModelProvider(day));
      return combineAsync(
        ref.watch(dayShiftsProvider(day)),
        ref.watch(volunteersProvider),
        (shifts, volunteers) => _board(state, shifts, volunteers),
      );
    });

AssignBoard _board(
  AssignState state,
  List<Shift> shifts,
  List<Volunteer> volunteers,
) {
  final open = shifts.where((shift) => !shift.isFull).toList();
  final current =
      open.where((shift) => shift.id == state.shiftId).firstOrNull ??
      open.firstOrNull;
  final query = state.query.trim().toLowerCase();

  VolunteerChoice choiceFor(Volunteer volunteer) {
    final onShift = current?.volunteers.contains(volunteer.name) ?? false;
    return VolunteerChoice(
      volunteer: volunteer,
      availability: onShift ? Availability.busy : volunteer.availability,
      alreadyOnShift: onShift,
      picked: state.picked.contains(volunteer.id),
    );
  }

  return AssignBoard(
    openShifts: open,
    current: current,
    choices: [
      for (final volunteer in volunteers)
        if (query.isEmpty || volunteer.name.toLowerCase().contains(query))
          choiceFor(volunteer),
    ],
  );
}
