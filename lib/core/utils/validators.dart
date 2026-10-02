import '../error/validation_issue.dart';
import '../models/phone_country.dart';

/// Input rules shared by every form. Each returns `null` when the value is
/// acceptable, otherwise the [ValidationIssue] to show.
abstract final class Validators {
  static final _email = RegExp(r'.+@.+\..+');
  static final _nonDigits = RegExp(r'\D');
  static final _memberNumber = RegExp(r'^0*[1-9][0-9]{0,14}$');

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  static String digitsOf(String value) => value.replaceAll(_nonDigits, '');

  static ValidationIssue? required(String value, ValidationIssue whenEmpty) =>
      value.trim().isEmpty ? whenEmpty : null;

  static ValidationIssue? requiredEmail(
    String value, {
    required ValidationIssue whenEmpty,
  }) {
    if (value.trim().isEmpty) return whenEmpty;
    return isEmail(value) ? null : ValidationIssue.emailIncomplete;
  }

  static ValidationIssue? optionalEmail(String value) {
    if (value.trim().isEmpty) return null;
    return isEmail(value) ? null : ValidationIssue.emailIncomplete;
  }

  static ValidationIssue? phone(String value) =>
      digitsOf(value).length < 10 ? ValidationIssue.phoneTooShort : null;

  /// A phone number that may be left empty. Typed with its own `+`, it is
  /// checked as a whole; otherwise against what [country]'s numbers look like.
  static ValidationIssue? optionalPhone(String value, PhoneCountry country) {
    if (value.trim().isEmpty) return null;
    final (digits, shortest, longest) = PhoneNumbers.isInternational(value)
        ? (digitsOf(value).length, 10, 15)
        : (
            PhoneNumbers.nationalDigits(value).length,
            country.minDigits,
            country.maxDigits,
          );
    if (digits < shortest) return ValidationIssue.phoneTooShort;
    if (digits > longest) return ValidationIssue.phoneTooLong;
    return null;
  }

  /// A membership number typed by hand: digits, above zero, at most fifteen.
  static ValidationIssue? memberNumber(String value) =>
      _memberNumber.hasMatch(value.trim())
      ? null
      : ValidationIssue.memberNumberInvalid;

  /// An optional contact that may be either an email or a phone number.
  static ValidationIssue? optionalContact(String value) {
    if (value.trim().isEmpty) return null;
    if (isEmail(value) || digitsOf(value).length >= 10) return null;
    return ValidationIssue.contactIncomplete;
  }
}
