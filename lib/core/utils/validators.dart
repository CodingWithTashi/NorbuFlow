import '../error/validation_issue.dart';

/// Input rules shared by every form. Each returns `null` when the value is
/// acceptable, otherwise the [ValidationIssue] to show.
abstract final class Validators {
  static final _email = RegExp(r'.+@.+\..+');
  static final _nonDigits = RegExp(r'\D');

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

  /// An optional contact that may be either an email or a phone number.
  static ValidationIssue? optionalContact(String value) {
    if (value.trim().isEmpty) return null;
    if (isEmail(value) || digitsOf(value).length >= 10) return null;
    return ValidationIssue.contactIncomplete;
  }
}
