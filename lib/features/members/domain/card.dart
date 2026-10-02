import 'package:flutter/foundation.dart';

import 'member.dart';

/// The photo box every temple's card has (`photo` in the backend's card
/// templates). The app crops to it, so what is framed prints.
abstract final class CardPhoto {
  /// Width over height.
  static const aspectRatio = 79.44738 / 90.434528;

  /// The rounding of the corners, as a fraction of the width.
  static const cornerRadius = 3.744516 / 79.44738;

  /// Pixels along the longer side: 600 per inch on the printed card.
  static const longSide = 754;
}

/// What a card's files are kept as on the device (`FileCache`). A card never
/// changes once printed, so its id names them for good.
abstract final class CardFiles {
  /// Front and back.
  static const sides = 2;

  static String pdf(String cardId) => 'cards/$cardId.pdf';

  /// The picture of one side: 0 for the front.
  static String page(String cardId, int side) =>
      'cards/$cardId-${side + 1}.png';

  static List<String> all(String cardId) => [
    pdf(cardId),
    for (var side = 0; side < sides; side++) page(cardId, side),
  ];
}

/// What the front desk enters for an ID card: a new member's, or new details
/// for a member on file.
@immutable
class CardRequest {
  const CardRequest({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.memberId,
    this.photo,
    this.number,
  });

  /// A UUID the app chooses, so that sending a request twice makes one card.
  final String id;

  /// Whose card it is. Null for a new member.
  final String? memberId;
  final String name;

  /// With its country's code. Empty when the member has none; so is [email].
  final String phone;
  final String email;

  /// Cropped to [CardPhoto]. Null keeps the photo a member on file has.
  final Uint8List? photo;

  /// The digits of a membership number typed by hand. Null leaves it to the
  /// temple: its next number, or the one the member has.
  final String? number;
}

/// A card as it would print, before anything is saved.
@immutable
class CardPreview {
  const CardPreview({
    required this.number,
    required this.label,
    required this.pdf,
  });

  /// The digits of the membership number on the card.
  final String number;

  /// That number as the temple writes it, e.g. `JC-0142`.
  final String label;

  /// Front, then back, at the size of the card.
  final Uint8List pdf;
}

/// A member as saved, with the card that was printed for them.
@immutable
class IssuedCard {
  const IssuedCard({required this.member, required this.pdf});

  final Member member;

  /// The print-ready card: front, then back, at the size of the card.
  final Uint8List pdf;
}

/// What came of asking for a card.
sealed class CardOutcome {
  const CardOutcome();
}

final class CardIssued extends CardOutcome {
  const CardIssued(this.card);

  final IssuedCard card;
}

/// The number typed by hand belongs to someone else. Nothing was saved.
@immutable
final class NumberTaken extends CardOutcome {
  const NumberTaken({required this.name, required this.number});

  /// Who holds it.
  final String name;

  /// As the temple writes it.
  final String number;
}

abstract interface class CardRepository {
  /// Draws the card [request] would make, with the number it would carry.
  /// A field that cannot be used fails as a `ValidationFailure` keyed by it.
  Future<CardPreview> preview(String templeId, CardRequest request);

  /// Saves the member and returns their card: the same card if asked again.
  /// With [replace], a number someone holds comes with that person's record.
  Future<CardOutcome> issue(
    String templeId,
    CardRequest request, {
    bool replace = false,
  });

  /// The card [member] holds. One that was fetched before comes from the
  /// device, without asking the backend again.
  Future<IssuedCard> fetch(String templeId, Member member);
}
