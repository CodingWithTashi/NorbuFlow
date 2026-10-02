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
          'JC-0142',
          '416 555 0142',
          MembershipType.family,
          165,
        ),
        _seed(
          2,
          'Sonam Wangchuk',
          'བསོད་ནམས་དབང་ཕྱུག',
          'JC-0087',
          '647 555 0187',
          MembershipType.individual,
          12,
        ),
        _seed(
          3,
          'Margaret Chen',
          '',
          'JC-0203',
          '416 555 0203',
          MembershipType.seniorStudent,
          94,
        ),
        _seed(
          4,
          'Pema Lhamo',
          'པདྨ་ལྷ་མོ།',
          'JC-0031',
          '905 555 0031',
          MembershipType.individual,
          -31,
        ),
        _seed(
          5,
          'Karma Tsering',
          'ཀར་མ་ཚེ་རིང་།',
          'JC-0115',
          '416 555 0115',
          MembershipType.family,
          264,
        ),
        _seed(
          6,
          'David Morrison',
          '',
          'JC-0198',
          '647 555 0198',
          MembershipType.individual,
          28,
        ),
        _seed(
          7,
          'Dawa Dolma',
          'ཟླ་བ་སྒྲོལ་མ།',
          'JC-0064',
          '416 555 0064',
          MembershipType.family,
          132,
        ),
        _seed(
          8,
          'Lobsang Gyatso',
          'བློ་བཟང་རྒྱ་མཚོ།',
          'JC-0012',
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
          'DL-0058',
          '604 555 0158',
          MembershipType.family,
          201,
        ),
        _seed(
          22,
          'Ngawang Choedon',
          'ངག་དབང་ཆོས་སྒྲོན།',
          'DL-0044',
          '778 555 0144',
          MembershipType.individual,
          19,
        ),
        _seed(
          23,
          'Robert Chen',
          '',
          'DL-0071',
          '604 555 0171',
          MembershipType.seniorStudent,
          88,
        ),
        _seed(
          24,
          'Chime Dolma',
          'འཆི་མེད་སྒྲོལ་མ།',
          'DL-0009',
          '604 555 0109',
          MembershipType.life,
          null,
        ),
        _seed(
          25,
          'Kelsang Pema',
          'བསྐལ་བཟང་པདྨ།',
          'DL-0063',
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

  /// What a temple with no members yet numbers its first.
  static const firstNumber = '0001';

  DateTime get _today => _clock().dateOnly;

  Member _seed(
    int id,
    String nameEn,
    String nameBo,
    String number,
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

  /// The temple's members as they stand, for the fake that issues cards.
  List<Member> membersOf(String templeId) => List.unmodifiable(_of(templeId));

  /// Files [member]: in place of the one with their id, or as the newest.
  void save(String templeId, Member member) {
    final members = _of(templeId);
    final index = members.indexWhere((m) => m.id == member.id);
    if (index < 0) {
      members.insert(0, member);
    } else {
      members[index] = member;
    }
  }

  @override
  Future<List<Member>> fetchMembers(String templeId) =>
      respond(() => List.unmodifiable(_of(templeId)));

  @override
  Future<Member> addMember(String templeId, NewMember newMember) => respond(() {
    final members = _of(templeId);
    final member = Member(
      id: 'm${_nextId++}',
      nameEn: newMember.nameEn.trim(),
      nameBo: newMember.nameBo.trim(),
      number: Member.numberAfter(
        members.map((member) => member.number),
        whenNone: firstNumber,
      ),
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
