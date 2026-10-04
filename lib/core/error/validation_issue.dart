/// Why a piece of user input was rejected. Rules live in `Validators` and the
/// backend, wording in `validationText`; everything between passes the code.
enum ValidationIssue {
  ownEmailRequired,
  theirEmailRequired,
  emailIncomplete,

  /// Typed on the sign-in screen, but no temple has added it.
  emailNotInvited,
  memberNameRequired,

  /// Does not fit on the temple's printed card.
  memberNameTooLong,

  /// Has letters the card's typeface cannot print.
  memberNameUnsupported,
  photoRequired,

  /// Not a picture, or too large to send.
  photoUnreadable,
  phoneTooShort,
  phoneTooLong,

  /// A membership number typed by hand that is not digits above zero.
  memberNumberInvalid,

  /// Who a support letter is for.
  letterNameRequired,
  letterNameTooLong,
  letterBodyRequired,

  /// Does not fit on the temple's letterhead.
  letterBodyTooLong,

  /// Has letters the letterhead's typeface cannot print.
  letterBodyUnsupported,

  /// A last day that has already passed.
  letterDatePast,

  /// A letter number typed by hand that is not digits above zero.
  letterNumberInvalid,
  donorRequired,
  purposeRequired,
  contactIncomplete,
  sponsorRequired,
  templeNameRequired,

  /// The person works at several temples and the request named none.
  templeRequired,
  addressRequired,
  alreadyOnTeam,
}
