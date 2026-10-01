import 'package:flutter/foundation.dart';

import '../../../core/utils/date_only.dart';

enum Duty { kitchen, frontDesk, cleaning, shrine, pujaSetup }

/// One duty on one day, and who has been asked to cover it.
@immutable
class Shift {
  const Shift({
    required this.date,
    required this.duty,
    required this.time,
    required this.needed,
    required this.volunteers,
  });

  final DateTime date;
  final Duty duty;

  /// Display time range, e.g. "10am–2pm".
  final String time;

  /// How many people the shift needs.
  final int needed;

  /// Names of the volunteers already assigned.
  final List<String> volunteers;

  /// Stable key: `2026-10-10/kitchen`.
  static String idFor(DateTime date, Duty duty) =>
      '${date.isoDate}/${duty.name}';

  String get id => idFor(date, duty);

  /// Places still to fill.
  int get open => needed > volunteers.length ? needed - volunteers.length : 0;

  bool get isFull => open == 0;
}

enum Availability { available, busy, away }

@immutable
class Volunteer {
  const Volunteer({
    required this.id,
    required this.name,
    required this.email,
    required this.availability,
    required this.note,
    required this.hoursThisYear,
    required this.duties,
    required this.sinceYear,
  });

  final String id;
  final String name;
  final String email;
  final Availability availability;

  /// A line the coordinator sees when assigning ("Prefers mornings").
  final String note;
  final int hoursThisYear;

  /// What they usually help with, e.g. "Kitchen, front desk".
  final String duties;
  final int sinceYear;
}

abstract interface class VolunteerRepository {
  /// Every shift in the calendar month containing [month].
  Future<List<Shift>> fetchShifts(String templeId, DateTime month);

  Future<List<Volunteer>> fetchVolunteers(String templeId);

  /// Adds the volunteers to the shift. Fails with
  /// `ConflictFailure(shiftFull)` if it needs fewer people than given.
  Future<Shift> assign(
    String templeId,
    String shiftId,
    List<String> volunteerIds,
  );
}
