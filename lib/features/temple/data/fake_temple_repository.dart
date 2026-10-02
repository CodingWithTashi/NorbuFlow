import '../../../core/data/fake_repository.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/theme/accent_preset.dart';
import '../domain/role.dart';
import '../domain/temple.dart';

/// Demo temples in Canada. Tibetan copy is a first pass and needs review by
/// a native reader; logos are placeholders.
abstract final class FakeTemples {
  static const jangchubId = 'jc';
  static const drolmaId = 'dl';

  static const all = [
    Temple(
      id: jangchubId,
      nameEn: 'Jangchub Choling',
      nameBo: 'བྱང་ཆུབ་ཆོས་གླིང་།',
      monogram: 'JC',
      tradition: 'Gelug tradition · Toronto',
      url: 'jangchub.norbuflow.app',
      accent: AccentPreset.maroon,
      charityRegistration: 'Registered Charity No. 81942 7731 RR0001',
      address: '412 Lansdowne Ave, Toronto ON M6H 3Y2',
      signatory: 'Geshe Lobsang Tenzin',
    ),
    Temple(
      id: drolmaId,
      nameEn: 'Drolma Ling Centre',
      nameBo: 'སྒྲོལ་མ་གླིང་།',
      monogram: 'DL',
      tradition: 'Kagyu tradition · Vancouver',
      url: 'drolmaling.norbuflow.app',
      accent: AccentPreset.lapisBlue,
      charityRegistration: 'Registered Charity No. 10457 2286 RR0001',
      address: '88 East 10th Ave, Vancouver BC V5T 1Z8',
      signatory: 'Lama Karma Wangdu',
    ),
  ];

  static const teams = <String, List<TeamMember>>{
    jangchubId: [
      TeamMember(
        id: 'u1',
        name: 'Dolma Tsering',
        email: 'dolma@jangchub.org',
        role: Role.admin,
        isYou: true,
      ),
      TeamMember(
        id: 'u2',
        name: 'Geshe Lobsang Tenzin',
        email: 'geshe.lobsang@jangchub.org',
        role: Role.geshe,
      ),
      TeamMember(
        id: 'u3',
        name: 'Karma Tsering',
        email: 'karma.treasurer@gmail.com',
        role: Role.accountant,
      ),
      TeamMember(
        id: 'u4',
        name: 'Sonam Wangchuk',
        email: 'sonam.w@gmail.com',
        role: Role.frontDesk,
      ),
      TeamMember(
        id: 'u5',
        name: 'Pema Lhamo',
        email: 'pema.lhamo@outlook.com',
        role: Role.coordinator,
      ),
      TeamMember(
        id: 'u6',
        name: 'Ruth Abernathy',
        email: 'ruth.a@example.com',
        role: Role.volunteer,
        invitePending: true,
      ),
    ],
    drolmaId: [
      TeamMember(
        id: 'w1',
        name: 'Ani Choedon',
        email: 'choedon@drolmaling.ca',
        role: Role.admin,
      ),
      TeamMember(
        id: 'w2',
        name: 'Dolma Tsering',
        email: 'dolma@jangchub.org',
        role: Role.accountant,
        isYou: true,
      ),
      TeamMember(
        id: 'w3',
        name: 'Lama Karma Wangdu',
        email: 'lama.karma@drolmaling.ca',
        role: Role.geshe,
      ),
      TeamMember(
        id: 'w4',
        name: 'Tashi Dorje',
        email: 'tashi.d@gmail.com',
        role: Role.frontDesk,
      ),
    ],
  };
}

final class FakeTempleRepository extends FakeRepository
    implements TempleRepository {
  FakeTempleRepository(super.latency);

  final Map<String, Temple> _temples = {
    for (final temple in FakeTemples.all) temple.id: temple,
  };

  @override
  Future<List<TempleMembership>> fetchMemberships(String userId) => respond(
    () => [
      for (final temple in _temples.values)
        TempleMembership(
          temple: temple,
          role: FakeTemples.teams[temple.id]!
              .firstWhere((member) => member.isYou)
              .role,
        ),
    ],
  );

  @override
  Future<Temple> updateTemple(Temple temple) => respond(() {
    if (!_temples.containsKey(temple.id)) throw const NotFoundFailure();
    return _temples[temple.id] = temple;
  });
}

final class FakeTeamRepository extends FakeRepository
    implements TeamRepository {
  FakeTeamRepository(super.latency);

  final Map<String, List<TeamMember>> _teams = {
    for (final entry in FakeTemples.teams.entries)
      entry.key: List.of(entry.value),
  };
  int _nextId = 1;

  // A temple the demo has no team for (a real one) starts with nobody.
  List<TeamMember> _team(String templeId) =>
      _teams.putIfAbsent(templeId, () => []);

  @override
  Future<List<TeamMember>> fetchTeam(String templeId) =>
      respond(() => List.unmodifiable(_team(templeId)));

  @override
  Future<TeamMember> invite(
    String templeId, {
    required String email,
    required Role role,
  }) => respond(() {
    final team = _team(templeId);
    final normalised = email.trim().toLowerCase();
    if (team.any((member) => member.email.toLowerCase() == normalised)) {
      throw const ConflictFailure(reason: ConflictReason.alreadyOnTeam);
    }
    final invited = TeamMember(
      id: 'invite-${_nextId++}',
      name: _nameFromEmail(email.trim()),
      email: email.trim(),
      role: role,
      invitePending: true,
    );
    team.add(invited);
    return invited;
  });

  @override
  Future<void> resendInvite(String templeId, String memberId) =>
      respond(() => _indexOf(templeId, memberId));

  @override
  Future<TeamMember> updateRole(String templeId, String memberId, Role role) =>
      respond(() {
        final team = _team(templeId);
        final index = _indexOf(templeId, memberId);
        return team[index] = team[index].copyWith(role: role);
      });

  @override
  Future<void> remove(String templeId, String memberId) => respond(() {
    _team(templeId).removeAt(_indexOf(templeId, memberId));
  });

  @override
  Future<void> restore(String templeId, TeamMember member) => respond(() {
    final team = _team(templeId);
    if (team.every((existing) => existing.id != member.id)) team.add(member);
  });

  int _indexOf(String templeId, String memberId) {
    final index = _team(templeId).indexWhere((m) => m.id == memberId);
    if (index < 0) throw const NotFoundFailure();
    return index;
  }

  /// `ruth.a@example.com` → `Ruth A`, until they sign in and set a name.
  static String _nameFromEmail(String email) {
    final local = email.split('@').first.replaceAll(RegExp(r'[._]'), ' ');
    return local
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
