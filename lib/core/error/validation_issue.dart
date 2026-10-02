/// Why a piece of user input was rejected. Rules live in `Validators` and the
/// backend, wording in `validationText`; everything between passes the code.
enum ValidationIssue {
  ownEmailRequired,
  theirEmailRequired,
  emailIncomplete,
  memberNameRequired,

  /// Does not fit on the temple's printed card.
  memberNameTooLong,

  /// Has letters the card's typeface cannot print.
  memberNameUnsupported,
  photoRequired,

  /// Not a picture, or too large to send.
  photoUnreadable,
  phoneTooShort,
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
