import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'date_only.dart';

export 'date_only.dart';

/// Returns the current time. Injected so date-dependent logic stays testable.
typedef Clock = DateTime Function();

final clockProvider = Provider<Clock>((ref) => DateTime.now);

/// Today's date at midnight. Watch this rather than calling the clock in a
/// widget, so "today" is consistent across a screen and overridable in tests.
final todayProvider = Provider<DateTime>(
  (ref) => ref.watch(clockProvider)().dateOnly,
);
