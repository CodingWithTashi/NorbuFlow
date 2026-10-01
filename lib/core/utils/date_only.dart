/// Calendar-date helpers. Pure Dart, so domain entities can use them.
extension DateOnly on DateTime {
  /// This date at midnight, local time.
  DateTime get dateOnly => DateTime(year, month, day);

  DateTime get firstOfMonth => DateTime(year, month);

  int get daysInMonth => DateTime(year, month + 1, 0).day;

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  bool isSameMonth(DateTime other) =>
      year == other.year && month == other.month;

  /// Calendar-day arithmetic. Unlike `add(Duration(days: n))` this cannot
  /// drift across a daylight-saving change.
  DateTime addDays(int days) => DateTime(year, month, day + days);

  /// The same day one year later (Feb 29 rolls to Mar 1).
  DateTime get plusOneYear => DateTime(year + 1, month, day);

  /// Stable key for routes and maps: `2026-10-19`.
  String get isoDate =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}

/// Parses a `yyyy-MM-dd` key produced by [DateOnly.isoDate].
DateTime? parseIsoDate(String? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  return parsed?.dateOnly;
}
