import 'dart:ui';

import 'package:intl/intl.dart';

/// Presentation formatting shared by every screen: money, dates, initials.
///
/// Dates are formatted in English in both interface languages (matching the
/// design); only the Home date has a Tibetan rendering.
abstract final class Formats {
  static const _locale = 'en_US';

  static final _whole = NumberFormat('#,##0', _locale);
  static final _mediumDate = DateFormat('MMM d, y', _locale);
  static final _longDate = DateFormat('EEEE, MMM d, y', _locale);
  static final _dayTitle = DateFormat('EEEE, MMMM d', _locale);
  static final _monthDay = DateFormat('MMMM d', _locale);
  static final _monthYear = DateFormat('MMMM y', _locale);
  static final _monthName = DateFormat('MMMM', _locale);
  static final _shortMonth = DateFormat('MMM', _locale);
  static final _weekdayDay = DateFormat('E d', _locale);
  static final _shortDay = DateFormat('E, MMM d', _locale);
  static final _time = DateFormat('h:mm a', _locale);

  /// `$1,080`
  static String money(int dollars) => '\$${_whole.format(dollars)}';

  /// `$108.00` — for receipts and totals.
  static String moneyExact(int dollars) => '${money(dollars)}.00';

  /// `Mar 14, 2027`
  static String date(DateTime date) => _mediumDate.format(date);

  /// `Wednesday, Sep 30, 2026`
  static String longDate(DateTime date) => _longDate.format(date);

  /// `Saturday, October 10`
  static String dayTitle(DateTime date) => _dayTitle.format(date);

  /// `October 19`
  static String monthDay(DateTime date) => _monthDay.format(date);

  /// `October 2026`
  static String monthYear(DateTime date) => _monthYear.format(date);

  /// `October`
  static String monthName(DateTime date) => _monthName.format(date);

  /// `Sat 10`
  static String weekdayDay(DateTime date) => _weekdayDay.format(date);

  /// `Sat, Oct 24`
  static String shortDay(DateTime date) => _shortDay.format(date);

  /// `10:42 am`
  static String time(DateTime date) => _time.format(date).toLowerCase();

  /// `Oct 4–10`, or `Sep 28–Oct 4` across months.
  static String dayRange(DateTime first, DateTime last) {
    final start = '${_shortMonth.format(first)} ${first.day}';
    if (first.month == last.month) {
      return first.day == last.day ? start : '$start–${last.day}';
    }
    return '$start–${_shortMonth.format(last)} ${last.day}';
  }

  /// Single-letter weekday headers, Sunday first.
  static const weekdayInitials = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  static const _tibetanDigits = '༠༡༢༣༤༥༦༧༨༩';
  static const _tibetanWeekdays = [
    'གཟའ་ཟླ་བ།',
    'གཟའ་མིག་དམར།',
    'གཟའ་ལྷག་པ།',
    'གཟའ་ཕུར་བུ།',
    'གཟའ་པ་སངས།',
    'གཟའ་སྤེན་པ།',
    'གཟའ་ཉི་མ།',
  ];

  /// Renders [value] with Tibetan numerals when the interface is Tibetan.
  static String digits(Object value, Locale locale) {
    final text = value.toString();
    if (locale.languageCode != 'bo') return text;
    return text.replaceAllMapped(
      RegExp(r'\d'),
      (m) => _tibetanDigits[int.parse(m[0]!)],
    );
  }

  /// Today's date for the Home header, in the interface language.
  static String homeDate(DateTime date, Locale locale) {
    if (locale.languageCode != 'bo') return longDate(date);
    String bo(int n) => digits(n, locale);
    return 'སྤྱི་ལོ་${bo(date.year)} ཟླ་${bo(date.month)} ཚེས་${bo(date.day)} '
        '${_tibetanWeekdays[date.weekday - 1]}';
  }
}

/// `Tenzin Dolkar` → `TD`.
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return '?';
  return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
}

/// `Tenzin Dolkar` → `Tenzin`.
String firstNameOf(String name) => name.trim().split(RegExp(r'\s+')).first;

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}
