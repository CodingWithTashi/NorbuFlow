import 'package:flutter/foundation.dart';

import '../../../core/models/photo_source.dart';
import '../../../core/theme/accent_preset.dart';
import 'role.dart';

/// A temple's portal: the details printed on its ID cards and receipts.
@immutable
class Temple {
  const Temple({
    required this.id,
    required this.nameEn,
    required this.nameBo,
    required this.monogram,
    required this.tradition,
    required this.url,
    required this.accent,
    required this.charityRegistration,
    required this.address,
    required this.signatory,
    this.logo,
  });

  final String id;
  final String nameEn;
  final String nameBo;

  /// Two-letter mark used on badges and as the member-number prefix.
  final String monogram;

  /// Lineage and city, e.g. "Gelug tradition · Toronto".
  final String tradition;
  final String url;
  final AccentPreset accent;
  final String charityRegistration;
  final String address;

  /// Name printed above the signature line on receipts.
  final String signatory;
  final PhotoSource? logo;

  Temple copyWith({
    String? nameEn,
    String? nameBo,
    String? tradition,
    AccentPreset? accent,
    String? charityRegistration,
    String? address,
    String? signatory,
    PhotoSource? logo,
  }) {
    return Temple(
      id: id,
      nameEn: nameEn ?? this.nameEn,
      nameBo: nameBo ?? this.nameBo,
      monogram: monogram,
      tradition: tradition ?? this.tradition,
      url: url,
      accent: accent ?? this.accent,
      charityRegistration: charityRegistration ?? this.charityRegistration,
      address: address ?? this.address,
      signatory: signatory ?? this.signatory,
      logo: logo ?? this.logo,
    );
  }
}

/// A temple the signed-in person belongs to, and what they do there.
@immutable
class TempleMembership {
  const TempleMembership({required this.temple, required this.role});

  final Temple temple;
  final Role role;

  TempleMembership copyWith({Temple? temple}) =>
      TempleMembership(temple: temple ?? this.temple, role: role);
}

/// Someone with access to a temple's portal.
@immutable
class TeamMember {
  const TeamMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isYou = false,
    this.invitePending = false,
  });

  final String id;
  final String name;
  final String email;
  final Role role;

  /// The signed-in person's own entry.
  final bool isYou;

  /// Invited but has not signed in yet.
  final bool invitePending;

  /// People cannot change their own role: an admin who demoted themselves
  /// could lock the temple out. Another admin has to do it.
  bool canTakeRole(Role newRole) => !isYou || newRole == role;

  TeamMember copyWith({Role? role}) => TeamMember(
    id: id,
    name: name,
    email: email,
    role: role ?? this.role,
    isYou: isYou,
    invitePending: invitePending,
  );
}

abstract interface class TempleRepository {
  /// Temples [userId] has been invited to, with their role at each.
  Future<List<TempleMembership>> fetchMemberships(String userId);

  Future<Temple> updateTemple(Temple temple);
}

abstract interface class TeamRepository {
  Future<List<TeamMember>> fetchTeam(String templeId);

  /// Fails with `ConflictFailure(alreadyOnTeam)` if [email] is on the team.
  Future<TeamMember> invite(
    String templeId, {
    required String email,
    required Role role,
  });

  Future<void> resendInvite(String templeId, String memberId);

  Future<TeamMember> updateRole(String templeId, String memberId, Role role);

  Future<void> remove(String templeId, String memberId);

  /// Puts back a member removed moments ago (the Undo on the toast).
  Future<void> restore(String templeId, TeamMember member);
}
