import '../../../core/data/fake_repository.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/utils/clock.dart';
import '../../temple/data/fake_temple_repository.dart';
import '../domain/member.dart';

/// In-memory members for the demo temples. Expiry dates are seeded relative
/// to today so the list always shows a mix of active, expiring and expired.
final class FakeMemberRepository extends FakeRepository
    implements MemberRepository {
  FakeMemberRepository(super.latency, this._clock) {
    _members = {
      FakeTemples.jangchubId: [
        _seed(
          1,
          'Tenzin Dolkar',
          'བསྟན་འཛིན་སྒྲོལ་དཀར།',
          142,
          '416 555 0142',
          MembershipType.family,
          165,
        ),
        _seed(
          2,
          'Sonam Wangchuk',
          'བསོད་ནམས་དབང་ཕྱུག',
          87,
          '647 555 0187',
          MembershipType.individual,
          12,
        ),
        _seed(
          3,
          'Margaret Chen',
          '',
          203,
          '416 555 0203',
          MembershipType.seniorStudent,
          94,
        ),
        _seed(
          4,
          'Pema Lhamo',
          'པདྨ་ལྷ་མོ།',
          31,
          '905 555 0031',
          MembershipType.individual,
          -31,
        ),
        _seed(
          5,
          'Karma Tsering',
          'ཀར་མ་ཚེ་རིང་།',
          115,
          '416 555 0115',
          MembershipType.family,
          264,
        ),
        _seed(
          6,
          'David Morrison',
          '',
          198,
          '647 555 0198',
          MembershipType.individual,
          28,
        ),
        _seed(
          7,
          'Dawa Dolma',
          'ཟླ་བ་སྒྲོལ་མ།',
          64,
          '416 555 0064',
          MembershipType.family,
          132,
        ),
        _seed(
          8,
          'Lobsang Gyatso',
          'བློ་བཟང་རྒྱ་མཚོ།',
          12,
          '905 555 0012',
          MembershipType.life,
          null,
        ),
      ],
      FakeTemples.drolmaId: [
        _seed(
          21,
          'Yeshi Lhamo',
          'ཡེ་ཤེས་ལྷ་མོ།',
          58,
          '604 555 0158',
          MembershipType.family,
          201,
        ),
        _seed(
          22,
          'Ngawang Choedon',
          'ངག་དབང་ཆོས་སྒྲོན།',
          44,
          '778 555 0144',
          MembershipType.individual,
          19,
        ),
        _seed(
          23,
          'Robert Chen',
          '',
          71,
          '604 555 0171',
          MembershipType.seniorStudent,
          88,
        ),
        _seed(
          24,
          'Chime Dolma',
          'འཆི་མེད་སྒྲོལ་མ།',
          9,
          '604 555 0109',
          MembershipType.life,
          null,
        ),
        _seed(
          25,
          'Kelsang Pema',
          'བསྐལ་བཟང་པདྨ།',
          63,
          '778 555 0163',
          MembershipType.individual,
          -12,
        ),
      ],
    };
  }

  final Clock _clock;
  late final Map<String, List<Member>> _members;
  int _nextId = 100;

  DateTime get _today => _clock().dateOnly;

  Member _seed(
    int id,
    String nameEn,
    String nameBo,
    int number,
    String phone,
    MembershipType type,
    int? expiresInDays,
  ) {
    return Member(
      id: 'm$id',
      nameEn: nameEn,
      nameBo: nameBo,
      number: number,
      phone: phone,
      type: type,
      expiresOn: expiresInDays == null ? null : _today.addDays(expiresInDays),
    );
  }

  List<Member> _of(String templeId) =>
      _members[templeId] ?? (throw const NotFoundFailure());

  int _indexOf(String templeId, String memberId) {
    final index = _of(templeId).indexWhere((m) => m.id == memberId);
    if (index < 0) throw const NotFoundFailure();
    return index;
  }

  @override
  Future<List<Member>> fetchMembers(String templeId) =>
      respond(() => List.unmodifiable(_of(templeId)));

  @override
  Future<Member> addMember(String templeId, NewMember newMember) => respond(() {
    final members = _of(templeId);
    final highest = members.fold(
      0,
      (max, m) => m.number > max ? m.number : max,
    );
    final member = Member(
      id: 'm${_nextId++}',
      nameEn: newMember.nameEn.trim(),
      nameBo: newMember.nameBo.trim(),
      number: highest + 1,
      phone: newMember.phone.trim(),
      email: newMember.email.trim(),
      type: newMember.type,
      expiresOn: newMember.type.isLifetime ? null : _today.plusOneYear,
      photo: newMember.photo,
    );
    members.insert(0, member);
    return member;
  });

  @override
  Future<Member> renew(String templeId, String memberId) => respond(() {
    final members = _of(templeId);
    final index = _indexOf(templeId, memberId);
    final member = members[index];
    final expiry = member.expiresOn;
    if (expiry == null) return member;
    final from = expiry.isAfter(_today) ? expiry : _today;
    return members[index] = member.copyWith(expiresOn: from.plusOneYear);
  });

  @override
  Future<CheckIn> checkIn(String templeId, String memberId) => respond(
    () => CheckIn(
      member: _of(templeId)[_indexOf(templeId, memberId)],
      at: _clock(),
    ),
  );
}
