import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/clock.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../data/volunteer_repositories.dart';
import '../../domain/volunteer.dart';

/// Shifts for one calendar month. Keyed by the first of the month.
final monthShiftsProvider = FutureProvider.autoDispose
    .family<List<Shift>, DateTime>((ref, month) {
      final templeId = ref.watch(activeTempleIdProvider);
      return ref
          .watch(volunteerRepositoryProvider)
          .fetchShifts(templeId, month.firstOfMonth);
    });

/// Shifts on a single day, read from its month.
final dayShiftsProvider = Provider.autoDispose
    .family<AsyncValue<List<Shift>>, DateTime>((ref, day) {
      return ref
          .watch(monthShiftsProvider(day.firstOfMonth))
          .whenData(
            (shifts) => shifts.where((s) => s.date.isSameDay(day)).toList(),
          );
    });

final volunteersProvider = FutureProvider.autoDispose<List<Volunteer>>((ref) {
  final templeId = ref.watch(activeTempleIdProvider);
  return ref.watch(volunteerRepositoryProvider).fetchVolunteers(templeId);
});

@immutable
class CalendarState {
  const CalendarState({required this.month, required this.selectedDay});

  /// First day of the month on screen.
  final DateTime month;
  final DateTime selectedDay;
}

class CalendarViewModel extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    final today = ref.watch(todayProvider);
    return CalendarState(month: today.firstOfMonth, selectedDay: today);
  }

  void selectDay(DateTime day) =>
      state = CalendarState(month: day.firstOfMonth, selectedDay: day.dateOnly);

  void previousMonth() => _showMonth(-1);

  void nextMonth() => _showMonth(1);

  void _showMonth(int delta) {
    final month = DateTime(state.month.year, state.month.month + delta);
    final today = ref.read(todayProvider);
    // Land on today when returning to the current month, else on the 1st.
    state = CalendarState(
      month: month,
      selectedDay: month.isSameMonth(today) ? today : month,
    );
  }
}

final calendarViewModelProvider =
    NotifierProvider<CalendarViewModel, CalendarState>(CalendarViewModel.new);
