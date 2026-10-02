import 'package:flutter/foundation.dart';

import '../../../core/models/photo_source.dart';
import '../../../core/utils/date_only.dart';

enum MembershipType {
  individual(60),
  family(100),
  seniorStudent(30),
  life(1080);

  const MembershipType(this.fee);

  /// Fee in whole dollars. Annual, except [life] which is paid once.
  final int fee;

  bool get isLifetime => this == MembershipType.life;
}

enum PaymentMethod { cash, card, transfer, cheque }

enum MembershipStatus { active, expiring, expired }

@immutable
class Member {
  const Member({
    required this.id,
    required this.nameEn,
    required this.nameBo,
    required this.number,
    this.phone = '',
    this.type = MembershipType.individual,
    this.email = '',
    this.expiresOn,
    this.photo,
    this.cardId,
  });

  /// Memberships within this many days of expiry are flagged for renewal.
  static const expiringWindowDays = 45;

  final String id;
  final String nameEn;

  /// Empty when the member has no Tibetan name.
  final String nameBo;

  /// As the temple writes it, e.g. `JC-0142`.
  final String number;

  /// Empty when the member gave none. So is [email].
  final String phone;
  final String email;
  final MembershipType type;

  /// Null for life members.
  final DateTime? expiresOn;
  final PhotoSource? photo;

  /// The card they hold now, which changes only when a new one is printed:
  /// what a card kept on the device is filed under. Null for a demo member.
  final String? cardId;

  MembershipStatus statusOn(DateTime today) {
    final expiry = expiresOn;
    if (expiry == null) return MembershipStatus.active;
    final daysLeft = expiry.dateOnly.difference(today.dateOnly).inDays;
    if (daysLeft < 0) return MembershipStatus.expired;
    if (daysLeft <= expiringWindowDays) return MembershipStatus.expiring;
    return MembershipStatus.active;
  }

  /// Whether [query] matches the member's English name, Tibetan name, or
  /// phone number. An empty query matches everyone.
  bool matches(String query) {
    final text = query.trim();
    if (text.isEmpty) return true;
    if (nameEn.toLowerCase().contains(text.toLowerCase())) return true;
    if (nameBo.isNotEmpty && nameBo.contains(text)) return true;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    return digits.isNotEmpty &&
        phone.replaceAll(RegExp(r'\D'), '').contains(digits);
  }

  /// The counting part of a number as written: `JC-0142` → `142`.
  static String digitsOf(String number) =>
      '${int.tryParse(_digitsAtEnd.stringMatch(number) ?? '') ?? 0}';

  static final _digitsAtEnd = RegExp(r'\d+$');

  /// The number after the highest of [numbers], written as they are:
  /// `JC-0203` → `JC-0204`. [whenNone] if there are no numbers to follow.
  static String numberAfter(
    Iterable<String> numbers, {
    required String whenNone,
  }) {
    String? highest;
    var value = 0;
    for (final number in numbers) {
      final counted = int.tryParse(_digitsAtEnd.stringMatch(number) ?? '');
      if (counted == null || counted < value) continue;
      (highest, value) = (number, counted);
    }
    if (highest == null) return whenNone;
    return rewritten(highest, '${value + 1}');
  }

  /// [digits] written the way [like] is: its prefix, and as many places.
  static String rewritten(String like, String digits) {
    final places = _digitsAtEnd.stringMatch(like)?.length ?? 0;
    final prefix = like.substring(0, like.length - places);
    return '$prefix${digits.padLeft(places, '0')}';
  }

  Member copyWith({DateTime? expiresOn}) => Member(
    id: id,
    nameEn: nameEn,
    nameBo: nameBo,
    number: number,
    phone: phone,
    email: email,
    type: type,
    expiresOn: expiresOn ?? this.expiresOn,
    photo: photo,
    cardId: cardId,
  );
}

/// Everything the front desk enters to create a member.
@immutable
class NewMember {
  const NewMember({
    required this.nameEn,
    required this.nameBo,
    required this.phone,
    required this.email,
    required this.type,
    required this.payment,
    this.photo,
  });

  final String nameEn;
  final String nameBo;
  final String phone;
  final String email;
  final MembershipType type;
  final PaymentMethod payment;
  final PhotoSource? photo;
}

/// A member's arrival recorded at the front desk.
@immutable
class CheckIn {
  const CheckIn({required this.member, required this.at});

  final Member member;
  final DateTime at;
}

abstract interface class MemberRepository {
  Future<List<Member>> fetchMembers(String templeId);

  /// Creates the member, assigns the next member number and records the
  /// membership payment.
  Future<Member> addMember(String templeId, NewMember newMember);

  /// Extends the membership by one year from its expiry (or from today if it
  /// has already lapsed).
  Future<Member> renew(String templeId, String memberId);

  Future<CheckIn> checkIn(String templeId, String memberId);
}
