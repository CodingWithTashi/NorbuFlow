/// Why a piece of user input was rejected.
///
/// Rules live in `Validators`, wording lives in `validationText`; view models
/// and views only pass these codes around.
enum ValidationIssue {
  ownEmailRequired,
  theirEmailRequired,
  emailIncomplete,
  memberNameRequired,
  phoneTooShort,
  donorRequired,
  purposeRequired,
  contactIncomplete,
  sponsorRequired,
  templeNameRequired,
  addressRequired,
  alreadyOnTeam,
}
