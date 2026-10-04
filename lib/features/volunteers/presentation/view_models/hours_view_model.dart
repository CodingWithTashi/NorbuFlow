import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/volunteer.dart';
import 'calendar_view_model.dart';

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
