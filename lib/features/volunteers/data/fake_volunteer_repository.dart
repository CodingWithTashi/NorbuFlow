import '../../../core/calendar/tibetan_calendar.dart';
import '../../../core/data/fake_repository.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/utils/clock.dart';
import '../domain/volunteer.dart';

/// Generates a believable rota: weekends need kitchen, front desk and
/// cleaning; weekdays need the shrine opened; practice days add Puja setup.
/// Past days are fully staffed and upcoming ones have gaps to fill.
final class FakeVolunteerRepository extends FakeRepository
    implements VolunteerRepository {
  FakeVolunteerRepository(super.latency, this._clock, this._calendar);

  static const _templates = {
    Duty.kitchen: (time: '10am–2pm', needed: 3),
    Duty.frontDesk: (time: '10am–1pm', needed: 2),
    Duty.cleaning: (time: '2–4pm', needed: 2),
    Duty.shrine: (time: '7:30–8:30am', needed: 1),
    Duty.pujaSetup: (time: '5–7pm', needed: 2),
  };

  /// People already on the rota before anyone is assigned in the app.
  static const _regulars = [
    'Jigme Norbu',
    'Yeshi Lhamo',
    'Tashi Dorje',
    'Ngawang Choedon',
    'Kelsang Pema',
    'Lhakpa Tsering',
    'Ruth Abernathy',
    'Chime Dolma',
  ];

  static const _volunteers = [
    Volunteer(
      id: 'v1',
      name: 'Sonam Wangchuk',
      email: 'sonam.w@gmail.com',
      availability: Availability.available,
      note: 'Helped 6 times this year',
      hoursThisYear: 42,
      duties: 'Kitchen, front desk',
      sinceYear: 2021,
    ),
    Volunteer(
      id: 'v2',
      name: 'Pema Lhamo',
      email: 'pema.lhamo@outlook.com',
      availability: Availability.available,
      note: 'Likes kitchen shifts',
      hoursThisYear: 38,
      duties: 'Kitchen',
      sinceYear: 2019,
    ),
    Volunteer(
      id: 'v3',
      name: 'Jigme Norbu',
      email: 'jigme.norbu@gmail.com',
      availability: Availability.busy,
      note: 'Already on another shift',
      hoursThisYear: 51,
      duties: 'Shrine, Puja setup',
      sinceYear: 2018,
    ),
    Volunteer(
      id: 'v4',
      name: 'Margaret Chen',
      email: 'margaret.chen@example.com',
      availability: Availability.available,
      note: 'Prefers mornings',
      hoursThisYear: 24,
      duties: 'Front desk',
      sinceYear: 2023,
    ),
    Volunteer(
      id: 'v5',
      name: 'Tashi Dorje',
      email: 'tashi.d@gmail.com',
      availability: Availability.away,
      note: 'Away for two weeks',
      hoursThisYear: 35,
      duties: 'Cleaning, events',
      sinceYear: 2020,
    ),
    Volunteer(
      id: 'v6',
      name: 'Yangchen Lhamo',
      email: 'yangchen.lhamo@gmail.com',
      availability: Availability.available,
      note: 'New volunteer',
      hoursThisYear: 12,
      duties: 'Kitchen',
      sinceYear: 2026,
    ),
  ];

  final Clock _clock;
  final TibetanCalendar _calendar;

  /// Names assigned through the app, by temple then shift id.
  final Map<String, Map<String, List<String>>> _assigned = {};

  List<Shift> _shiftsOn(String templeId, DateTime date) {
    final weekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final duties = [
      if (weekend) ...[Duty.kitchen, Duty.frontDesk, Duty.cleaning],
      if (!weekend) Duty.shrine,
      if (_calendar.practiceOn(date) != null) Duty.pujaSetup,
    ];
    final past = date.isBefore(_clock().dateOnly);

    return [
      for (final (index, duty) in duties.indexed)
        _shift(templeId, date, duty, index, past: past),
    ];
  }

  Shift _shift(
    String templeId,
    DateTime date,
    Duty duty,
    int index, {
    required bool past,
  }) {
    final template = _templates[duty]!;
    // Deterministic, so the same day always shows the same rota.
    final filled = past
        ? template.needed
        : (date.day * 3 + index * 5) % (template.needed + 1);
    final start = (date.day + index) % 5;
    return Shift(
      date: date,
      duty: duty,
      time: template.time,
      needed: template.needed,
      volunteers: [
        ..._regulars.sublist(start, start + filled),
        ...?_assigned[templeId]?[Shift.idFor(date, duty)],
      ],
    );
  }

  @override
  Future<List<Shift>> fetchShifts(String templeId, DateTime month) => respond(
    () => [
      for (var day = 1; day <= month.daysInMonth; day++)
        ..._shiftsOn(templeId, DateTime(month.year, month.month, day)),
    ],
  );

  @override
  Future<List<Volunteer>> fetchVolunteers(String templeId) =>
      respond(() => _volunteers);

  @override
  Future<Shift> assign(
    String templeId,
    String shiftId,
    List<String> volunteerIds,
  ) => respond(() {
    final date = parseIsoDate(shiftId.split('/').first);
    if (date == null) throw const NotFoundFailure();
    Shift current() => _shiftsOn(templeId, date).firstWhere(
      (shift) => shift.id == shiftId,
      orElse: () => throw const NotFoundFailure(),
    );

    final names = [
      for (final id in volunteerIds)
        _volunteers
            .firstWhere(
              (volunteer) => volunteer.id == id,
              orElse: () => throw const NotFoundFailure(),
            )
            .name,
    ];
    if (names.length > current().open) {
      throw const ConflictFailure(reason: ConflictReason.shiftFull);
    }
    _assigned
        .putIfAbsent(templeId, () => {})
        .putIfAbsent(shiftId, () => [])
        .addAll(names);
    return current();
  });
}
