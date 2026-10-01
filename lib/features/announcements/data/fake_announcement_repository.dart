import '../../../core/calendar/tibetan_calendar.dart';
import '../../../core/data/fake_repository.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/formatters.dart';
import '../domain/announcement.dart';

/// Announcement templates dated relative to today, so the samples always
/// refer to upcoming days.
final class FakeAnnouncementRepository extends FakeRepository
    implements AnnouncementRepository {
  FakeAnnouncementRepository(super.latency, this._clock, this._calendar);

  static const _groups = [
    AudienceGroup(id: 'members', name: 'All members', size: 142),
    AudienceGroup(id: 'volunteers', name: 'Volunteers', size: 24),
    AudienceGroup(id: 'sangha', name: 'Sangha & staff', size: 6),
  ];

  final Clock _clock;
  final TibetanCalendar _calendar;
  final Map<String, List<PendingAnnouncement>> _pending = {};
  final List<Announcement> sent = [];

  DateTime get _today => _clock().dateOnly;

  /// The next [weekday] strictly after today.
  DateTime _next(int weekday) {
    var date = _today.addDays(1);
    while (date.weekday != weekday) {
      date = date.addDays(1);
    }
    return date;
  }

  DateTime _nextPractice(PracticeDay practice) {
    for (var offset = 1; offset < 60; offset++) {
      final date = _today.addDays(offset);
      if (_calendar.practiceOn(date) == practice) return date;
    }
    return _today;
  }

  List<AnnouncementTemplate> _templates() {
    final puja = _nextPractice(PracticeDay.medicineBuddha);
    final teaching = _next(DateTime.saturday);
    final festival = _nextPractice(PracticeDay.fullMoon);
    final closure = _next(DateTime.tuesday);
    return [
      AnnouncementTemplate(
        id: 'puja',
        name: 'Puja schedule',
        title: 'Medicine Buddha Puja',
        when: '${Formats.dayTitle(puja)} · 7:00 pm',
        details:
            'Join the Sangha for Medicine Buddha prayers for health and '
            'healing. Names for prayers can be given at the front desk. All '
            'are welcome.',
      ),
      AnnouncementTemplate(
        id: 'teaching',
        name: 'Teaching',
        title: 'Teaching on the Four Noble Truths',
        when: '${Formats.dayTitle(teaching)} · 2:00 pm',
        details:
            'Geshe-la will teach in English and Tibetan. Tea is served '
            'afterwards. Free for members.',
      ),
      AnnouncementTemplate(
        id: 'festival',
        name: 'Festival',
        title: 'Full Moon butter lamp offering',
        when: '${Formats.dayTitle(festival)} · all day',
        details:
            'Celebrate the full moon with prayers and butter lamp offerings. '
            'Lamps can be sponsored at the front desk.',
      ),
      AnnouncementTemplate(
        id: 'closure',
        name: 'Closure',
        title: 'Temple closed for cleaning',
        when: Formats.dayTitle(closure),
        details:
            'The temple will be closed for deep cleaning. Morning prayers '
            'continue online.',
      ),
      AnnouncementTemplate(
        id: 'fundraiser',
        name: 'Fundraiser',
        title: 'New shrine hall fund',
        when: 'Until December 31',
        details:
            'Help us build our new shrine hall. Every offering, large or '
            'small, is welcome and receives a tax receipt.',
      ),
    ];
  }

  List<PendingAnnouncement> _pendingFor(String templeId) =>
      _pending.putIfAbsent(
        templeId,
        () => [
          PendingAnnouncement(
            id: 'a1',
            templateName: 'Teaching',
            title: 'Teaching on the Four Noble Truths',
            when: Formats.shortDay(_next(DateTime.saturday)),
            author: 'Pema Lhamo',
            audience: 'All members',
            details:
                'Geshe-la will teach in English and Tibetan. Tea is served '
                'afterwards. Free for members.',
          ),
          PendingAnnouncement(
            id: 'a2',
            templateName: 'Closure',
            title: 'Temple closed for cleaning',
            when: Formats.shortDay(_next(DateTime.tuesday)),
            author: 'Sonam Wangchuk',
            audience: 'Everyone',
            details:
                'The temple will be closed for deep cleaning. Morning '
                'prayers continue online.',
          ),
        ],
      );

  @override
  Future<List<AnnouncementTemplate>> fetchTemplates(String templeId) =>
      respond(_templates);

  @override
  Future<List<AudienceGroup>> fetchAudienceGroups(String templeId) =>
      respond(() => _groups);

  @override
  Future<void> send(String templeId, Announcement announcement) =>
      respond(() => sent.add(announcement));

  @override
  Future<List<PendingAnnouncement>> fetchPending(String templeId) =>
      respond(() => List.unmodifiable(_pendingFor(templeId)));

  @override
  Future<void> approve(String templeId, String announcementId) =>
      respond(() => _resolve(templeId, announcementId));

  @override
  Future<void> requestChanges(String templeId, String announcementId) =>
      respond(() => _resolve(templeId, announcementId));

  void _resolve(String templeId, String announcementId) {
    final pending = _pendingFor(templeId);
    final index = pending.indexWhere((a) => a.id == announcementId);
    if (index < 0) throw const NotFoundFailure();
    pending.removeAt(index);
  }
}
