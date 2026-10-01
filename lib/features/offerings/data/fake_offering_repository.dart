import '../../../core/calendar/tibetan_calendar.dart';
import '../../../core/data/fake_repository.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/utils/clock.dart';
import '../domain/offering.dart';

final class FakeOfferingRepository extends FakeRepository
    implements OfferingRepository {
  FakeOfferingRepository(super.latency, this._clock, this._calendar);

  static const medicineBuddha = Ceremony(
    id: 'medicine-buddha',
    nameEn: 'Medicine Buddha Puja',
    nameBo: 'སྨན་བླའི་མཆོད་པ།',
  );
  static const greenTara = Ceremony(
    id: 'green-tara',
    nameEn: 'Green Tara Puja',
    nameBo: 'སྒྲོལ་ལྗང་མཆོད་པ།',
  );
  static const guruRinpocheTsok = Ceremony(
    id: 'guru-rinpoche-tsok',
    nameEn: 'Guru Rinpoche Tsok',
    nameBo: 'གུ་རུ་རིན་པོ་ཆེའི་ཚོགས།',
    isTsok: true,
  );
  static const ceremonies = [medicineBuddha, greenTara, guruRinpocheTsok];

  final Clock _clock;
  final TibetanCalendar _calendar;

  /// Receipts per temple, oldest first. Seeded lazily so the sample
  /// requests fall on upcoming practice days.
  final Map<String, List<Receipt>> _receipts = {};
  int _sequence = 915;

  List<Receipt> _of(String templeId) => _receipts.putIfAbsent(templeId, _seed);

  List<Receipt> _seed() {
    final today = _clock().dateOnly;
    DateTime next(PracticeDay practice) {
      for (var offset = 0; offset < 60; offset++) {
        final date = today.addDays(offset);
        if (_calendar.practiceOn(date) == practice) return date;
      }
      return today;
    }

    return [
      _issue(
        puja: PujaRequest(
          ceremony: guruRinpocheTsok,
          date: next(PracticeDay.guruRinpoche),
          living: const ['Margaret Chen', 'Dawa Dolma', 'ཀར་མ་ཚེ་རིང་།'],
          deceased: const ['Tsering Wangmo', 'Robert Chen'],
          sponsor: 'Margaret Chen',
          contact: 'margaret.chen@example.com',
          dedication: '',
          amount: 54,
        ),
      ),
      _issue(
        puja: PujaRequest(
          ceremony: medicineBuddha,
          date: next(PracticeDay.medicineBuddha),
          living: const ['Tenzin Dolkar', 'བསོད་ནམས་ཚེ་རིང་།'],
          deceased: const ['Pasang Norbu'],
          sponsor: 'Tenzin Dolkar',
          contact: 'tenzin.d@example.com',
          dedication:
              'For the long life and good health of our family, and for the '
              'benefit of all beings.',
          amount: 108,
        ),
      ),
    ];
  }

  Receipt _issue({Donation? donation, PujaRequest? puja}) {
    final now = _clock();
    return Receipt(
      number: 'R-${now.year}-${(_sequence++).toString().padLeft(4, '0')}',
      issuedOn: now,
      donation: donation,
      puja: puja,
    );
  }

  @override
  Future<List<Ceremony>> fetchCeremonies(String templeId) =>
      respond(() => ceremonies);

  @override
  Future<Receipt> recordDonation(String templeId, Donation donation) =>
      respond(() {
        final receipt = _issue(donation: donation);
        _of(templeId).add(receipt);
        return receipt;
      });

  @override
  Future<Receipt> recordPujaRequest(String templeId, PujaRequest request) =>
      respond(() {
        final receipt = _issue(puja: request);
        _of(templeId).add(receipt);
        return receipt;
      });

  @override
  Future<Receipt> fetchReceipt(String templeId, String number) => respond(
    () => _of(templeId).firstWhere(
      (receipt) => receipt.number == number,
      orElse: () => throw const NotFoundFailure(),
    ),
  );

  @override
  Future<Receipt?> fetchLatestReceipt(String templeId) =>
      respond(() => _of(templeId).lastOrNull);

  @override
  Future<List<PrayerList>> fetchPrayerLists(String templeId) => respond(() {
    // One list per ceremony and day, merging every request for it.
    final lists = <String, PrayerList>{};
    for (final receipt in _of(templeId)) {
      final puja = receipt.puja;
      if (puja == null) continue;
      final key = '${puja.ceremony.id}@${puja.date.isoDate}';
      final existing = lists[key];
      lists[key] = PrayerList(
        ceremony: puja.ceremony,
        date: puja.date,
        living: [...?existing?.living, ...puja.living],
        deceased: [...?existing?.deceased, ...puja.deceased],
      );
    }
    return lists.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  });
}
