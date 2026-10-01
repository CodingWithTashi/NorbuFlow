import 'package:flutter/foundation.dart';

import '../../members/domain/member.dart' show PaymentMethod;

/// Offerings recorded with the short donation form. (Puja and Tsok have
/// their own flow because they carry names for prayers.)
enum OfferingKind { donation, butterLamp, buildingFund, other }

@immutable
class Ceremony {
  const Ceremony({
    required this.id,
    required this.nameEn,
    required this.nameBo,
    this.isTsok = false,
  });

  final String id;
  final String nameEn;
  final String nameBo;

  /// A feast offering rather than a Puja; picks the default on the Tsok tile.
  final bool isTsok;
}

@immutable
class Donation {
  const Donation({
    required this.kind,
    required this.donor,
    required this.contact,
    required this.note,
    required this.amount,
    required this.payment,
  });

  final OfferingKind kind;
  final String donor;
  final String contact;
  final String note;

  /// Whole dollars.
  final int amount;
  final PaymentMethod payment;
}

@immutable
class PujaRequest {
  const PujaRequest({
    required this.ceremony,
    required this.date,
    required this.living,
    required this.deceased,
    required this.sponsor,
    required this.contact,
    required this.dedication,
    required this.amount,
  });

  final Ceremony ceremony;
  final DateTime date;

  /// Names to pray for: long life, health and protection.
  final List<String> living;

  /// Names of those who have passed: for a good rebirth.
  final List<String> deceased;
  final String sponsor;
  final String contact;
  final String dedication;
  final int amount;
}

/// An official donation receipt. Exactly one of [donation] and [puja] is set.
@immutable
class Receipt {
  const Receipt({
    required this.number,
    required this.issuedOn,
    this.donation,
    this.puja,
  }) : assert((donation == null) != (puja == null));

  /// e.g. `R-2026-0917`.
  final String number;
  final DateTime issuedOn;
  final Donation? donation;
  final PujaRequest? puja;

  String get receivedFrom => donation?.donor ?? puja!.sponsor;

  String get contact => donation?.contact ?? puja!.contact;

  int get amount => donation?.amount ?? puja!.amount;
}

/// Names the Geshe reads at one ceremony, gathered from its Puja requests.
@immutable
class PrayerList {
  const PrayerList({
    required this.ceremony,
    required this.date,
    required this.living,
    required this.deceased,
  });

  final Ceremony ceremony;
  final DateTime date;
  final List<String> living;
  final List<String> deceased;
}

abstract interface class OfferingRepository {
  Future<List<Ceremony>> fetchCeremonies(String templeId);

  /// Saves the donation and issues its receipt.
  Future<Receipt> recordDonation(String templeId, Donation donation);

  /// Saves the request, adds its names to the ceremony's prayer list and
  /// issues the receipt.
  Future<Receipt> recordPujaRequest(String templeId, PujaRequest request);

  Future<Receipt> fetchReceipt(String templeId, String number);

  /// The most recently issued receipt, or null if there are none.
  Future<Receipt?> fetchLatestReceipt(String templeId);

  Future<List<PrayerList>> fetchPrayerLists(String templeId);
}
