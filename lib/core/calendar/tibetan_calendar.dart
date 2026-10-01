import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tibetan_calendar/tibetan_calendar.dart' as phugpa;

import '../utils/clock.dart';

/// A date in the Tibetan lunar calendar.
@immutable
class TibetanDay {
  const TibetanDay({required this.month, required this.day});

  final int month;
  final int day;

  @override
  bool operator ==(Object other) =>
      other is TibetanDay && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(month, day);
}

/// Monthly practice days, keyed by the lunar day they fall on.
enum PracticeDay {
  medicineBuddha(8),
  guruRinpoche(10),
  fullMoon(15),
  dakini(25),
  newMoon(30);

  const PracticeDay(this.lunarDay);

  final int lunarDay;

  static PracticeDay? forLunarDay(int day) {
    for (final practice in values) {
      if (practice.lunarDay == day) return practice;
    }
    return null;
  }
}

/// Converts Western dates to Tibetan ones. An interface so the rest of the
/// app does not depend on a particular calendar library.
abstract interface class TibetanCalendar {
  TibetanDay dayOf(DateTime date);
}

extension TibetanCalendarQueries on TibetanCalendar {
  PracticeDay? practiceOn(DateTime date) =>
      PracticeDay.forLunarDay(dayOf(date).day);

  /// The next [count] practice days on or after [from].
  List<DateTime> upcomingPracticeDays(DateTime from, {int count = 3}) {
    final found = <DateTime>[];
    // Two lunar months is always enough to find a handful of practice days.
    for (var offset = 0; offset < 60 && found.length < count; offset++) {
      final date = from.dateOnly.addDays(offset);
      if (practiceOn(date) != null) found.add(date);
    }
    return found;
  }
}

/// [TibetanCalendar] backed by the `tibetan_calendar` package (Phugpa
/// tradition). Conversions are cached because each one is a binary search.
final class PhugpaTibetanCalendar implements TibetanCalendar {
  final Map<String, TibetanDay> _cache = {};

  @override
  TibetanDay dayOf(DateTime date) {
    final day = date.dateOnly;
    return _cache.putIfAbsent(day.isoDate, () {
      final converted = phugpa.getDayFromWestern(day);
      return TibetanDay(month: converted.month.month, day: converted.day);
    });
  }
}

final tibetanCalendarProvider = Provider<TibetanCalendar>(
  (ref) => PhugpaTibetanCalendar(),
);
