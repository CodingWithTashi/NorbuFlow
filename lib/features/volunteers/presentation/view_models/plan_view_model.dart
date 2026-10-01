import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/clock.dart';
import 'calendar_view_model.dart';

enum PlanMode { week, month }

/// The days of [month] grouped into Sunday-to-Saturday weeks. The first and
/// last weeks are short when the month does not start or end on a boundary.
List<List<DateTime>> weeksOfMonth(DateTime month) {
  final weeks = <List<DateTime>>[];
  var week = <DateTime>[];
  for (var day = 1; day <= month.daysInMonth; day++) {
    final date = DateTime(month.year, month.month, day);
    week.add(date);
    if (date.weekday == DateTime.saturday) {
      weeks.add(week);
      week = [];
    }
  }
  if (week.isNotEmpty) weeks.add(week);
  return weeks;
}

@immutable
class PlanState {
  const PlanState({
    required this.month,
    required this.weeks,
    required this.mode,
    required this.weekIndex,
  });

  final DateTime month;
  final List<List<DateTime>> weeks;
  final PlanMode mode;
  final int weekIndex;

  List<DateTime> get week => weeks[weekIndex];

  PlanState copyWith({PlanMode? mode, int? weekIndex}) => PlanState(
    month: month,
    weeks: weeks,
    mode: mode ?? this.mode,
    weekIndex: weekIndex ?? this.weekIndex,
  );
}

/// The printable volunteer plan for the month open in the calendar.
class PlanViewModel extends Notifier<PlanState> {
  @override
  PlanState build() {
    final calendar = ref.watch(calendarViewModelProvider);
    final weeks = weeksOfMonth(calendar.month);
    // Start on the week of the day the coordinator was looking at.
    final index = weeks.indexWhere(
      (week) => week.any((day) => day.isSameDay(calendar.selectedDay)),
    );
    return PlanState(
      month: calendar.month,
      weeks: weeks,
      mode: PlanMode.month,
      weekIndex: index < 0 ? 0 : index,
    );
  }

  void setMode(PlanMode mode) => state = state.copyWith(mode: mode);

  void setWeek(int index) => state = state.copyWith(weekIndex: index);
}

final planViewModelProvider =
    NotifierProvider.autoDispose<PlanViewModel, PlanState>(PlanViewModel.new);
