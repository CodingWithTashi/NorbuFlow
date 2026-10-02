import 'package:flutter/foundation.dart';

/// The photo box of the `drepung-loseling-canada` card (its `photo` in
/// functions/.../templates). The app crops to it, so what is framed prints.
abstract final class CardPhoto {
  /// Width over height.
  static const aspectRatio = 79.44738 / 90.434528;

  /// The rounding of the corners, as a fraction of the width.
  static const cornerRadius = 3.744516 / 79.44738;

  /// Pixels along the longer side: 600 per inch on the printed card.
  static const longSide = 754;
}

/// What the front desk enters to give someone an ID card.
@immutable
class NewCard {
  const NewCard({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.photo,
  });

  /// A UUID the app chooses, so that sending a card twice makes one member.
  final String id;
  final String name;
  final String phone;

  /// Empty when the member has none.
  final String email;

  /// Cropped to [CardPhoto].
  final Uint8List photo;
}

/// A member's ID card as issued by the backend: who they now are on the
/// membership roll, and the card itself.
@immutable
class IssuedCard {
  const IssuedCard({
    required this.number,
    required this.name,
    required this.expiresOn,
    required this.pdf,
  });

  /// Assigned by the temple's backend, as printed on the card.
  final String number;
  final String name;

  /// The membership's last day, as printed on the card.
  final DateTime expiresOn;

  /// The print-ready card: front, then back, at the size of the card.
  final Uint8List pdf;
}

abstract interface class CardRepository {
  /// Adds a member and returns their card: the same card if asked again.
  /// A field that cannot be used fails as a `ValidationFailure` keyed by it.
  Future<IssuedCard> issue(NewCard card);
}
