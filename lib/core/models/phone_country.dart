/// A country whose phone numbers the app knows how to write: the ones where
/// the temples it serves are.
enum PhoneCountry {
  canada('CA', '1', 10, 10),
  unitedStates('US', '1', 10, 10),
  india('IN', '91', 10, 10),
  nepal('NP', '977', 8, 10),
  taiwan('TW', '886', 8, 9),
  france('FR', '33', 9, 9),
  australia('AU', '61', 9, 9),
  switzerland('CH', '41', 9, 9),
  unitedKingdom('GB', '44', 9, 10);

  const PhoneCountry(
    this.isoCode,
    this.callingCode,
    this.minDigits,
    this.maxDigits,
  );

  /// Two letters, as a SIM card reports its country.
  final String isoCode;

  /// What a number from here starts with abroad, without the plus.
  final String callingCode;

  /// How many digits a number has inside the country, any leading 0 aside.
  final int minDigits;
  final int maxDigits;

  /// The country a device says it is in, or null if it is not one of these.
  static PhoneCountry? fromIso(String? isoCode) {
    final code = isoCode?.toUpperCase();
    for (final country in values) {
      if (country.isoCode == code) return country;
    }
    return null;
  }
}

/// A phone number as typed: where it is from, and the number inside that
/// country. Saved with its country's code, so it can be dialled anywhere.
abstract final class PhoneNumbers {
  static final _nonDigits = RegExp(r'\D');
  static final _leadingZeros = RegExp(r'^0+');
  // The 0 in front of a number, whatever bracket or space comes before it.
  static final _trunkZeros = RegExp(r'^(\D*)0+');
  static final _separators = RegExp(r'^[\s.-]+');

  /// The digits to dial inside the country: what was typed, less the 0 that
  /// many countries put in front.
  static String nationalDigits(String typed) =>
      typed.replaceAll(_nonDigits, '').replaceFirst(_leadingZeros, '');

  /// Whether [typed] already carries a country's code.
  static bool isInternational(String typed) => typed.trim().startsWith('+');

  /// `416 555 0142` in Canada → `+1 416 555 0142`. Empty stays empty, and a
  /// number typed with its own `+` is kept as it is.
  static String compose(PhoneCountry country, String typed) {
    final text = typed.trim();
    if (text.isEmpty || isInternational(text)) return text;
    final national = text.replaceFirstMapped(_trunkZeros, (zeros) => zeros[1]!);
    return '+${country.callingCode} $national';
  }

  /// Takes a saved number apart again for editing. One saved without a
  /// code is taken to be from [fallback].
  static (PhoneCountry, String) parse(
    String saved, {
    required PhoneCountry fallback,
  }) {
    final text = saved.trim();
    if (!isInternational(text)) return (fallback, text);
    final digits = text.replaceAll(_nonDigits, '');
    // Canada and the United States share a code: the device's own is likelier.
    final candidates = [fallback, ...PhoneCountry.values];
    for (final country in candidates) {
      if (!digits.startsWith(country.callingCode)) continue;
      final rest = text.substring(1).trimLeft();
      final national = rest.substring(country.callingCode.length);
      return (country, national.replaceFirst(_separators, ''));
    }
    return (fallback, text);
  }

  /// The digits WhatsApp and diallers want: country code first, no plus.
  static String dialable(String saved, {required PhoneCountry fallback}) {
    if (isInternational(saved)) return saved.replaceAll(_nonDigits, '');
    return '${fallback.callingCode}${nationalDigits(saved)}';
  }
}
