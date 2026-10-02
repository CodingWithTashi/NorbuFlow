// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'NorbuFlow';

  @override
  String get appTagline => 'Membership, offerings & volunteers in one place';

  @override
  String get tapToBegin => 'Tap to begin';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageEnglishShort => 'EN';

  @override
  String get languageTibetan => 'བོད་ཡིག';

  @override
  String get commonBack => 'Back';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDone => 'Done';

  @override
  String get commonNext => 'Next';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonOptional => '(optional)';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonNone => 'None';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get commonPrint => 'Print';

  @override
  String get commonEmail => 'Email';

  @override
  String get commonWhatsApp => 'WhatsApp';

  @override
  String get commonPayment => 'Payment';

  @override
  String get commonAmount => 'Amount';

  @override
  String get commonSearchHint => 'Search by name or phone';

  @override
  String get commonEmailHint => 'name@example.com';

  @override
  String commonPeople(Object count) {
    return '$count people';
  }

  @override
  String get commonLifetime => 'Lifetime';

  @override
  String get commonEmDash => '—';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String onboardingCount(Object current, Object total) {
    return '$current OF $total';
  }

  @override
  String get onboardingMembersTitle => 'Members & ID cards';

  @override
  String get onboardingMembersBody =>
      'Add a member in a few taps. Everyone gets a digital ID card with their English and Tibetan names.';

  @override
  String get onboardingOfferingsTitle => 'Offerings & receipts';

  @override
  String get onboardingOfferingsBody =>
      'Record Puja, Tsok and donations. Official tax receipts are ready to print, email or WhatsApp.';

  @override
  String get onboardingVolunteersTitle => 'Volunteers & calendar';

  @override
  String get onboardingVolunteersBody =>
      'Plan shifts around practice days. Volunteers can accept or swap from their phone.';

  @override
  String get loginWelcome => 'Welcome';

  @override
  String get loginSubtitle => 'Sign in to your temple';

  @override
  String get loginEmailLabel => 'Your email';

  @override
  String get loginSendLink => 'Email me a sign-in link';

  @override
  String get loginInviteOnlyTitle => 'NorbuFlow is invite-only';

  @override
  String get loginInviteOnlyBody =>
      'Use the email your temple invited. No password needed — we email you a link.';

  @override
  String get checkEmailTitle => 'Check your email';

  @override
  String get checkEmailSentTo => 'We sent a sign-in link to';

  @override
  String get checkEmailHelp =>
      'Open the email from NorbuFlow and tap “Sign in”. The link works for 1 hour.';

  @override
  String get checkEmailSigningIn => 'Signing you in…';

  @override
  String get checkEmailDemo => 'Demo only — pretend I tapped the link';

  @override
  String get checkEmailOpenMail => 'Open my email app';

  @override
  String get checkEmailResend => 'Send it again';

  @override
  String get checkEmailOther => 'Use another email';

  @override
  String get toastOpeningMail => 'Opening your email app…';

  @override
  String get toastLinkResent => 'A new sign-in link is on its way.';

  @override
  String get templesTitle => 'Choose your temple';

  @override
  String templesBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You help at $count temples. You can switch later from the top bar.',
      one: 'You help at 1 temple.',
    );
    return '$_temp0';
  }

  @override
  String templesYouAre(Object role) {
    return 'You are: $role';
  }

  @override
  String get templeSwitch => 'Switch';

  @override
  String get templeSwitchSheetTitle => 'Which temple?';

  @override
  String get templeYouAreHere => 'You are here';

  @override
  String templeSwitchConfirmTitle(Object temple) {
    return 'Switch to $temple?';
  }

  @override
  String templeSwitchConfirmBody(Object temple) {
    return 'You will see $temple’s members, offerings and volunteers. Nothing here will be lost.';
  }

  @override
  String get templeSwitchConfirmYes => 'Yes, switch temple';

  @override
  String get templeSwitchConfirmNo => 'Stay here';

  @override
  String toastTempleSwitched(Object temple) {
    return 'You are now working in $temple.';
  }

  @override
  String get tabHome => 'Home';

  @override
  String get tabMembers => 'Members';

  @override
  String get tabOfferings => 'Offerings';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String get tabMore => 'More';

  @override
  String get previewLabel => 'Preview:';

  @override
  String previewBody(Object role) {
    return 'home screen for $role';
  }

  @override
  String get previewExit => 'Exit preview';

  @override
  String homeGreeting(Object name) {
    return 'Tashi Delek, $name';
  }

  @override
  String get homeAsk => 'What would you like to do today?';

  @override
  String tibetanDate(Object month, Object day) {
    return 'Tibetan month $month, day $day';
  }

  @override
  String tibetanMonth(Object month) {
    return 'Tibetan month $month';
  }

  @override
  String tibetanMonths(Object first, Object last) {
    return 'Tibetan months $first–$last';
  }

  @override
  String tibetanMonthShort(Object month, Object day) {
    return 'M$month · day $day';
  }

  @override
  String get actionAddMember => 'Add a Member';

  @override
  String get actionRenew => 'Renew Membership';

  @override
  String get actionDonate => 'Record a Donation';

  @override
  String get actionReceipt => 'Send a Receipt';

  @override
  String get actionCheckIn => 'Check-in';

  @override
  String get actionVolunteers => 'This Month\'s Volunteers';

  @override
  String get actionAnnounce => 'Make an Announcement';

  @override
  String get actionAssign => 'Assign a Shift';

  @override
  String get actionLetter => 'Volunteer Letter';

  @override
  String get actionHours => 'Volunteer Hours';

  @override
  String get actionReports => 'Reports';

  @override
  String get actionTax => 'Year-end Tax Receipts';

  @override
  String get actionTeam => 'Temple Team';

  @override
  String get actionPrayers => 'Prayer Name Lists';

  @override
  String get actionPujaRequests => 'Puja Requests';

  @override
  String get actionCalendar => 'Temple Calendar';

  @override
  String get actionApprove => 'Approve Announcements';

  @override
  String get actionPlan => 'Volunteer Plan';

  @override
  String get actionMyShifts => 'My Shifts';

  @override
  String get actionMyCard => 'My ID Card';

  @override
  String get actionAddMemberSub => 'New member + ID';

  @override
  String get actionRenewSub => 'Add one year';

  @override
  String get actionDonateSub => 'Puja, Tsok, lamps';

  @override
  String get actionReceiptSub => 'Print or send';

  @override
  String get actionCheckInSub => 'Scan member QR';

  @override
  String get actionVolunteersSub => 'This month\'s plan';

  @override
  String get actionAnnounceSub => 'Poster or message';

  @override
  String get actionAssignSub => 'Fill open shifts';

  @override
  String get actionLetterSub => 'Thanks, certificate';

  @override
  String get actionHoursSub => 'By person';

  @override
  String get actionReportsSub => 'This month';

  @override
  String get actionTaxSub => 'Year-end bundle';

  @override
  String get actionTeamSub => 'Invite, set roles';

  @override
  String get actionPrayersSub => 'By ceremony';

  @override
  String get actionPujaRequestsSub => 'To review';

  @override
  String get actionCalendarSub => 'Practice days';

  @override
  String get actionApproveSub => 'Waiting for you';

  @override
  String get actionPlanSub => 'Week or month PDF';

  @override
  String get actionMyShiftsSub => 'Accept or swap';

  @override
  String get actionMyCardSub => 'Show at desk';

  @override
  String get roleAdmin => 'Temple Admin';

  @override
  String get roleAdminDesc =>
      'Everything for this temple, including settings and people';

  @override
  String get roleGeshe => 'Geshe / Lama';

  @override
  String get roleGesheDesc =>
      'Sees Puja requests, prayer name lists and the calendar. Approves announcements.';

  @override
  String get roleAccountant => 'Accountant / Treasurer';

  @override
  String get roleAccountantDesc =>
      'Donations, membership payments, receipts and reports';

  @override
  String get roleFrontDesk => 'Front Desk Volunteer';

  @override
  String get roleFrontDeskDesc =>
      'Adds and renews members, records donations, sends receipts';

  @override
  String get roleCoordinator => 'Volunteer Coordinator';

  @override
  String get roleCoordinatorDesc =>
      'Plans the volunteer calendar and writes volunteer letters';

  @override
  String get roleVolunteer => 'Volunteer';

  @override
  String get roleVolunteerDesc => 'Sees their own shifts and hours';

  @override
  String get roleMember => 'Member';

  @override
  String get roleMemberDesc =>
      'Their own ID card, renewals, donations and Puja requests';

  @override
  String get membersTitle => 'Members';

  @override
  String membersCount(Object count) {
    return '$count members';
  }

  @override
  String membersExpiringCount(Object count) {
    return '$count expiring';
  }

  @override
  String membersExpiredCount(Object count) {
    return '$count expired';
  }

  @override
  String membersFoundCount(Object count) {
    return '$count found';
  }

  @override
  String membersNoResults(Object query) {
    return 'No one found for “$query”.';
  }

  @override
  String get membersNoResultsHint =>
      'Check the spelling, or try a phone number.';

  @override
  String get membersAddCta => '+ Add a Member';

  @override
  String get membersSelectHint => 'Choose a member to see their ID card.';

  @override
  String get statusActive => 'Active';

  @override
  String get statusExpiring => 'Expiring soon';

  @override
  String get statusExpired => 'Expired';

  @override
  String wizardStepOf(Object step, Object total) {
    return 'Step $step of $total';
  }

  @override
  String get wizardProgressSaved => 'Progress saved';

  @override
  String get addFlowName => 'Add a Member';

  @override
  String get addStepPhoto => 'Take a photo';

  @override
  String get addStepDetails => 'Member details';

  @override
  String get addStepType => 'Membership type';

  @override
  String get addStepPayment => 'Payment';

  @override
  String get addTakePhoto => 'Take photo';

  @override
  String get addUploadPhoto => 'Upload photo';

  @override
  String get addPhotoHelp =>
      'The photo goes on the member\'s ID card. You can skip this and add it later.';

  @override
  String get addCropHelp =>
      'Drag the photo to move it. Slide to zoom.\nThe circle is exactly what shows on the ID card.';

  @override
  String get addCropZoom => 'Zoom';

  @override
  String get addChooseDifferentPhoto => 'Choose a different photo';

  @override
  String get addPhotoReady => 'Photo ready for the ID card';

  @override
  String get addAdjustCrop => 'Adjust the crop';

  @override
  String get addUseThisPhoto => 'Use this photo';

  @override
  String get toastPhotoCropped => 'Photo cropped to fit the ID card.';

  @override
  String get addFieldNameEn => 'Name in English';

  @override
  String get addFieldNameEnHint => 'e.g. Tenzin Dolkar';

  @override
  String get addFieldNameBo => 'Name in Tibetan';

  @override
  String get addFieldNameBoHint => 'བོད་ཡིག་ནང་མིང་།';

  @override
  String get addFieldPhone => 'Phone number';

  @override
  String get addFieldPhoneHint => 'e.g. 416 555 0142';

  @override
  String get addFieldEmail => 'Email';

  @override
  String get membershipIndividual => 'Individual';

  @override
  String get membershipIndividualSub => 'One person, 1 year';

  @override
  String get membershipFamily => 'Family';

  @override
  String get membershipFamilySub => 'Up to 5 people at one address, 1 year';

  @override
  String get membershipSenior => 'Senior / Student';

  @override
  String get membershipSeniorSub => '1 year';

  @override
  String get membershipLife => 'Life member';

  @override
  String get membershipLifeSub => 'One payment, never expires';

  @override
  String get addFilledForYou => 'FILLED IN FOR YOU';

  @override
  String get addMemberNumber => 'Member number';

  @override
  String get addValidUntil => 'Valid until';

  @override
  String get addRenewalReminders =>
      'Renewal reminders go out by email 30 days before, 7 days before, and on the expiry day.';

  @override
  String addSummaryLine(Object name, Object type) {
    return '$name · $type';
  }

  @override
  String addSummaryMeta(Object number, Object date) {
    return 'Member no. $number · Valid until $date';
  }

  @override
  String get addHowPaying => 'How are they paying?';

  @override
  String get payCash => 'Cash';

  @override
  String get payCard => 'Card';

  @override
  String get payTransfer => 'Bank transfer';

  @override
  String get payCheque => 'Cheque';

  @override
  String addSubmit(Object price) {
    return 'Add member · $price';
  }

  @override
  String addSuccessTitle(Object name) {
    return '$name is now a member';
  }

  @override
  String addSuccessBody(Object number) {
    return 'Member number $number. Payment recorded and a welcome email is ready to send.';
  }

  @override
  String get addViewCard => 'View ID card';

  @override
  String get membersNewCard => 'New ID card';

  @override
  String get newCardTitle => 'New ID card';

  @override
  String get newCardIntro =>
      'Add a photo and the member\'s details. The membership number and dates are filled in for you.';

  @override
  String get newCardNameLabel => 'Name on the card';

  @override
  String get newCardPhotoHelp => 'The photo is printed on the ID card.';

  @override
  String get newCardCropHelp =>
      'Drag the photo to move it. Slide to zoom.\nThe frame is exactly what prints on the ID card.';

  @override
  String get newCardSubmit => 'Create ID card';

  @override
  String get newCardReadyTitle => 'ID card ready';

  @override
  String newCardReadyBody(Object name, Object number, Object date) {
    return '$name is member number $number. Valid until $date.';
  }

  @override
  String newCardDocumentName(Object number) {
    return 'ID card $number';
  }

  @override
  String get newCardFront => 'Front';

  @override
  String get newCardBack => 'Back';

  @override
  String get newCardPrint => 'Print the card';

  @override
  String get newCardShare => 'Save or send';

  @override
  String get newCardAnother => 'Another card';

  @override
  String get cardTitle => 'Membership Card';

  @override
  String get cardMemberNo => 'Member no.';

  @override
  String get cardValidUntil => 'Valid until';

  @override
  String get cardType => 'Membership';

  @override
  String get cardShare => 'Share card';

  @override
  String get cardAddToWallet => 'Add to Wallet';

  @override
  String get cardRenew => 'Renew 1 year';

  @override
  String cardValidUntilDate(Object date) {
    return 'Valid until $date';
  }

  @override
  String get cardNotFound => 'This member could not be found.';

  @override
  String toastRenewed(Object date) {
    return 'Renewed. Valid until $date.';
  }

  @override
  String get toastPrinted => 'Sent to the Front Desk printer.';

  @override
  String get toastWallet => 'Card added to Wallet.';

  @override
  String get offeringsTitle => 'Record an offering';

  @override
  String get offeringsAsk => 'What is this payment for?';

  @override
  String get offeringMembership => 'Membership';

  @override
  String get offeringMembershipSub => 'New or renewal';

  @override
  String get offeringDonation => 'Donation';

  @override
  String get offeringDonationSub => 'Any amount';

  @override
  String get offeringPuja => 'Puja';

  @override
  String get offeringPujaSub => 'Prayers by Sangha';

  @override
  String get offeringTsok => 'Tsok';

  @override
  String get offeringTsokSub => 'Feast offering';

  @override
  String get offeringButterLamp => 'Butter Lamp';

  @override
  String get offeringButterLampSub => 'Light offering';

  @override
  String get offeringBuildingFund => 'Building Fund';

  @override
  String get offeringBuildingFundSub => 'New shrine hall';

  @override
  String get offeringOther => 'Other';

  @override
  String get offeringOtherSub => 'Write the purpose';

  @override
  String get pujaFlowName => 'Puja / Tsok request';

  @override
  String get pujaStepCeremony => 'Ceremony and date';

  @override
  String get pujaStepNames => 'Names for prayers';

  @override
  String get pujaStepSponsor => 'Sponsor and offering';

  @override
  String get pujaStepReview => 'Check and save';

  @override
  String get pujaCeremony => 'Ceremony';

  @override
  String get pujaDate => 'Date';

  @override
  String get pujaLivingTitle => 'For the living';

  @override
  String get pujaLivingSub => 'Long life, health and protection';

  @override
  String get pujaPassedTitle => 'For those who have passed';

  @override
  String get pujaPassedSub => 'For a good rebirth';

  @override
  String get pujaNameHint => 'Type a name (English or Tibetan)';

  @override
  String toastNameRemoved(Object name) {
    return 'Removed “$name”.';
  }

  @override
  String get pujaSponsorName => 'Sponsor name';

  @override
  String get pujaReceiptContact => 'Email or phone for the receipt';

  @override
  String get pujaDedication => 'Dedication';

  @override
  String get pujaOfferingAmount => 'Offering amount';

  @override
  String get pujaReviewIntro => 'Please check everything before saving.';

  @override
  String get pujaReviewLiving => 'Names for the living';

  @override
  String get pujaReviewPassed => 'Names for those who have passed';

  @override
  String get pujaReviewSponsor => 'Sponsor';

  @override
  String get pujaReviewOffering => 'Offering';

  @override
  String pujaSubmit(Object amount) {
    return 'Save offering · $amount';
  }

  @override
  String get practiceMedicineBuddha => 'Medicine Buddha Day';

  @override
  String get practiceGuruRinpoche => 'Guru Rinpoche Day';

  @override
  String get practiceFullMoon => 'Full Moon';

  @override
  String get practiceDakini => 'Dakini Day';

  @override
  String get practiceNewMoon => 'New Moon';

  @override
  String get offeringRecordedTitle => 'Offering recorded';

  @override
  String offeringRecordedPuja(Object ceremony, Object date, Object number) {
    return '$ceremony on $date. The names have been added to the Geshe’s prayer list. Receipt $number is ready.';
  }

  @override
  String offeringRecordedDonation(
    Object amount,
    Object kind,
    Object donor,
    Object number,
  ) {
    return '$amount $kind from $donor. Receipt $number is ready.';
  }

  @override
  String get offeringViewReceipt => 'View receipt';

  @override
  String get receiptTitle => 'Official Donation Receipt';

  @override
  String get receiptFrom => 'Received from';

  @override
  String get receiptAmount => 'Amount received';

  @override
  String get receiptFor => 'Offering for';

  @override
  String get receiptDate => 'Date';

  @override
  String get receiptNames => 'Names for prayers';

  @override
  String get receiptTax => 'Official receipt for income tax purposes.';

  @override
  String get receiptThanks => 'Thank you for your generous offering.';

  @override
  String get receiptSignature => 'Authorised signature';

  @override
  String receiptPassedSuffix(Object name) {
    return '$name (passed)';
  }

  @override
  String get receiptEmpty =>
      'No receipts yet. Record an offering to create one.';

  @override
  String get donationSubtitle =>
      'Record an offering · a receipt is made for you';

  @override
  String get donationDonor => 'Donor name';

  @override
  String get donationNote => 'Note on the receipt';

  @override
  String get donationNoteOther => 'What is it for?';

  @override
  String get donationNoteHintDonation => 'e.g. In memory of my mother';

  @override
  String get donationNoteHintButterLamp => 'Names for the lamp dedication';

  @override
  String get donationNoteHintBuildingFund => 'e.g. Sponsor a brick';

  @override
  String get donationNoteHintOther => 'What is this offering for?';

  @override
  String donationSubmit(Object amount, Object kind) {
    return 'Record $amount $kind';
  }

  @override
  String get calendarPlanButton => 'Weekly or monthly plan (PDF)';

  @override
  String get calendarPreviousMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String get calendarNeedsPeople => 'Needs people';

  @override
  String get calendarNoShifts => 'No shifts on this day.';

  @override
  String get dutyKitchen => 'Kitchen';

  @override
  String get dutyFrontDesk => 'Front desk';

  @override
  String get dutyCleaning => 'Cleaning';

  @override
  String get dutyShrine => 'Shrine';

  @override
  String get dutyPujaSetup => 'Puja setup';

  @override
  String get shiftNoOneYet => 'No one yet';

  @override
  String shiftNeeds(Object count) {
    return 'Needs $count';
  }

  @override
  String get shiftFull => 'Full';

  @override
  String get calendarAssign => 'Assign volunteers';

  @override
  String get calendarAllFull => 'All shifts are full';

  @override
  String get toastAllShiftsFull => 'Every shift on this day is full.';

  @override
  String get assignTitle => 'Assign volunteers';

  @override
  String assignNeedsMore(Object count) {
    return 'needs $count more';
  }

  @override
  String get availabilityAvailable => 'Available';

  @override
  String get availabilityBusy => 'Busy';

  @override
  String get availabilityAway => 'Away';

  @override
  String get assignAlreadyOnShift => 'Already on this shift';

  @override
  String toastVolunteerAway(Object name) {
    return '$name is away that day.';
  }

  @override
  String toastVolunteerBusy(Object name) {
    return '$name is already on a shift.';
  }

  @override
  String toastShiftLimit(Object count) {
    return 'This shift only needs $count more.';
  }

  @override
  String assignCta(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Assign $count volunteers',
      one: 'Assign 1 volunteer',
    );
    return '$_temp0';
  }

  @override
  String get assignCtaEmpty => 'Tap names above to choose';

  @override
  String get assignSuccessTitle => 'Shift filled';

  @override
  String assignSuccessBody(Object names, Object shift, Object day) {
    return '$names will help with $shift on $day.';
  }

  @override
  String get assignMessageThem => 'Message them';

  @override
  String listAnd(Object first, Object last) {
    return '$first and $last';
  }

  @override
  String get planTitle => 'Volunteer plan';

  @override
  String get planWeekly => 'Weekly';

  @override
  String get planMonthly => 'Monthly';

  @override
  String planDocumentTitle(Object temple) {
    return '$temple — Volunteer plan';
  }

  @override
  String planPrinted(Object date) {
    return 'Printed $date';
  }

  @override
  String planWeekOf(Object range) {
    return 'Week of $range';
  }

  @override
  String get planColDate => 'Date';

  @override
  String get planColTibetan => 'Tibetan';

  @override
  String get planColDuty => 'Duty';

  @override
  String get planLegendNeeds => '= still looking for volunteers';

  @override
  String get planLegendGrey => 'Grey = no shift that day';

  @override
  String get planLegendPractice => 'practice days';

  @override
  String get planDownload => 'Download PDF';

  @override
  String get planEmailTeam => 'Email to team';

  @override
  String get toastPlanSaved => 'Volunteer plan saved as PDF.';

  @override
  String get navHome => 'Home';

  @override
  String get navMembers => 'Members';

  @override
  String get navOfferings => 'Offerings';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navMore => 'More';

  @override
  String get letterTitle => 'Volunteer letter';

  @override
  String get letterIntro =>
      'Pick a volunteer and a letter type. A draft is written for you to check and edit.';

  @override
  String get letterStepVolunteer => '1 · Volunteer';

  @override
  String get letterStepType => '2 · Type of letter';

  @override
  String get letterStepDraft => '3 · Draft';

  @override
  String get letterTypeThanks => 'Thank-you letter';

  @override
  String get letterTypeThanksDesc => 'A warm thank-you for their service';

  @override
  String get letterTypeReference => 'Reference letter';

  @override
  String get letterTypeReferenceDesc => 'For a job, school or visa application';

  @override
  String get letterTypeCertificate => 'Certificate of service';

  @override
  String get letterTypeCertificateDesc =>
      'Hours served this year, signed by the temple';

  @override
  String get improveWording => 'Improve wording';

  @override
  String get improveWordingBusy => 'Improving…';

  @override
  String get toastWordingImproved =>
      'Wording improved. Please read it before sending.';

  @override
  String get letterCheck =>
      'Please read it through. You can change any word before it is sent.';

  @override
  String get letterApproveSend => 'Approve and send';

  @override
  String get letterPrint => 'Print on letterhead';

  @override
  String get toastLetterEmpty =>
      'The letter is empty. Please write something first.';

  @override
  String toastLetterSent(Object name) {
    return 'Letter sent to $name.';
  }

  @override
  String get announceTitle => 'Make an announcement';

  @override
  String get announceStepTemplate => '1 · Choose a template';

  @override
  String get announceStepFill => '2 · Fill in the blanks';

  @override
  String get announceFieldTitle => 'Title';

  @override
  String get announceFieldWhen => 'When';

  @override
  String get announceFieldDetails => 'Details';

  @override
  String get announceStepPreview => '3 · Preview';

  @override
  String get announceViewPoster => 'Poster';

  @override
  String get announceStepSendTo => '4 · Send to';

  @override
  String announceSendCta(Object count) {
    return 'Preview and send to $count people';
  }

  @override
  String get announceSendCtaEmpty => 'Choose who to send it to';

  @override
  String get toastChooseGroup => 'Please choose at least one group.';

  @override
  String get toastAddTitle => 'Please add a title.';

  @override
  String get announceEmailFrom => 'From:';

  @override
  String get announceEmailSubject => 'Subject:';

  @override
  String get announceEmailGreeting => 'Tashi Delek,';

  @override
  String get announceEmailSignoff => 'With warm wishes,';

  @override
  String toastAnnouncementSent(Object count) {
    return 'Announcement sent to $count people.';
  }

  @override
  String get hoursTitle => 'Volunteer hours';

  @override
  String hoursPeriod(Object month, Object year) {
    return 'January – $month $year';
  }

  @override
  String hoursTotalLabel(Object count) {
    return 'hours from $count volunteers';
  }

  @override
  String hoursValue(Object hours) {
    return '$hours h';
  }

  @override
  String hoursRowMeta(Object duties, Object year) {
    return '$duties · since $year';
  }

  @override
  String get hoursWriteThanks => 'Write a thank-you letter';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsOfferingsThisMonth => 'Offerings this month';

  @override
  String reportsChangeUp(Object percent, Object month) {
    return 'Up $percent% from $month';
  }

  @override
  String reportsChangeDown(Object percent, Object month) {
    return 'Down $percent% from $month';
  }

  @override
  String get reportsByType => 'By type';

  @override
  String get reportsMembershipsDue => 'Memberships due';

  @override
  String get reportsSeeMembers => 'See these members';

  @override
  String get reportsExportPdf => 'Export PDF';

  @override
  String get reportsExportExcel => 'Export Excel';

  @override
  String get toastReportPdf => 'Report saved as PDF.';

  @override
  String get toastReportExcel => 'Report saved as an Excel file.';

  @override
  String get reportCategoryPuja => 'Puja & Tsok';

  @override
  String get reportCategoryMembership => 'Membership';

  @override
  String get reportCategoryBuildingFund => 'Building Fund';

  @override
  String get reportCategoryButterLamp => 'Butter Lamp';

  @override
  String get reportCategoryGeneral => 'General donations';

  @override
  String get taxTitle => 'Year-end tax receipts';

  @override
  String taxSubtitle(Object year) {
    return 'Tax year $year · one receipt per donor';
  }

  @override
  String get taxDonors => 'Donors';

  @override
  String get taxTotalGiven => 'Total given';

  @override
  String taxMissingLead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count donors need a mailing address',
      one: '1 donor needs a mailing address',
    );
    return '$_temp0';
  }

  @override
  String get taxMissingRest =>
      'before their receipt can be sent. Tap their name to add it.';

  @override
  String taxDonorMeta(Object gifts, Object total) {
    return '$gifts offerings · $total';
  }

  @override
  String get taxReady => 'Ready';

  @override
  String get taxNeedsAddress => 'Needs address';

  @override
  String taxMoreDonors(Object count) {
    return '+ $count more donors';
  }

  @override
  String get taxEmailAll => 'Email all receipts';

  @override
  String get taxDownloadAll => 'Download all as one PDF';

  @override
  String toastTaxReady(Object name) {
    return '$name’s receipt is ready.';
  }

  @override
  String toastTaxSent(Object sent) {
    return '$sent receipts sent.';
  }

  @override
  String toastTaxSentWaiting(Object sent, Object waiting) {
    return '$sent receipts sent. $waiting waiting for an address.';
  }

  @override
  String toastTaxPdf(Object count) {
    return 'All $count receipts saved as one PDF.';
  }

  @override
  String taxAddressTitle(Object name) {
    return 'Mailing address for $name';
  }

  @override
  String get taxAddressLabel => 'Mailing address';

  @override
  String get taxAddressHint => 'Street, city, province, postal code';

  @override
  String get taxAddressSave => 'Save address';

  @override
  String toastTaxAddressSaved(Object name) {
    return 'Address saved. $name’s receipt is ready.';
  }

  @override
  String get prayersTitle => 'Prayer name lists';

  @override
  String prayersSubtitle(Object name) {
    return 'For $name · large print';
  }

  @override
  String prayersLivingCount(Object count) {
    return 'FOR THE LIVING · $count';
  }

  @override
  String prayersPassedCount(Object count) {
    return 'FOR THOSE WHO HAVE PASSED · $count';
  }

  @override
  String get prayersPrint => 'Print name lists';

  @override
  String get prayersEmpty => 'No prayer requests yet.';

  @override
  String get approveTitle => 'Approve announcements';

  @override
  String approveWaiting(Object count) {
    return '$count waiting for you';
  }

  @override
  String get approveAllDone => 'All done';

  @override
  String approveMeta(Object when, Object by, Object to) {
    return '$when · from $by · to $to';
  }

  @override
  String get approveYes => 'Approve';

  @override
  String get approveAskChanges => 'Ask for changes';

  @override
  String get approveEmptyTitle => 'Nothing is waiting for you';

  @override
  String get approveEmptyBody => 'New announcements will appear here.';

  @override
  String toastApproved(Object name) {
    return 'Approved. $name can now send it.';
  }

  @override
  String toastSentBack(Object name) {
    return 'Sent back to $name with a request for changes.';
  }

  @override
  String get checkInTitle => 'Check-in';

  @override
  String checkInAt(Object time, Object number) {
    return 'Checked in at $time · $number';
  }

  @override
  String checkInStatus(Object status, Object date) {
    return 'Membership $status · valid until $date';
  }

  @override
  String get checkInAnother => 'Check in someone else';

  @override
  String get checkInPointCamera => 'Point the camera at the member\'s card';

  @override
  String get checkInDemoScan => 'Demo only — pretend a card was scanned';

  @override
  String get checkInFindByName => 'No card? Find them by name';

  @override
  String get checkInAction => 'Check in';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsChineseLater =>
      'Chinese (Simplified and Traditional) coming later';

  @override
  String get settingsDisplay => 'DISPLAY';

  @override
  String get settingsDarkMode => 'Dark mode';

  @override
  String get settingsDarkModeSub => 'Easier on the eyes in the evening';

  @override
  String get settingsSimpleMode => 'Simple Mode';

  @override
  String get settingsSimpleModeSub => 'Larger text, fewer options';

  @override
  String get settingsThisTemple => 'THIS TEMPLE';

  @override
  String get settingsTeamRow => 'Temple team';

  @override
  String settingsTeamRowSub(Object count) {
    return '$count people · invite and set roles';
  }

  @override
  String get settingsTempleRow => 'Temple settings';

  @override
  String get settingsTempleRowSub => 'Logo, names, charity no., signature';

  @override
  String get settingsSwitchRow => 'Switch temple';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get teamTitle => 'Temple team';

  @override
  String get teamNoteAdmin =>
      'Tap a person to change what they can do. Each role gets its own simple home screen.';

  @override
  String get teamNoteOther =>
      'Only the Temple Admin can invite people or change roles.';

  @override
  String teamYouSuffix(Object name) {
    return '$name (you)';
  }

  @override
  String get teamInvitePending => 'Invite sent';

  @override
  String get teamInviteCta => 'Invite someone';

  @override
  String get teamInviteEmail => 'Their email';

  @override
  String get teamRoleQuestion => 'What will they help with?';

  @override
  String get teamInvitePreviewLabel => 'Email they will get';

  @override
  String teamInvitePreview(Object temple, Object inviter, Object role) {
    return 'Subject: You are invited to $temple\n\nTashi Delek! $inviter has invited you to help at $temple as $role.\n\nTap “Sign in” to join — no password needed. The link works for 7 days.';
  }

  @override
  String get teamSendInvite => 'Send invite';

  @override
  String teamPersonPending(Object email) {
    return '$email · invite sent, not signed in yet';
  }

  @override
  String get teamSaveRole => 'Save role';

  @override
  String get teamResendInvite => 'Resend invite';

  @override
  String get teamSeeHome => 'See their home screen';

  @override
  String get teamRemove => 'Remove from team';

  @override
  String get teamCancelInvite => 'Cancel invite';

  @override
  String toastInviteSent(Object email) {
    return 'Invite sent to $email.';
  }

  @override
  String toastInviteResent(Object email) {
    return 'Invite sent again to $email.';
  }

  @override
  String get toastNoChanges => 'No changes.';

  @override
  String toastRoleSaved(Object name, Object role) {
    return 'Saved. $name now sees the $role home screen.';
  }

  @override
  String toastTeamRemoved(Object name) {
    return '$name removed.';
  }

  @override
  String teamRemoveTitle(Object name) {
    return 'Remove $name?';
  }

  @override
  String teamRemoveBody(Object name, Object temple) {
    return '$name will no longer be able to sign in to $temple. You can invite them again later.';
  }

  @override
  String get teamRemoveYes => 'Yes, remove';

  @override
  String teamCancelInviteTitle(Object name) {
    return 'Cancel the invite for $name?';
  }

  @override
  String get teamCancelInviteBody =>
      'The sign-in link we emailed them will stop working.';

  @override
  String get teamCancelInviteYes => 'Yes, cancel invite';

  @override
  String get teamKeep => 'Keep them';

  @override
  String get templeSettingsTitle => 'Temple settings';

  @override
  String get templeSettingsLogo => 'Temple logo';

  @override
  String get templeSettingsUploadLogo => 'Upload logo';

  @override
  String get templeFieldNameEn => 'Temple name (English)';

  @override
  String get templeFieldNameBo => 'Temple name (Tibetan)';

  @override
  String get templeFieldTradition => 'Lineage and city';

  @override
  String get templeFieldAddress => 'Address';

  @override
  String get templeFieldCharity => 'Charity registration number';

  @override
  String get templeFieldSignatory => 'Name for receipt signature';

  @override
  String get templeAccentColour => 'Accent colour';

  @override
  String get accentMaroon => 'Maroon';

  @override
  String get accentSaffron => 'Saffron';

  @override
  String get accentLapisBlue => 'Lapis Blue';

  @override
  String get accentJadeGreen => 'Jade Green';

  @override
  String get accentTurquoise => 'Turquoise';

  @override
  String get accentDeepGold => 'Deep Gold';

  @override
  String get templeSaveChanges => 'Save changes';

  @override
  String get toastTempleSaved =>
      'Saved. Receipts and ID cards now use these details.';

  @override
  String get toastLogoUpdated => 'Logo updated.';

  @override
  String get sendPreviewEmail => 'Email preview';

  @override
  String get sendPreviewWhatsApp => 'WhatsApp preview';

  @override
  String get sendTo => 'To:';

  @override
  String get sendNow => 'Send now';

  @override
  String get sendNotYet => 'Not yet';

  @override
  String get toastSentWhatsApp => 'Sent on WhatsApp.';

  @override
  String get toastSentEmail => 'Email sent.';

  @override
  String msgCardBody(Object name, Object temple) {
    return 'Tashi Delek $name,\n\nWelcome to $temple! Your membership card is attached. Show it at the front desk to check in.';
  }

  @override
  String msgCardAttachment(Object number) {
    return 'Membership card $number';
  }

  @override
  String msgReceiptDonationBody(
    Object name,
    Object amount,
    Object kind,
    Object temple,
  ) {
    return 'Tashi Delek $name,\n\nThank you for your offering of $amount ($kind). Your official receipt is attached.\n\n— $temple';
  }

  @override
  String msgReceiptPujaBody(
    Object name,
    Object ceremony,
    Object date,
    Object temple,
  ) {
    return 'Tashi Delek $name,\n\nThank you for sponsoring the $ceremony on $date. Your official receipt is attached.\n\n— $temple';
  }

  @override
  String msgReceiptAttachment(Object number) {
    return 'Receipt $number.pdf';
  }

  @override
  String msgShiftBody(Object shift, Object day, Object temple) {
    return 'Tashi Delek! Thank you for helping with $shift on $day. Please reply YES to confirm, or tap the link to swap.\n\n— $temple';
  }

  @override
  String get msgShiftAttachment => 'Shift details';

  @override
  String msgPlanTo(Object count) {
    return 'All volunteers ($count people)';
  }

  @override
  String msgPlanBody(Object range, Object temple) {
    return 'Tashi Delek! Here is the volunteer plan for $range. Please check your shifts, and reply if you cannot make one.\n\n— $temple';
  }

  @override
  String msgPlanAttachment(Object range) {
    return 'Volunteer plan – $range.pdf';
  }

  @override
  String msgTaxTo(Object count) {
    return 'All $count donors, by email';
  }

  @override
  String msgTaxBody(Object year, Object temple, Object registration) {
    return 'Tashi Delek,\n\nThank you for your generous offerings in $year. Your official year-end tax receipt is attached.\n\n— $temple\n$registration';
  }

  @override
  String msgTaxAttachment(Object count) {
    return '$count receipts · one PDF per donor';
  }

  @override
  String msgAnnouncementTo(Object groups, Object count) {
    return '$groups ($count people)';
  }

  @override
  String get msgAnnouncementAttachment =>
      'Poster image + email + WhatsApp message';

  @override
  String msgLetterAttachment(Object type) {
    return '$type (signed PDF)';
  }

  @override
  String get failureNetwork =>
      'No internet connection. Please check it and try again.';

  @override
  String get failureTimeout => 'That took too long. Please try again.';

  @override
  String get failureUnauthenticated => 'Please sign in again.';

  @override
  String get failureSignInLinkInvalid =>
      'This sign-in link has expired or was already used. Please ask for a new one.';

  @override
  String get failureSignInLinkOtherDevice =>
      'Please ask for the sign-in link on this device, then open it here.';

  @override
  String get failureAccountDisabled =>
      'This account has been turned off. Please ask your Temple Admin.';

  @override
  String get failureNotOnTeam =>
      'Your email is not on a temple team yet. Please ask your Temple Admin.';

  @override
  String get failureTooManyRequests =>
      'Too many tries. Please wait a few minutes, then try again.';

  @override
  String get failurePermission => 'You do not have permission to do that.';

  @override
  String get failureAdminOnlyRoles => 'Only the Temple Admin can change roles.';

  @override
  String get failureAdminOnlySettings =>
      'Only the Temple Admin can change settings.';

  @override
  String get failureOwnRole =>
      'Another Temple Admin must change your own role.';

  @override
  String get failureNotFound =>
      'We could not find that. It may have been removed.';

  @override
  String get failureAlreadyOnTeam => 'This person is already on the team.';

  @override
  String get failureShiftFull => 'This shift is already full.';

  @override
  String get failureConflict =>
      'This was changed by someone else. Please try again.';

  @override
  String get failureUnavailable =>
      'This is not available right now. Nothing was changed.';

  @override
  String get failureNoTemple => 'Please choose a temple first.';

  @override
  String get failureUnknown => 'Something went wrong. Please try again.';

  @override
  String get validationOwnEmailRequired => 'Please type your email.';

  @override
  String get validationTheirEmailRequired => 'Please type their email.';

  @override
  String get validationEmailIncomplete =>
      'This email looks incomplete. Please check it.';

  @override
  String get validationMemberNameRequired => 'Please type the member\'s name.';

  @override
  String get validationMemberNameTooLong =>
      'This name is too long for the ID card. Please shorten it.';

  @override
  String get validationMemberNameUnsupported =>
      'Please type the name in English letters. The ID card cannot print this name.';

  @override
  String get validationPhotoRequired => 'Please add a photo for the ID card.';

  @override
  String get validationPhotoUnreadable =>
      'This photo could not be used. Please choose another.';

  @override
  String get validationPhoneShort =>
      'Phone number seems short. Please check it.';

  @override
  String get validationDonorRequired => 'Please type the donor’s name.';

  @override
  String get validationPurposeRequired =>
      'Please say what this offering is for.';

  @override
  String get validationContactIncomplete =>
      'This email or phone looks incomplete. Please check it.';

  @override
  String get validationSponsorRequired => 'Please add the sponsor’s name.';

  @override
  String get validationTempleNameRequired => 'Please keep a temple name.';

  @override
  String get validationTempleRequired =>
      'Please choose which temple this is for.';

  @override
  String get validationAddressRequired => 'Please type the mailing address.';
}
