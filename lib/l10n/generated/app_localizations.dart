import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bo.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bo'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'NorbuFlow'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Membership, offerings & volunteers in one place'**
  String get appTagline;

  /// No description provided for @tapToBegin.
  ///
  /// In en, this message translates to:
  /// **'Tap to begin'**
  String get tapToBegin;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageEnglishShort.
  ///
  /// In en, this message translates to:
  /// **'EN'**
  String get languageEnglishShort;

  /// No description provided for @languageTibetan.
  ///
  /// In en, this message translates to:
  /// **'བོད་ཡིག'**
  String get languageTibetan;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'(optional)'**
  String get commonOptional;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// No description provided for @commonOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @commonPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get commonPrint;

  /// No description provided for @commonEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get commonEmail;

  /// No description provided for @commonWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get commonWhatsApp;

  /// No description provided for @commonPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get commonPayment;

  /// No description provided for @commonAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get commonAmount;

  /// No description provided for @commonSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone'**
  String get commonSearchHint;

  /// No description provided for @commonEmailHint.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get commonEmailHint;

  /// No description provided for @commonPeople.
  ///
  /// In en, this message translates to:
  /// **'{count} people'**
  String commonPeople(Object count);

  /// No description provided for @commonLifetime.
  ///
  /// In en, this message translates to:
  /// **'Lifetime'**
  String get commonLifetime;

  /// No description provided for @commonEmDash.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get commonEmDash;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingStart;

  /// No description provided for @onboardingCount.
  ///
  /// In en, this message translates to:
  /// **'{current} OF {total}'**
  String onboardingCount(Object current, Object total);

  /// No description provided for @onboardingMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members & ID cards'**
  String get onboardingMembersTitle;

  /// No description provided for @onboardingMembersBody.
  ///
  /// In en, this message translates to:
  /// **'Add a member in a few taps. Everyone gets a digital ID card with their English and Tibetan names.'**
  String get onboardingMembersBody;

  /// No description provided for @onboardingOfferingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Offerings & receipts'**
  String get onboardingOfferingsTitle;

  /// No description provided for @onboardingOfferingsBody.
  ///
  /// In en, this message translates to:
  /// **'Record Puja, Tsok and donations. Official tax receipts are ready to print, email or WhatsApp.'**
  String get onboardingOfferingsBody;

  /// No description provided for @onboardingVolunteersTitle.
  ///
  /// In en, this message translates to:
  /// **'Volunteers & calendar'**
  String get onboardingVolunteersTitle;

  /// No description provided for @onboardingVolunteersBody.
  ///
  /// In en, this message translates to:
  /// **'Plan shifts around practice days. Volunteers can accept or swap from their phone.'**
  String get onboardingVolunteersBody;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get loginWelcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your temple'**
  String get loginSubtitle;

  /// No description provided for @loginEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Your email'**
  String get loginEmailLabel;

  /// No description provided for @loginSendLink.
  ///
  /// In en, this message translates to:
  /// **'Email me a sign-in link'**
  String get loginSendLink;

  /// No description provided for @loginInviteOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'NorbuFlow is invite-only'**
  String get loginInviteOnlyTitle;

  /// No description provided for @loginInviteOnlyBody.
  ///
  /// In en, this message translates to:
  /// **'Use the email your temple invited. No password needed — we email you a link.'**
  String get loginInviteOnlyBody;

  /// No description provided for @checkEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkEmailTitle;

  /// No description provided for @checkEmailSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a sign-in link to'**
  String get checkEmailSentTo;

  /// No description provided for @checkEmailHelp.
  ///
  /// In en, this message translates to:
  /// **'Open the email from NorbuFlow and tap “Sign in”. The link works for 1 hour.'**
  String get checkEmailHelp;

  /// No description provided for @checkEmailSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing you in…'**
  String get checkEmailSigningIn;

  /// No description provided for @checkEmailDemo.
  ///
  /// In en, this message translates to:
  /// **'Demo only — pretend I tapped the link'**
  String get checkEmailDemo;

  /// No description provided for @checkEmailOpenMail.
  ///
  /// In en, this message translates to:
  /// **'Open my email app'**
  String get checkEmailOpenMail;

  /// No description provided for @checkEmailResend.
  ///
  /// In en, this message translates to:
  /// **'Send it again'**
  String get checkEmailResend;

  /// No description provided for @checkEmailOther.
  ///
  /// In en, this message translates to:
  /// **'Use another email'**
  String get checkEmailOther;

  /// No description provided for @toastOpeningMail.
  ///
  /// In en, this message translates to:
  /// **'Opening your email app…'**
  String get toastOpeningMail;

  /// No description provided for @toastLinkResent.
  ///
  /// In en, this message translates to:
  /// **'A new sign-in link is on its way.'**
  String get toastLinkResent;

  /// No description provided for @templesTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your temple'**
  String get templesTitle;

  /// No description provided for @templesBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{You help at 1 temple.} other{You help at {count} temples. You can switch later from the top bar.}}'**
  String templesBody(int count);

  /// No description provided for @templesYouAre.
  ///
  /// In en, this message translates to:
  /// **'You are: {role}'**
  String templesYouAre(Object role);

  /// No description provided for @templeSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get templeSwitch;

  /// No description provided for @templeSwitchSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Which temple?'**
  String get templeSwitchSheetTitle;

  /// No description provided for @templeYouAreHere.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get templeYouAreHere;

  /// No description provided for @templeSwitchConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch to {temple}?'**
  String templeSwitchConfirmTitle(Object temple);

  /// No description provided for @templeSwitchConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will see {temple}’s members, offerings and volunteers. Nothing here will be lost.'**
  String templeSwitchConfirmBody(Object temple);

  /// No description provided for @templeSwitchConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, switch temple'**
  String get templeSwitchConfirmYes;

  /// No description provided for @templeSwitchConfirmNo.
  ///
  /// In en, this message translates to:
  /// **'Stay here'**
  String get templeSwitchConfirmNo;

  /// No description provided for @toastTempleSwitched.
  ///
  /// In en, this message translates to:
  /// **'You are now working in {temple}.'**
  String toastTempleSwitched(Object temple);

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get tabMembers;

  /// No description provided for @tabOfferings.
  ///
  /// In en, this message translates to:
  /// **'Offerings'**
  String get tabOfferings;

  /// No description provided for @tabCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get tabCalendar;

  /// No description provided for @tabMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tabMore;

  /// No description provided for @previewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview:'**
  String get previewLabel;

  /// No description provided for @previewBody.
  ///
  /// In en, this message translates to:
  /// **'home screen for {role}'**
  String previewBody(Object role);

  /// No description provided for @previewExit.
  ///
  /// In en, this message translates to:
  /// **'Exit preview'**
  String get previewExit;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Tashi Delek, {name}'**
  String homeGreeting(Object name);

  /// No description provided for @homeAsk.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do today?'**
  String get homeAsk;

  /// No description provided for @tibetanDate.
  ///
  /// In en, this message translates to:
  /// **'Tibetan month {month}, day {day}'**
  String tibetanDate(Object month, Object day);

  /// No description provided for @tibetanMonth.
  ///
  /// In en, this message translates to:
  /// **'Tibetan month {month}'**
  String tibetanMonth(Object month);

  /// No description provided for @tibetanMonths.
  ///
  /// In en, this message translates to:
  /// **'Tibetan months {first}–{last}'**
  String tibetanMonths(Object first, Object last);

  /// No description provided for @tibetanMonthShort.
  ///
  /// In en, this message translates to:
  /// **'M{month} · day {day}'**
  String tibetanMonthShort(Object month, Object day);

  /// No description provided for @actionAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add a Member'**
  String get actionAddMember;

  /// No description provided for @actionRenew.
  ///
  /// In en, this message translates to:
  /// **'Renew Membership'**
  String get actionRenew;

  /// No description provided for @actionDonate.
  ///
  /// In en, this message translates to:
  /// **'Record a Donation'**
  String get actionDonate;

  /// No description provided for @actionReceipt.
  ///
  /// In en, this message translates to:
  /// **'Send a Receipt'**
  String get actionReceipt;

  /// No description provided for @actionCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get actionCheckIn;

  /// No description provided for @actionVolunteers.
  ///
  /// In en, this message translates to:
  /// **'This Month\'s Volunteers'**
  String get actionVolunteers;

  /// No description provided for @actionAnnounce.
  ///
  /// In en, this message translates to:
  /// **'Make an Announcement'**
  String get actionAnnounce;

  /// No description provided for @actionAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign a Shift'**
  String get actionAssign;

  /// No description provided for @actionLetter.
  ///
  /// In en, this message translates to:
  /// **'Volunteer Letter'**
  String get actionLetter;

  /// No description provided for @actionHours.
  ///
  /// In en, this message translates to:
  /// **'Volunteer Hours'**
  String get actionHours;

  /// No description provided for @actionReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get actionReports;

  /// No description provided for @actionTax.
  ///
  /// In en, this message translates to:
  /// **'Year-end Tax Receipts'**
  String get actionTax;

  /// No description provided for @actionTeam.
  ///
  /// In en, this message translates to:
  /// **'Temple Team'**
  String get actionTeam;

  /// No description provided for @actionPrayers.
  ///
  /// In en, this message translates to:
  /// **'Prayer Name Lists'**
  String get actionPrayers;

  /// No description provided for @actionPujaRequests.
  ///
  /// In en, this message translates to:
  /// **'Puja Requests'**
  String get actionPujaRequests;

  /// No description provided for @actionCalendar.
  ///
  /// In en, this message translates to:
  /// **'Temple Calendar'**
  String get actionCalendar;

  /// No description provided for @actionApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve Announcements'**
  String get actionApprove;

  /// No description provided for @actionPlan.
  ///
  /// In en, this message translates to:
  /// **'Volunteer Plan'**
  String get actionPlan;

  /// No description provided for @actionMyShifts.
  ///
  /// In en, this message translates to:
  /// **'My Shifts'**
  String get actionMyShifts;

  /// No description provided for @actionMyCard.
  ///
  /// In en, this message translates to:
  /// **'My ID Card'**
  String get actionMyCard;

  /// No description provided for @actionAddMemberSub.
  ///
  /// In en, this message translates to:
  /// **'New member + ID'**
  String get actionAddMemberSub;

  /// No description provided for @actionRenewSub.
  ///
  /// In en, this message translates to:
  /// **'Add one year'**
  String get actionRenewSub;

  /// No description provided for @actionDonateSub.
  ///
  /// In en, this message translates to:
  /// **'Puja, Tsok, lamps'**
  String get actionDonateSub;

  /// No description provided for @actionReceiptSub.
  ///
  /// In en, this message translates to:
  /// **'Print or send'**
  String get actionReceiptSub;

  /// No description provided for @actionCheckInSub.
  ///
  /// In en, this message translates to:
  /// **'Scan member QR'**
  String get actionCheckInSub;

  /// No description provided for @actionVolunteersSub.
  ///
  /// In en, this message translates to:
  /// **'This month\'s plan'**
  String get actionVolunteersSub;

  /// No description provided for @actionAnnounceSub.
  ///
  /// In en, this message translates to:
  /// **'Poster or message'**
  String get actionAnnounceSub;

  /// No description provided for @actionAssignSub.
  ///
  /// In en, this message translates to:
  /// **'Fill open shifts'**
  String get actionAssignSub;

  /// No description provided for @actionLetterSub.
  ///
  /// In en, this message translates to:
  /// **'Thanks, certificate'**
  String get actionLetterSub;

  /// No description provided for @actionHoursSub.
  ///
  /// In en, this message translates to:
  /// **'By person'**
  String get actionHoursSub;

  /// No description provided for @actionReportsSub.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get actionReportsSub;

  /// No description provided for @actionTaxSub.
  ///
  /// In en, this message translates to:
  /// **'Year-end bundle'**
  String get actionTaxSub;

  /// No description provided for @actionTeamSub.
  ///
  /// In en, this message translates to:
  /// **'Invite, set roles'**
  String get actionTeamSub;

  /// No description provided for @actionPrayersSub.
  ///
  /// In en, this message translates to:
  /// **'By ceremony'**
  String get actionPrayersSub;

  /// No description provided for @actionPujaRequestsSub.
  ///
  /// In en, this message translates to:
  /// **'To review'**
  String get actionPujaRequestsSub;

  /// No description provided for @actionCalendarSub.
  ///
  /// In en, this message translates to:
  /// **'Practice days'**
  String get actionCalendarSub;

  /// No description provided for @actionApproveSub.
  ///
  /// In en, this message translates to:
  /// **'Waiting for you'**
  String get actionApproveSub;

  /// No description provided for @actionPlanSub.
  ///
  /// In en, this message translates to:
  /// **'Week or month PDF'**
  String get actionPlanSub;

  /// No description provided for @actionMyShiftsSub.
  ///
  /// In en, this message translates to:
  /// **'Accept or swap'**
  String get actionMyShiftsSub;

  /// No description provided for @actionMyCardSub.
  ///
  /// In en, this message translates to:
  /// **'Show at desk'**
  String get actionMyCardSub;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Temple Admin'**
  String get roleAdmin;

  /// No description provided for @roleAdminDesc.
  ///
  /// In en, this message translates to:
  /// **'Everything for this temple, including settings and people'**
  String get roleAdminDesc;

  /// No description provided for @roleGeshe.
  ///
  /// In en, this message translates to:
  /// **'Geshe / Lama'**
  String get roleGeshe;

  /// No description provided for @roleGesheDesc.
  ///
  /// In en, this message translates to:
  /// **'Sees Puja requests, prayer name lists and the calendar. Approves announcements.'**
  String get roleGesheDesc;

  /// No description provided for @roleAccountant.
  ///
  /// In en, this message translates to:
  /// **'Accountant / Treasurer'**
  String get roleAccountant;

  /// No description provided for @roleAccountantDesc.
  ///
  /// In en, this message translates to:
  /// **'Donations, membership payments, receipts and reports'**
  String get roleAccountantDesc;

  /// No description provided for @roleFrontDesk.
  ///
  /// In en, this message translates to:
  /// **'Front Desk Volunteer'**
  String get roleFrontDesk;

  /// No description provided for @roleFrontDeskDesc.
  ///
  /// In en, this message translates to:
  /// **'Adds and renews members, records donations, sends receipts'**
  String get roleFrontDeskDesc;

  /// No description provided for @roleCoordinator.
  ///
  /// In en, this message translates to:
  /// **'Volunteer Coordinator'**
  String get roleCoordinator;

  /// No description provided for @roleCoordinatorDesc.
  ///
  /// In en, this message translates to:
  /// **'Plans the volunteer calendar and writes volunteer letters'**
  String get roleCoordinatorDesc;

  /// No description provided for @roleVolunteer.
  ///
  /// In en, this message translates to:
  /// **'Volunteer'**
  String get roleVolunteer;

  /// No description provided for @roleVolunteerDesc.
  ///
  /// In en, this message translates to:
  /// **'Sees their own shifts and hours'**
  String get roleVolunteerDesc;

  /// No description provided for @roleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @roleMemberDesc.
  ///
  /// In en, this message translates to:
  /// **'Their own ID card, renewals, donations and Puja requests'**
  String get roleMemberDesc;

  /// No description provided for @membersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersTitle;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String membersCount(Object count);

  /// No description provided for @membersExpiringCount.
  ///
  /// In en, this message translates to:
  /// **'{count} expiring'**
  String membersExpiringCount(Object count);

  /// No description provided for @membersExpiredCount.
  ///
  /// In en, this message translates to:
  /// **'{count} expired'**
  String membersExpiredCount(Object count);

  /// No description provided for @membersFoundCount.
  ///
  /// In en, this message translates to:
  /// **'{count} found'**
  String membersFoundCount(Object count);

  /// No description provided for @membersNoResults.
  ///
  /// In en, this message translates to:
  /// **'No one found for “{query}”.'**
  String membersNoResults(Object query);

  /// No description provided for @membersNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Check the spelling, or try a phone number.'**
  String get membersNoResultsHint;

  /// No description provided for @membersAddCta.
  ///
  /// In en, this message translates to:
  /// **'+ Add a Member'**
  String get membersAddCta;

  /// No description provided for @membersSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a member to see their ID card.'**
  String get membersSelectHint;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusExpiring.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get statusExpiring;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @wizardStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String wizardStepOf(Object step, Object total);

  /// No description provided for @wizardProgressSaved.
  ///
  /// In en, this message translates to:
  /// **'Progress saved'**
  String get wizardProgressSaved;

  /// No description provided for @addFlowName.
  ///
  /// In en, this message translates to:
  /// **'Add a Member'**
  String get addFlowName;

  /// No description provided for @addStepPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get addStepPhoto;

  /// No description provided for @addStepDetails.
  ///
  /// In en, this message translates to:
  /// **'Member details'**
  String get addStepDetails;

  /// No description provided for @addStepType.
  ///
  /// In en, this message translates to:
  /// **'Membership type'**
  String get addStepType;

  /// No description provided for @addStepPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get addStepPayment;

  /// No description provided for @addTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get addTakePhoto;

  /// No description provided for @addUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload photo'**
  String get addUploadPhoto;

  /// No description provided for @addPhotoHelp.
  ///
  /// In en, this message translates to:
  /// **'The photo goes on the member\'s ID card. You can skip this and add it later.'**
  String get addPhotoHelp;

  /// No description provided for @addCropHelp.
  ///
  /// In en, this message translates to:
  /// **'Drag the photo to move it. Slide to zoom.\nThe circle is exactly what shows on the ID card.'**
  String get addCropHelp;

  /// No description provided for @addCropZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get addCropZoom;

  /// No description provided for @addChooseDifferentPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a different photo'**
  String get addChooseDifferentPhoto;

  /// No description provided for @addPhotoReady.
  ///
  /// In en, this message translates to:
  /// **'Photo ready for the ID card'**
  String get addPhotoReady;

  /// No description provided for @addAdjustCrop.
  ///
  /// In en, this message translates to:
  /// **'Adjust the crop'**
  String get addAdjustCrop;

  /// No description provided for @addUseThisPhoto.
  ///
  /// In en, this message translates to:
  /// **'Use this photo'**
  String get addUseThisPhoto;

  /// No description provided for @toastPhotoCropped.
  ///
  /// In en, this message translates to:
  /// **'Photo cropped to fit the ID card.'**
  String get toastPhotoCropped;

  /// No description provided for @addFieldNameEn.
  ///
  /// In en, this message translates to:
  /// **'Name in English'**
  String get addFieldNameEn;

  /// No description provided for @addFieldNameEnHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Tenzin Dolkar'**
  String get addFieldNameEnHint;

  /// No description provided for @addFieldNameBo.
  ///
  /// In en, this message translates to:
  /// **'Name in Tibetan'**
  String get addFieldNameBo;

  /// No description provided for @addFieldNameBoHint.
  ///
  /// In en, this message translates to:
  /// **'བོད་ཡིག་ནང་མིང་།'**
  String get addFieldNameBoHint;

  /// No description provided for @addFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get addFieldPhone;

  /// No description provided for @addFieldPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 416 555 0142'**
  String get addFieldPhoneHint;

  /// No description provided for @addFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get addFieldEmail;

  /// No description provided for @membershipIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get membershipIndividual;

  /// No description provided for @membershipIndividualSub.
  ///
  /// In en, this message translates to:
  /// **'One person, 1 year'**
  String get membershipIndividualSub;

  /// No description provided for @membershipFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get membershipFamily;

  /// No description provided for @membershipFamilySub.
  ///
  /// In en, this message translates to:
  /// **'Up to 5 people at one address, 1 year'**
  String get membershipFamilySub;

  /// No description provided for @membershipSenior.
  ///
  /// In en, this message translates to:
  /// **'Senior / Student'**
  String get membershipSenior;

  /// No description provided for @membershipSeniorSub.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get membershipSeniorSub;

  /// No description provided for @membershipLife.
  ///
  /// In en, this message translates to:
  /// **'Life member'**
  String get membershipLife;

  /// No description provided for @membershipLifeSub.
  ///
  /// In en, this message translates to:
  /// **'One payment, never expires'**
  String get membershipLifeSub;

  /// No description provided for @addFilledForYou.
  ///
  /// In en, this message translates to:
  /// **'FILLED IN FOR YOU'**
  String get addFilledForYou;

  /// No description provided for @addMemberNumber.
  ///
  /// In en, this message translates to:
  /// **'Member number'**
  String get addMemberNumber;

  /// No description provided for @addValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get addValidUntil;

  /// No description provided for @addRenewalReminders.
  ///
  /// In en, this message translates to:
  /// **'Renewal reminders go out by email 30 days before, 7 days before, and on the expiry day.'**
  String get addRenewalReminders;

  /// No description provided for @addSummaryLine.
  ///
  /// In en, this message translates to:
  /// **'{name} · {type}'**
  String addSummaryLine(Object name, Object type);

  /// No description provided for @addSummaryMeta.
  ///
  /// In en, this message translates to:
  /// **'Member no. {number} · Valid until {date}'**
  String addSummaryMeta(Object number, Object date);

  /// No description provided for @addHowPaying.
  ///
  /// In en, this message translates to:
  /// **'How are they paying?'**
  String get addHowPaying;

  /// No description provided for @payCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get payCash;

  /// No description provided for @payCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get payCard;

  /// No description provided for @payTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get payTransfer;

  /// No description provided for @payCheque.
  ///
  /// In en, this message translates to:
  /// **'Cheque'**
  String get payCheque;

  /// No description provided for @addSubmit.
  ///
  /// In en, this message translates to:
  /// **'Add member · {price}'**
  String addSubmit(Object price);

  /// No description provided for @addSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} is now a member'**
  String addSuccessTitle(Object name);

  /// No description provided for @addSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'Member number {number}. Payment recorded and a welcome email is ready to send.'**
  String addSuccessBody(Object number);

  /// No description provided for @addViewCard.
  ///
  /// In en, this message translates to:
  /// **'View ID card'**
  String get addViewCard;

  /// No description provided for @membersNewCard.
  ///
  /// In en, this message translates to:
  /// **'New ID card'**
  String get membersNewCard;

  /// No description provided for @newCardTitle.
  ///
  /// In en, this message translates to:
  /// **'New ID card'**
  String get newCardTitle;

  /// No description provided for @newCardIntro.
  ///
  /// In en, this message translates to:
  /// **'Add a photo and the member\'s details. The membership number and dates are filled in for you.'**
  String get newCardIntro;

  /// No description provided for @newCardNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name on the card'**
  String get newCardNameLabel;

  /// No description provided for @newCardPhotoHelp.
  ///
  /// In en, this message translates to:
  /// **'The photo is printed on the ID card.'**
  String get newCardPhotoHelp;

  /// No description provided for @newCardCropHelp.
  ///
  /// In en, this message translates to:
  /// **'Drag the photo to move it. Slide to zoom.\nThe frame is exactly what prints on the ID card.'**
  String get newCardCropHelp;

  /// No description provided for @newCardSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create ID card'**
  String get newCardSubmit;

  /// No description provided for @newCardReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'ID card ready'**
  String get newCardReadyTitle;

  /// No description provided for @newCardReadyBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is member number {number}. Valid until {date}.'**
  String newCardReadyBody(Object name, Object number, Object date);

  /// No description provided for @newCardDocumentName.
  ///
  /// In en, this message translates to:
  /// **'ID card {number}'**
  String newCardDocumentName(Object number);

  /// No description provided for @newCardFront.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get newCardFront;

  /// No description provided for @newCardBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get newCardBack;

  /// No description provided for @newCardPrint.
  ///
  /// In en, this message translates to:
  /// **'Print the card'**
  String get newCardPrint;

  /// No description provided for @newCardShare.
  ///
  /// In en, this message translates to:
  /// **'Save or send'**
  String get newCardShare;

  /// No description provided for @newCardAnother.
  ///
  /// In en, this message translates to:
  /// **'Another card'**
  String get newCardAnother;

  /// No description provided for @cardTitle.
  ///
  /// In en, this message translates to:
  /// **'Membership Card'**
  String get cardTitle;

  /// No description provided for @cardMemberNo.
  ///
  /// In en, this message translates to:
  /// **'Member no.'**
  String get cardMemberNo;

  /// No description provided for @cardValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get cardValidUntil;

  /// No description provided for @cardType.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get cardType;

  /// No description provided for @cardShare.
  ///
  /// In en, this message translates to:
  /// **'Share card'**
  String get cardShare;

  /// No description provided for @cardAddToWallet.
  ///
  /// In en, this message translates to:
  /// **'Add to Wallet'**
  String get cardAddToWallet;

  /// No description provided for @cardRenew.
  ///
  /// In en, this message translates to:
  /// **'Renew 1 year'**
  String get cardRenew;

  /// No description provided for @cardValidUntilDate.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String cardValidUntilDate(Object date);

  /// No description provided for @cardNotFound.
  ///
  /// In en, this message translates to:
  /// **'This member could not be found.'**
  String get cardNotFound;

  /// No description provided for @toastRenewed.
  ///
  /// In en, this message translates to:
  /// **'Renewed. Valid until {date}.'**
  String toastRenewed(Object date);

  /// No description provided for @toastPrinted.
  ///
  /// In en, this message translates to:
  /// **'Sent to the Front Desk printer.'**
  String get toastPrinted;

  /// No description provided for @toastWallet.
  ///
  /// In en, this message translates to:
  /// **'Card added to Wallet.'**
  String get toastWallet;

  /// No description provided for @offeringsTitle.
  ///
  /// In en, this message translates to:
  /// **'Record an offering'**
  String get offeringsTitle;

  /// No description provided for @offeringsAsk.
  ///
  /// In en, this message translates to:
  /// **'What is this payment for?'**
  String get offeringsAsk;

  /// No description provided for @offeringMembership.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get offeringMembership;

  /// No description provided for @offeringMembershipSub.
  ///
  /// In en, this message translates to:
  /// **'New or renewal'**
  String get offeringMembershipSub;

  /// No description provided for @offeringDonation.
  ///
  /// In en, this message translates to:
  /// **'Donation'**
  String get offeringDonation;

  /// No description provided for @offeringDonationSub.
  ///
  /// In en, this message translates to:
  /// **'Any amount'**
  String get offeringDonationSub;

  /// No description provided for @offeringPuja.
  ///
  /// In en, this message translates to:
  /// **'Puja'**
  String get offeringPuja;

  /// No description provided for @offeringPujaSub.
  ///
  /// In en, this message translates to:
  /// **'Prayers by Sangha'**
  String get offeringPujaSub;

  /// No description provided for @offeringTsok.
  ///
  /// In en, this message translates to:
  /// **'Tsok'**
  String get offeringTsok;

  /// No description provided for @offeringTsokSub.
  ///
  /// In en, this message translates to:
  /// **'Feast offering'**
  String get offeringTsokSub;

  /// No description provided for @offeringButterLamp.
  ///
  /// In en, this message translates to:
  /// **'Butter Lamp'**
  String get offeringButterLamp;

  /// No description provided for @offeringButterLampSub.
  ///
  /// In en, this message translates to:
  /// **'Light offering'**
  String get offeringButterLampSub;

  /// No description provided for @offeringBuildingFund.
  ///
  /// In en, this message translates to:
  /// **'Building Fund'**
  String get offeringBuildingFund;

  /// No description provided for @offeringBuildingFundSub.
  ///
  /// In en, this message translates to:
  /// **'New shrine hall'**
  String get offeringBuildingFundSub;

  /// No description provided for @offeringOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get offeringOther;

  /// No description provided for @offeringOtherSub.
  ///
  /// In en, this message translates to:
  /// **'Write the purpose'**
  String get offeringOtherSub;

  /// No description provided for @pujaFlowName.
  ///
  /// In en, this message translates to:
  /// **'Puja / Tsok request'**
  String get pujaFlowName;

  /// No description provided for @pujaStepCeremony.
  ///
  /// In en, this message translates to:
  /// **'Ceremony and date'**
  String get pujaStepCeremony;

  /// No description provided for @pujaStepNames.
  ///
  /// In en, this message translates to:
  /// **'Names for prayers'**
  String get pujaStepNames;

  /// No description provided for @pujaStepSponsor.
  ///
  /// In en, this message translates to:
  /// **'Sponsor and offering'**
  String get pujaStepSponsor;

  /// No description provided for @pujaStepReview.
  ///
  /// In en, this message translates to:
  /// **'Check and save'**
  String get pujaStepReview;

  /// No description provided for @pujaCeremony.
  ///
  /// In en, this message translates to:
  /// **'Ceremony'**
  String get pujaCeremony;

  /// No description provided for @pujaDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get pujaDate;

  /// No description provided for @pujaLivingTitle.
  ///
  /// In en, this message translates to:
  /// **'For the living'**
  String get pujaLivingTitle;

  /// No description provided for @pujaLivingSub.
  ///
  /// In en, this message translates to:
  /// **'Long life, health and protection'**
  String get pujaLivingSub;

  /// No description provided for @pujaPassedTitle.
  ///
  /// In en, this message translates to:
  /// **'For those who have passed'**
  String get pujaPassedTitle;

  /// No description provided for @pujaPassedSub.
  ///
  /// In en, this message translates to:
  /// **'For a good rebirth'**
  String get pujaPassedSub;

  /// No description provided for @pujaNameHint.
  ///
  /// In en, this message translates to:
  /// **'Type a name (English or Tibetan)'**
  String get pujaNameHint;

  /// No description provided for @toastNameRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed “{name}”.'**
  String toastNameRemoved(Object name);

  /// No description provided for @pujaSponsorName.
  ///
  /// In en, this message translates to:
  /// **'Sponsor name'**
  String get pujaSponsorName;

  /// No description provided for @pujaReceiptContact.
  ///
  /// In en, this message translates to:
  /// **'Email or phone for the receipt'**
  String get pujaReceiptContact;

  /// No description provided for @pujaDedication.
  ///
  /// In en, this message translates to:
  /// **'Dedication'**
  String get pujaDedication;

  /// No description provided for @pujaOfferingAmount.
  ///
  /// In en, this message translates to:
  /// **'Offering amount'**
  String get pujaOfferingAmount;

  /// No description provided for @pujaReviewIntro.
  ///
  /// In en, this message translates to:
  /// **'Please check everything before saving.'**
  String get pujaReviewIntro;

  /// No description provided for @pujaReviewLiving.
  ///
  /// In en, this message translates to:
  /// **'Names for the living'**
  String get pujaReviewLiving;

  /// No description provided for @pujaReviewPassed.
  ///
  /// In en, this message translates to:
  /// **'Names for those who have passed'**
  String get pujaReviewPassed;

  /// No description provided for @pujaReviewSponsor.
  ///
  /// In en, this message translates to:
  /// **'Sponsor'**
  String get pujaReviewSponsor;

  /// No description provided for @pujaReviewOffering.
  ///
  /// In en, this message translates to:
  /// **'Offering'**
  String get pujaReviewOffering;

  /// No description provided for @pujaSubmit.
  ///
  /// In en, this message translates to:
  /// **'Save offering · {amount}'**
  String pujaSubmit(Object amount);

  /// No description provided for @practiceMedicineBuddha.
  ///
  /// In en, this message translates to:
  /// **'Medicine Buddha Day'**
  String get practiceMedicineBuddha;

  /// No description provided for @practiceGuruRinpoche.
  ///
  /// In en, this message translates to:
  /// **'Guru Rinpoche Day'**
  String get practiceGuruRinpoche;

  /// No description provided for @practiceFullMoon.
  ///
  /// In en, this message translates to:
  /// **'Full Moon'**
  String get practiceFullMoon;

  /// No description provided for @practiceDakini.
  ///
  /// In en, this message translates to:
  /// **'Dakini Day'**
  String get practiceDakini;

  /// No description provided for @practiceNewMoon.
  ///
  /// In en, this message translates to:
  /// **'New Moon'**
  String get practiceNewMoon;

  /// No description provided for @offeringRecordedTitle.
  ///
  /// In en, this message translates to:
  /// **'Offering recorded'**
  String get offeringRecordedTitle;

  /// No description provided for @offeringRecordedPuja.
  ///
  /// In en, this message translates to:
  /// **'{ceremony} on {date}. The names have been added to the Geshe’s prayer list. Receipt {number} is ready.'**
  String offeringRecordedPuja(Object ceremony, Object date, Object number);

  /// No description provided for @offeringRecordedDonation.
  ///
  /// In en, this message translates to:
  /// **'{amount} {kind} from {donor}. Receipt {number} is ready.'**
  String offeringRecordedDonation(
    Object amount,
    Object kind,
    Object donor,
    Object number,
  );

  /// No description provided for @offeringViewReceipt.
  ///
  /// In en, this message translates to:
  /// **'View receipt'**
  String get offeringViewReceipt;

  /// No description provided for @receiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Official Donation Receipt'**
  String get receiptTitle;

  /// No description provided for @receiptFrom.
  ///
  /// In en, this message translates to:
  /// **'Received from'**
  String get receiptFrom;

  /// No description provided for @receiptAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount received'**
  String get receiptAmount;

  /// No description provided for @receiptFor.
  ///
  /// In en, this message translates to:
  /// **'Offering for'**
  String get receiptFor;

  /// No description provided for @receiptDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get receiptDate;

  /// No description provided for @receiptNames.
  ///
  /// In en, this message translates to:
  /// **'Names for prayers'**
  String get receiptNames;

  /// No description provided for @receiptTax.
  ///
  /// In en, this message translates to:
  /// **'Official receipt for income tax purposes.'**
  String get receiptTax;

  /// No description provided for @receiptThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your generous offering.'**
  String get receiptThanks;

  /// No description provided for @receiptSignature.
  ///
  /// In en, this message translates to:
  /// **'Authorised signature'**
  String get receiptSignature;

  /// No description provided for @receiptPassedSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (passed)'**
  String receiptPassedSuffix(Object name);

  /// No description provided for @receiptEmpty.
  ///
  /// In en, this message translates to:
  /// **'No receipts yet. Record an offering to create one.'**
  String get receiptEmpty;

  /// No description provided for @donationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record an offering · a receipt is made for you'**
  String get donationSubtitle;

  /// No description provided for @donationDonor.
  ///
  /// In en, this message translates to:
  /// **'Donor name'**
  String get donationDonor;

  /// No description provided for @donationNote.
  ///
  /// In en, this message translates to:
  /// **'Note on the receipt'**
  String get donationNote;

  /// No description provided for @donationNoteOther.
  ///
  /// In en, this message translates to:
  /// **'What is it for?'**
  String get donationNoteOther;

  /// No description provided for @donationNoteHintDonation.
  ///
  /// In en, this message translates to:
  /// **'e.g. In memory of my mother'**
  String get donationNoteHintDonation;

  /// No description provided for @donationNoteHintButterLamp.
  ///
  /// In en, this message translates to:
  /// **'Names for the lamp dedication'**
  String get donationNoteHintButterLamp;

  /// No description provided for @donationNoteHintBuildingFund.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sponsor a brick'**
  String get donationNoteHintBuildingFund;

  /// No description provided for @donationNoteHintOther.
  ///
  /// In en, this message translates to:
  /// **'What is this offering for?'**
  String get donationNoteHintOther;

  /// No description provided for @donationSubmit.
  ///
  /// In en, this message translates to:
  /// **'Record {amount} {kind}'**
  String donationSubmit(Object amount, Object kind);

  /// No description provided for @calendarPlanButton.
  ///
  /// In en, this message translates to:
  /// **'Weekly or monthly plan (PDF)'**
  String get calendarPlanButton;

  /// No description provided for @calendarPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get calendarPreviousMonth;

  /// No description provided for @calendarNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get calendarNextMonth;

  /// No description provided for @calendarNeedsPeople.
  ///
  /// In en, this message translates to:
  /// **'Needs people'**
  String get calendarNeedsPeople;

  /// No description provided for @calendarNoShifts.
  ///
  /// In en, this message translates to:
  /// **'No shifts on this day.'**
  String get calendarNoShifts;

  /// No description provided for @dutyKitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get dutyKitchen;

  /// No description provided for @dutyFrontDesk.
  ///
  /// In en, this message translates to:
  /// **'Front desk'**
  String get dutyFrontDesk;

  /// No description provided for @dutyCleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get dutyCleaning;

  /// No description provided for @dutyShrine.
  ///
  /// In en, this message translates to:
  /// **'Shrine'**
  String get dutyShrine;

  /// No description provided for @dutyPujaSetup.
  ///
  /// In en, this message translates to:
  /// **'Puja setup'**
  String get dutyPujaSetup;

  /// No description provided for @shiftNoOneYet.
  ///
  /// In en, this message translates to:
  /// **'No one yet'**
  String get shiftNoOneYet;

  /// No description provided for @shiftNeeds.
  ///
  /// In en, this message translates to:
  /// **'Needs {count}'**
  String shiftNeeds(Object count);

  /// No description provided for @shiftFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get shiftFull;

  /// No description provided for @calendarAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign volunteers'**
  String get calendarAssign;

  /// No description provided for @calendarAllFull.
  ///
  /// In en, this message translates to:
  /// **'All shifts are full'**
  String get calendarAllFull;

  /// No description provided for @toastAllShiftsFull.
  ///
  /// In en, this message translates to:
  /// **'Every shift on this day is full.'**
  String get toastAllShiftsFull;

  /// No description provided for @assignTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign volunteers'**
  String get assignTitle;

  /// No description provided for @assignNeedsMore.
  ///
  /// In en, this message translates to:
  /// **'needs {count} more'**
  String assignNeedsMore(Object count);

  /// No description provided for @availabilityAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availabilityAvailable;

  /// No description provided for @availabilityBusy.
  ///
  /// In en, this message translates to:
  /// **'Busy'**
  String get availabilityBusy;

  /// No description provided for @availabilityAway.
  ///
  /// In en, this message translates to:
  /// **'Away'**
  String get availabilityAway;

  /// No description provided for @assignAlreadyOnShift.
  ///
  /// In en, this message translates to:
  /// **'Already on this shift'**
  String get assignAlreadyOnShift;

  /// No description provided for @toastVolunteerAway.
  ///
  /// In en, this message translates to:
  /// **'{name} is away that day.'**
  String toastVolunteerAway(Object name);

  /// No description provided for @toastVolunteerBusy.
  ///
  /// In en, this message translates to:
  /// **'{name} is already on a shift.'**
  String toastVolunteerBusy(Object name);

  /// No description provided for @toastShiftLimit.
  ///
  /// In en, this message translates to:
  /// **'This shift only needs {count} more.'**
  String toastShiftLimit(Object count);

  /// No description provided for @assignCta.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Assign 1 volunteer} other{Assign {count} volunteers}}'**
  String assignCta(int count);

  /// No description provided for @assignCtaEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap names above to choose'**
  String get assignCtaEmpty;

  /// No description provided for @assignSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift filled'**
  String get assignSuccessTitle;

  /// No description provided for @assignSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'{names} will help with {shift} on {day}.'**
  String assignSuccessBody(Object names, Object shift, Object day);

  /// No description provided for @assignMessageThem.
  ///
  /// In en, this message translates to:
  /// **'Message them'**
  String get assignMessageThem;

  /// No description provided for @listAnd.
  ///
  /// In en, this message translates to:
  /// **'{first} and {last}'**
  String listAnd(Object first, Object last);

  /// No description provided for @planTitle.
  ///
  /// In en, this message translates to:
  /// **'Volunteer plan'**
  String get planTitle;

  /// No description provided for @planWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get planWeekly;

  /// No description provided for @planMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get planMonthly;

  /// No description provided for @planDocumentTitle.
  ///
  /// In en, this message translates to:
  /// **'{temple} — Volunteer plan'**
  String planDocumentTitle(Object temple);

  /// No description provided for @planPrinted.
  ///
  /// In en, this message translates to:
  /// **'Printed {date}'**
  String planPrinted(Object date);

  /// No description provided for @planWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {range}'**
  String planWeekOf(Object range);

  /// No description provided for @planColDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get planColDate;

  /// No description provided for @planColTibetan.
  ///
  /// In en, this message translates to:
  /// **'Tibetan'**
  String get planColTibetan;

  /// No description provided for @planColDuty.
  ///
  /// In en, this message translates to:
  /// **'Duty'**
  String get planColDuty;

  /// No description provided for @planLegendNeeds.
  ///
  /// In en, this message translates to:
  /// **'= still looking for volunteers'**
  String get planLegendNeeds;

  /// No description provided for @planLegendGrey.
  ///
  /// In en, this message translates to:
  /// **'Grey = no shift that day'**
  String get planLegendGrey;

  /// No description provided for @planLegendPractice.
  ///
  /// In en, this message translates to:
  /// **'practice days'**
  String get planLegendPractice;

  /// No description provided for @planDownload.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get planDownload;

  /// No description provided for @planEmailTeam.
  ///
  /// In en, this message translates to:
  /// **'Email to team'**
  String get planEmailTeam;

  /// No description provided for @toastPlanSaved.
  ///
  /// In en, this message translates to:
  /// **'Volunteer plan saved as PDF.'**
  String get toastPlanSaved;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get navMembers;

  /// No description provided for @navOfferings.
  ///
  /// In en, this message translates to:
  /// **'Offerings'**
  String get navOfferings;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @letterTitle.
  ///
  /// In en, this message translates to:
  /// **'Volunteer letter'**
  String get letterTitle;

  /// No description provided for @letterIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick a volunteer and a letter type. A draft is written for you to check and edit.'**
  String get letterIntro;

  /// No description provided for @letterStepVolunteer.
  ///
  /// In en, this message translates to:
  /// **'1 · Volunteer'**
  String get letterStepVolunteer;

  /// No description provided for @letterStepType.
  ///
  /// In en, this message translates to:
  /// **'2 · Type of letter'**
  String get letterStepType;

  /// No description provided for @letterStepDraft.
  ///
  /// In en, this message translates to:
  /// **'3 · Draft'**
  String get letterStepDraft;

  /// No description provided for @letterTypeThanks.
  ///
  /// In en, this message translates to:
  /// **'Thank-you letter'**
  String get letterTypeThanks;

  /// No description provided for @letterTypeThanksDesc.
  ///
  /// In en, this message translates to:
  /// **'A warm thank-you for their service'**
  String get letterTypeThanksDesc;

  /// No description provided for @letterTypeReference.
  ///
  /// In en, this message translates to:
  /// **'Reference letter'**
  String get letterTypeReference;

  /// No description provided for @letterTypeReferenceDesc.
  ///
  /// In en, this message translates to:
  /// **'For a job, school or visa application'**
  String get letterTypeReferenceDesc;

  /// No description provided for @letterTypeCertificate.
  ///
  /// In en, this message translates to:
  /// **'Certificate of service'**
  String get letterTypeCertificate;

  /// No description provided for @letterTypeCertificateDesc.
  ///
  /// In en, this message translates to:
  /// **'Hours served this year, signed by the temple'**
  String get letterTypeCertificateDesc;

  /// No description provided for @improveWording.
  ///
  /// In en, this message translates to:
  /// **'Improve wording'**
  String get improveWording;

  /// No description provided for @improveWordingBusy.
  ///
  /// In en, this message translates to:
  /// **'Improving…'**
  String get improveWordingBusy;

  /// No description provided for @toastWordingImproved.
  ///
  /// In en, this message translates to:
  /// **'Wording improved. Please read it before sending.'**
  String get toastWordingImproved;

  /// No description provided for @letterCheck.
  ///
  /// In en, this message translates to:
  /// **'Please read it through. You can change any word before it is sent.'**
  String get letterCheck;

  /// No description provided for @letterApproveSend.
  ///
  /// In en, this message translates to:
  /// **'Approve and send'**
  String get letterApproveSend;

  /// No description provided for @letterPrint.
  ///
  /// In en, this message translates to:
  /// **'Print on letterhead'**
  String get letterPrint;

  /// No description provided for @toastLetterEmpty.
  ///
  /// In en, this message translates to:
  /// **'The letter is empty. Please write something first.'**
  String get toastLetterEmpty;

  /// No description provided for @toastLetterSent.
  ///
  /// In en, this message translates to:
  /// **'Letter sent to {name}.'**
  String toastLetterSent(Object name);

  /// No description provided for @announceTitle.
  ///
  /// In en, this message translates to:
  /// **'Make an announcement'**
  String get announceTitle;

  /// No description provided for @announceStepTemplate.
  ///
  /// In en, this message translates to:
  /// **'1 · Choose a template'**
  String get announceStepTemplate;

  /// No description provided for @announceStepFill.
  ///
  /// In en, this message translates to:
  /// **'2 · Fill in the blanks'**
  String get announceStepFill;

  /// No description provided for @announceFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get announceFieldTitle;

  /// No description provided for @announceFieldWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get announceFieldWhen;

  /// No description provided for @announceFieldDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get announceFieldDetails;

  /// No description provided for @announceStepPreview.
  ///
  /// In en, this message translates to:
  /// **'3 · Preview'**
  String get announceStepPreview;

  /// No description provided for @announceViewPoster.
  ///
  /// In en, this message translates to:
  /// **'Poster'**
  String get announceViewPoster;

  /// No description provided for @announceStepSendTo.
  ///
  /// In en, this message translates to:
  /// **'4 · Send to'**
  String get announceStepSendTo;

  /// No description provided for @announceSendCta.
  ///
  /// In en, this message translates to:
  /// **'Preview and send to {count} people'**
  String announceSendCta(Object count);

  /// No description provided for @announceSendCtaEmpty.
  ///
  /// In en, this message translates to:
  /// **'Choose who to send it to'**
  String get announceSendCtaEmpty;

  /// No description provided for @toastChooseGroup.
  ///
  /// In en, this message translates to:
  /// **'Please choose at least one group.'**
  String get toastChooseGroup;

  /// No description provided for @toastAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Please add a title.'**
  String get toastAddTitle;

  /// No description provided for @announceEmailFrom.
  ///
  /// In en, this message translates to:
  /// **'From:'**
  String get announceEmailFrom;

  /// No description provided for @announceEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject:'**
  String get announceEmailSubject;

  /// No description provided for @announceEmailGreeting.
  ///
  /// In en, this message translates to:
  /// **'Tashi Delek,'**
  String get announceEmailGreeting;

  /// No description provided for @announceEmailSignoff.
  ///
  /// In en, this message translates to:
  /// **'With warm wishes,'**
  String get announceEmailSignoff;

  /// No description provided for @toastAnnouncementSent.
  ///
  /// In en, this message translates to:
  /// **'Announcement sent to {count} people.'**
  String toastAnnouncementSent(Object count);

  /// No description provided for @hoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Volunteer hours'**
  String get hoursTitle;

  /// No description provided for @hoursPeriod.
  ///
  /// In en, this message translates to:
  /// **'January – {month} {year}'**
  String hoursPeriod(Object month, Object year);

  /// No description provided for @hoursTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'hours from {count} volunteers'**
  String hoursTotalLabel(Object count);

  /// No description provided for @hoursValue.
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String hoursValue(Object hours);

  /// No description provided for @hoursRowMeta.
  ///
  /// In en, this message translates to:
  /// **'{duties} · since {year}'**
  String hoursRowMeta(Object duties, Object year);

  /// No description provided for @hoursWriteThanks.
  ///
  /// In en, this message translates to:
  /// **'Write a thank-you letter'**
  String get hoursWriteThanks;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsOfferingsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Offerings this month'**
  String get reportsOfferingsThisMonth;

  /// No description provided for @reportsChangeUp.
  ///
  /// In en, this message translates to:
  /// **'Up {percent}% from {month}'**
  String reportsChangeUp(Object percent, Object month);

  /// No description provided for @reportsChangeDown.
  ///
  /// In en, this message translates to:
  /// **'Down {percent}% from {month}'**
  String reportsChangeDown(Object percent, Object month);

  /// No description provided for @reportsByType.
  ///
  /// In en, this message translates to:
  /// **'By type'**
  String get reportsByType;

  /// No description provided for @reportsMembershipsDue.
  ///
  /// In en, this message translates to:
  /// **'Memberships due'**
  String get reportsMembershipsDue;

  /// No description provided for @reportsSeeMembers.
  ///
  /// In en, this message translates to:
  /// **'See these members'**
  String get reportsSeeMembers;

  /// No description provided for @reportsExportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get reportsExportPdf;

  /// No description provided for @reportsExportExcel.
  ///
  /// In en, this message translates to:
  /// **'Export Excel'**
  String get reportsExportExcel;

  /// No description provided for @toastReportPdf.
  ///
  /// In en, this message translates to:
  /// **'Report saved as PDF.'**
  String get toastReportPdf;

  /// No description provided for @toastReportExcel.
  ///
  /// In en, this message translates to:
  /// **'Report saved as an Excel file.'**
  String get toastReportExcel;

  /// No description provided for @reportCategoryPuja.
  ///
  /// In en, this message translates to:
  /// **'Puja & Tsok'**
  String get reportCategoryPuja;

  /// No description provided for @reportCategoryMembership.
  ///
  /// In en, this message translates to:
  /// **'Membership'**
  String get reportCategoryMembership;

  /// No description provided for @reportCategoryBuildingFund.
  ///
  /// In en, this message translates to:
  /// **'Building Fund'**
  String get reportCategoryBuildingFund;

  /// No description provided for @reportCategoryButterLamp.
  ///
  /// In en, this message translates to:
  /// **'Butter Lamp'**
  String get reportCategoryButterLamp;

  /// No description provided for @reportCategoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General donations'**
  String get reportCategoryGeneral;

  /// No description provided for @taxTitle.
  ///
  /// In en, this message translates to:
  /// **'Year-end tax receipts'**
  String get taxTitle;

  /// No description provided for @taxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tax year {year} · one receipt per donor'**
  String taxSubtitle(Object year);

  /// No description provided for @taxDonors.
  ///
  /// In en, this message translates to:
  /// **'Donors'**
  String get taxDonors;

  /// No description provided for @taxTotalGiven.
  ///
  /// In en, this message translates to:
  /// **'Total given'**
  String get taxTotalGiven;

  /// No description provided for @taxMissingLead.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 donor needs a mailing address} other{{count} donors need a mailing address}}'**
  String taxMissingLead(int count);

  /// No description provided for @taxMissingRest.
  ///
  /// In en, this message translates to:
  /// **'before their receipt can be sent. Tap their name to add it.'**
  String get taxMissingRest;

  /// No description provided for @taxDonorMeta.
  ///
  /// In en, this message translates to:
  /// **'{gifts} offerings · {total}'**
  String taxDonorMeta(Object gifts, Object total);

  /// No description provided for @taxReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get taxReady;

  /// No description provided for @taxNeedsAddress.
  ///
  /// In en, this message translates to:
  /// **'Needs address'**
  String get taxNeedsAddress;

  /// No description provided for @taxMoreDonors.
  ///
  /// In en, this message translates to:
  /// **'+ {count} more donors'**
  String taxMoreDonors(Object count);

  /// No description provided for @taxEmailAll.
  ///
  /// In en, this message translates to:
  /// **'Email all receipts'**
  String get taxEmailAll;

  /// No description provided for @taxDownloadAll.
  ///
  /// In en, this message translates to:
  /// **'Download all as one PDF'**
  String get taxDownloadAll;

  /// No description provided for @toastTaxReady.
  ///
  /// In en, this message translates to:
  /// **'{name}’s receipt is ready.'**
  String toastTaxReady(Object name);

  /// No description provided for @toastTaxSent.
  ///
  /// In en, this message translates to:
  /// **'{sent} receipts sent.'**
  String toastTaxSent(Object sent);

  /// No description provided for @toastTaxSentWaiting.
  ///
  /// In en, this message translates to:
  /// **'{sent} receipts sent. {waiting} waiting for an address.'**
  String toastTaxSentWaiting(Object sent, Object waiting);

  /// No description provided for @toastTaxPdf.
  ///
  /// In en, this message translates to:
  /// **'All {count} receipts saved as one PDF.'**
  String toastTaxPdf(Object count);

  /// No description provided for @taxAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Mailing address for {name}'**
  String taxAddressTitle(Object name);

  /// No description provided for @taxAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Mailing address'**
  String get taxAddressLabel;

  /// No description provided for @taxAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Street, city, province, postal code'**
  String get taxAddressHint;

  /// No description provided for @taxAddressSave.
  ///
  /// In en, this message translates to:
  /// **'Save address'**
  String get taxAddressSave;

  /// No description provided for @toastTaxAddressSaved.
  ///
  /// In en, this message translates to:
  /// **'Address saved. {name}’s receipt is ready.'**
  String toastTaxAddressSaved(Object name);

  /// No description provided for @prayersTitle.
  ///
  /// In en, this message translates to:
  /// **'Prayer name lists'**
  String get prayersTitle;

  /// No description provided for @prayersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For {name} · large print'**
  String prayersSubtitle(Object name);

  /// No description provided for @prayersLivingCount.
  ///
  /// In en, this message translates to:
  /// **'FOR THE LIVING · {count}'**
  String prayersLivingCount(Object count);

  /// No description provided for @prayersPassedCount.
  ///
  /// In en, this message translates to:
  /// **'FOR THOSE WHO HAVE PASSED · {count}'**
  String prayersPassedCount(Object count);

  /// No description provided for @prayersPrint.
  ///
  /// In en, this message translates to:
  /// **'Print name lists'**
  String get prayersPrint;

  /// No description provided for @prayersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No prayer requests yet.'**
  String get prayersEmpty;

  /// No description provided for @approveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve announcements'**
  String get approveTitle;

  /// No description provided for @approveWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting for you'**
  String approveWaiting(Object count);

  /// No description provided for @approveAllDone.
  ///
  /// In en, this message translates to:
  /// **'All done'**
  String get approveAllDone;

  /// No description provided for @approveMeta.
  ///
  /// In en, this message translates to:
  /// **'{when} · from {by} · to {to}'**
  String approveMeta(Object when, Object by, Object to);

  /// No description provided for @approveYes.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approveYes;

  /// No description provided for @approveAskChanges.
  ///
  /// In en, this message translates to:
  /// **'Ask for changes'**
  String get approveAskChanges;

  /// No description provided for @approveEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing is waiting for you'**
  String get approveEmptyTitle;

  /// No description provided for @approveEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'New announcements will appear here.'**
  String get approveEmptyBody;

  /// No description provided for @toastApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved. {name} can now send it.'**
  String toastApproved(Object name);

  /// No description provided for @toastSentBack.
  ///
  /// In en, this message translates to:
  /// **'Sent back to {name} with a request for changes.'**
  String toastSentBack(Object name);

  /// No description provided for @checkInTitle.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get checkInTitle;

  /// No description provided for @checkInAt.
  ///
  /// In en, this message translates to:
  /// **'Checked in at {time} · {number}'**
  String checkInAt(Object time, Object number);

  /// No description provided for @checkInStatus.
  ///
  /// In en, this message translates to:
  /// **'Membership {status} · valid until {date}'**
  String checkInStatus(Object status, Object date);

  /// No description provided for @checkInAnother.
  ///
  /// In en, this message translates to:
  /// **'Check in someone else'**
  String get checkInAnother;

  /// No description provided for @checkInPointCamera.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the member\'s card'**
  String get checkInPointCamera;

  /// No description provided for @checkInDemoScan.
  ///
  /// In en, this message translates to:
  /// **'Demo only — pretend a card was scanned'**
  String get checkInDemoScan;

  /// No description provided for @checkInFindByName.
  ///
  /// In en, this message translates to:
  /// **'No card? Find them by name'**
  String get checkInFindByName;

  /// No description provided for @checkInAction.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get checkInAction;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsChineseLater.
  ///
  /// In en, this message translates to:
  /// **'Chinese (Simplified and Traditional) coming later'**
  String get settingsChineseLater;

  /// No description provided for @settingsDisplay.
  ///
  /// In en, this message translates to:
  /// **'DISPLAY'**
  String get settingsDisplay;

  /// No description provided for @settingsDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get settingsDarkMode;

  /// No description provided for @settingsDarkModeSub.
  ///
  /// In en, this message translates to:
  /// **'Easier on the eyes in the evening'**
  String get settingsDarkModeSub;

  /// No description provided for @settingsSimpleMode.
  ///
  /// In en, this message translates to:
  /// **'Simple Mode'**
  String get settingsSimpleMode;

  /// No description provided for @settingsSimpleModeSub.
  ///
  /// In en, this message translates to:
  /// **'Larger text, fewer options'**
  String get settingsSimpleModeSub;

  /// No description provided for @settingsThisTemple.
  ///
  /// In en, this message translates to:
  /// **'THIS TEMPLE'**
  String get settingsThisTemple;

  /// No description provided for @settingsTeamRow.
  ///
  /// In en, this message translates to:
  /// **'Temple team'**
  String get settingsTeamRow;

  /// No description provided for @settingsTeamRowSub.
  ///
  /// In en, this message translates to:
  /// **'{count} people · invite and set roles'**
  String settingsTeamRowSub(Object count);

  /// No description provided for @settingsTempleRow.
  ///
  /// In en, this message translates to:
  /// **'Temple settings'**
  String get settingsTempleRow;

  /// No description provided for @settingsTempleRowSub.
  ///
  /// In en, this message translates to:
  /// **'Logo, names, charity no., signature'**
  String get settingsTempleRowSub;

  /// No description provided for @settingsSwitchRow.
  ///
  /// In en, this message translates to:
  /// **'Switch temple'**
  String get settingsSwitchRow;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @teamTitle.
  ///
  /// In en, this message translates to:
  /// **'Temple team'**
  String get teamTitle;

  /// No description provided for @teamNoteAdmin.
  ///
  /// In en, this message translates to:
  /// **'Tap a person to change what they can do. Each role gets its own simple home screen.'**
  String get teamNoteAdmin;

  /// No description provided for @teamNoteOther.
  ///
  /// In en, this message translates to:
  /// **'Only the Temple Admin can invite people or change roles.'**
  String get teamNoteOther;

  /// No description provided for @teamYouSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String teamYouSuffix(Object name);

  /// No description provided for @teamInvitePending.
  ///
  /// In en, this message translates to:
  /// **'Invite sent'**
  String get teamInvitePending;

  /// No description provided for @teamInviteCta.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get teamInviteCta;

  /// No description provided for @teamInviteEmail.
  ///
  /// In en, this message translates to:
  /// **'Their email'**
  String get teamInviteEmail;

  /// No description provided for @teamRoleQuestion.
  ///
  /// In en, this message translates to:
  /// **'What will they help with?'**
  String get teamRoleQuestion;

  /// No description provided for @teamInvitePreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Email they will get'**
  String get teamInvitePreviewLabel;

  /// No description provided for @teamInvitePreview.
  ///
  /// In en, this message translates to:
  /// **'Subject: You are invited to {temple}\n\nTashi Delek! {inviter} has invited you to help at {temple} as {role}.\n\nTap “Sign in” to join — no password needed. The link works for 7 days.'**
  String teamInvitePreview(Object temple, Object inviter, Object role);

  /// No description provided for @teamSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get teamSendInvite;

  /// No description provided for @teamPersonPending.
  ///
  /// In en, this message translates to:
  /// **'{email} · invite sent, not signed in yet'**
  String teamPersonPending(Object email);

  /// No description provided for @teamSaveRole.
  ///
  /// In en, this message translates to:
  /// **'Save role'**
  String get teamSaveRole;

  /// No description provided for @teamResendInvite.
  ///
  /// In en, this message translates to:
  /// **'Resend invite'**
  String get teamResendInvite;

  /// No description provided for @teamSeeHome.
  ///
  /// In en, this message translates to:
  /// **'See their home screen'**
  String get teamSeeHome;

  /// No description provided for @teamRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from team'**
  String get teamRemove;

  /// No description provided for @teamCancelInvite.
  ///
  /// In en, this message translates to:
  /// **'Cancel invite'**
  String get teamCancelInvite;

  /// No description provided for @toastInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invite sent to {email}.'**
  String toastInviteSent(Object email);

  /// No description provided for @toastInviteResent.
  ///
  /// In en, this message translates to:
  /// **'Invite sent again to {email}.'**
  String toastInviteResent(Object email);

  /// No description provided for @toastNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes.'**
  String get toastNoChanges;

  /// No description provided for @toastRoleSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved. {name} now sees the {role} home screen.'**
  String toastRoleSaved(Object name, Object role);

  /// No description provided for @toastTeamRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed.'**
  String toastTeamRemoved(Object name);

  /// No description provided for @teamRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String teamRemoveTitle(Object name);

  /// No description provided for @teamRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will no longer be able to sign in to {temple}. You can invite them again later.'**
  String teamRemoveBody(Object name, Object temple);

  /// No description provided for @teamRemoveYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, remove'**
  String get teamRemoveYes;

  /// No description provided for @teamCancelInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel the invite for {name}?'**
  String teamCancelInviteTitle(Object name);

  /// No description provided for @teamCancelInviteBody.
  ///
  /// In en, this message translates to:
  /// **'The sign-in link we emailed them will stop working.'**
  String get teamCancelInviteBody;

  /// No description provided for @teamCancelInviteYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, cancel invite'**
  String get teamCancelInviteYes;

  /// No description provided for @teamKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep them'**
  String get teamKeep;

  /// No description provided for @templeSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Temple settings'**
  String get templeSettingsTitle;

  /// No description provided for @templeSettingsLogo.
  ///
  /// In en, this message translates to:
  /// **'Temple logo'**
  String get templeSettingsLogo;

  /// No description provided for @templeSettingsUploadLogo.
  ///
  /// In en, this message translates to:
  /// **'Upload logo'**
  String get templeSettingsUploadLogo;

  /// No description provided for @templeFieldNameEn.
  ///
  /// In en, this message translates to:
  /// **'Temple name (English)'**
  String get templeFieldNameEn;

  /// No description provided for @templeFieldNameBo.
  ///
  /// In en, this message translates to:
  /// **'Temple name (Tibetan)'**
  String get templeFieldNameBo;

  /// No description provided for @templeFieldTradition.
  ///
  /// In en, this message translates to:
  /// **'Lineage and city'**
  String get templeFieldTradition;

  /// No description provided for @templeFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get templeFieldAddress;

  /// No description provided for @templeFieldCharity.
  ///
  /// In en, this message translates to:
  /// **'Charity registration number'**
  String get templeFieldCharity;

  /// No description provided for @templeFieldSignatory.
  ///
  /// In en, this message translates to:
  /// **'Name for receipt signature'**
  String get templeFieldSignatory;

  /// No description provided for @templeAccentColour.
  ///
  /// In en, this message translates to:
  /// **'Accent colour'**
  String get templeAccentColour;

  /// No description provided for @accentMaroon.
  ///
  /// In en, this message translates to:
  /// **'Maroon'**
  String get accentMaroon;

  /// No description provided for @accentSaffron.
  ///
  /// In en, this message translates to:
  /// **'Saffron'**
  String get accentSaffron;

  /// No description provided for @accentLapisBlue.
  ///
  /// In en, this message translates to:
  /// **'Lapis Blue'**
  String get accentLapisBlue;

  /// No description provided for @accentJadeGreen.
  ///
  /// In en, this message translates to:
  /// **'Jade Green'**
  String get accentJadeGreen;

  /// No description provided for @accentTurquoise.
  ///
  /// In en, this message translates to:
  /// **'Turquoise'**
  String get accentTurquoise;

  /// No description provided for @accentDeepGold.
  ///
  /// In en, this message translates to:
  /// **'Deep Gold'**
  String get accentDeepGold;

  /// No description provided for @templeSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get templeSaveChanges;

  /// No description provided for @toastTempleSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved. Receipts and ID cards now use these details.'**
  String get toastTempleSaved;

  /// No description provided for @toastLogoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Logo updated.'**
  String get toastLogoUpdated;

  /// No description provided for @sendPreviewEmail.
  ///
  /// In en, this message translates to:
  /// **'Email preview'**
  String get sendPreviewEmail;

  /// No description provided for @sendPreviewWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp preview'**
  String get sendPreviewWhatsApp;

  /// No description provided for @sendTo.
  ///
  /// In en, this message translates to:
  /// **'To:'**
  String get sendTo;

  /// No description provided for @sendNow.
  ///
  /// In en, this message translates to:
  /// **'Send now'**
  String get sendNow;

  /// No description provided for @sendNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get sendNotYet;

  /// No description provided for @toastSentWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Sent on WhatsApp.'**
  String get toastSentWhatsApp;

  /// No description provided for @toastSentEmail.
  ///
  /// In en, this message translates to:
  /// **'Email sent.'**
  String get toastSentEmail;

  /// No description provided for @msgCardBody.
  ///
  /// In en, this message translates to:
  /// **'Tashi Delek {name},\n\nWelcome to {temple}! Your membership card is attached. Show it at the front desk to check in.'**
  String msgCardBody(Object name, Object temple);

  /// No description provided for @msgCardAttachment.
  ///
  /// In en, this message translates to:
  /// **'Membership card {number}'**
  String msgCardAttachment(Object number);

  /// No description provided for @msgReceiptDonationBody.
  ///
  /// In en, this message translates to:
  /// **'Tashi Delek {name},\n\nThank you for your offering of {amount} ({kind}). Your official receipt is attached.\n\n— {temple}'**
  String msgReceiptDonationBody(
    Object name,
    Object amount,
    Object kind,
    Object temple,
  );

  /// No description provided for @msgReceiptPujaBody.
  ///
  /// In en, this message translates to:
  /// **'Tashi Delek {name},\n\nThank you for sponsoring the {ceremony} on {date}. Your official receipt is attached.\n\n— {temple}'**
  String msgReceiptPujaBody(
    Object name,
    Object ceremony,
    Object date,
    Object temple,
  );

  /// No description provided for @msgReceiptAttachment.
  ///
  /// In en, this message translates to:
  /// **'Receipt {number}.pdf'**
  String msgReceiptAttachment(Object number);

  /// No description provided for @msgShiftBody.
  ///
  /// In en, this message translates to:
  /// **'Tashi Delek! Thank you for helping with {shift} on {day}. Please reply YES to confirm, or tap the link to swap.\n\n— {temple}'**
  String msgShiftBody(Object shift, Object day, Object temple);

  /// No description provided for @msgShiftAttachment.
  ///
  /// In en, this message translates to:
  /// **'Shift details'**
  String get msgShiftAttachment;

  /// No description provided for @msgPlanTo.
  ///
  /// In en, this message translates to:
  /// **'All volunteers ({count} people)'**
  String msgPlanTo(Object count);

  /// No description provided for @msgPlanBody.
  ///
  /// In en, this message translates to:
  /// **'Tashi Delek! Here is the volunteer plan for {range}. Please check your shifts, and reply if you cannot make one.\n\n— {temple}'**
  String msgPlanBody(Object range, Object temple);

  /// No description provided for @msgPlanAttachment.
  ///
  /// In en, this message translates to:
  /// **'Volunteer plan – {range}.pdf'**
  String msgPlanAttachment(Object range);

  /// No description provided for @msgTaxTo.
  ///
  /// In en, this message translates to:
  /// **'All {count} donors, by email'**
  String msgTaxTo(Object count);

  /// No description provided for @msgTaxBody.
  ///
  /// In en, this message translates to:
  /// **'Tashi Delek,\n\nThank you for your generous offerings in {year}. Your official year-end tax receipt is attached.\n\n— {temple}\n{registration}'**
  String msgTaxBody(Object year, Object temple, Object registration);

  /// No description provided for @msgTaxAttachment.
  ///
  /// In en, this message translates to:
  /// **'{count} receipts · one PDF per donor'**
  String msgTaxAttachment(Object count);

  /// No description provided for @msgAnnouncementTo.
  ///
  /// In en, this message translates to:
  /// **'{groups} ({count} people)'**
  String msgAnnouncementTo(Object groups, Object count);

  /// No description provided for @msgAnnouncementAttachment.
  ///
  /// In en, this message translates to:
  /// **'Poster image + email + WhatsApp message'**
  String get msgAnnouncementAttachment;

  /// No description provided for @msgLetterAttachment.
  ///
  /// In en, this message translates to:
  /// **'{type} (signed PDF)'**
  String msgLetterAttachment(Object type);

  /// No description provided for @failureNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Please check it and try again.'**
  String get failureNetwork;

  /// No description provided for @failureTimeout.
  ///
  /// In en, this message translates to:
  /// **'That took too long. Please try again.'**
  String get failureTimeout;

  /// No description provided for @failureUnauthenticated.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get failureUnauthenticated;

  /// No description provided for @failureSignInLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'This sign-in link has expired or was already used. Please ask for a new one.'**
  String get failureSignInLinkInvalid;

  /// No description provided for @failureSignInLinkOtherDevice.
  ///
  /// In en, this message translates to:
  /// **'Please ask for the sign-in link on this device, then open it here.'**
  String get failureSignInLinkOtherDevice;

  /// No description provided for @failureAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been turned off. Please ask your Temple Admin.'**
  String get failureAccountDisabled;

  /// No description provided for @failureNotOnTeam.
  ///
  /// In en, this message translates to:
  /// **'Your email is not on a temple team yet. Please ask your Temple Admin.'**
  String get failureNotOnTeam;

  /// No description provided for @failureTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Please wait a few minutes, then try again.'**
  String get failureTooManyRequests;

  /// No description provided for @failurePermission.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do that.'**
  String get failurePermission;

  /// No description provided for @failureAdminOnlyRoles.
  ///
  /// In en, this message translates to:
  /// **'Only the Temple Admin can change roles.'**
  String get failureAdminOnlyRoles;

  /// No description provided for @failureAdminOnlySettings.
  ///
  /// In en, this message translates to:
  /// **'Only the Temple Admin can change settings.'**
  String get failureAdminOnlySettings;

  /// No description provided for @failureOwnRole.
  ///
  /// In en, this message translates to:
  /// **'Another Temple Admin must change your own role.'**
  String get failureOwnRole;

  /// No description provided for @failureNotFound.
  ///
  /// In en, this message translates to:
  /// **'We could not find that. It may have been removed.'**
  String get failureNotFound;

  /// No description provided for @failureAlreadyOnTeam.
  ///
  /// In en, this message translates to:
  /// **'This person is already on the team.'**
  String get failureAlreadyOnTeam;

  /// No description provided for @failureShiftFull.
  ///
  /// In en, this message translates to:
  /// **'This shift is already full.'**
  String get failureShiftFull;

  /// No description provided for @failureConflict.
  ///
  /// In en, this message translates to:
  /// **'This was changed by someone else. Please try again.'**
  String get failureConflict;

  /// No description provided for @failureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This is not available right now. Nothing was changed.'**
  String get failureUnavailable;

  /// No description provided for @failureNoTemple.
  ///
  /// In en, this message translates to:
  /// **'Please choose a temple first.'**
  String get failureNoTemple;

  /// No description provided for @failureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get failureUnknown;

  /// No description provided for @validationOwnEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please type your email.'**
  String get validationOwnEmailRequired;

  /// No description provided for @validationTheirEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please type their email.'**
  String get validationTheirEmailRequired;

  /// No description provided for @validationEmailIncomplete.
  ///
  /// In en, this message translates to:
  /// **'This email looks incomplete. Please check it.'**
  String get validationEmailIncomplete;

  /// No description provided for @validationMemberNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please type the member\'s name.'**
  String get validationMemberNameRequired;

  /// No description provided for @validationMemberNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'This name is too long for the ID card. Please shorten it.'**
  String get validationMemberNameTooLong;

  /// No description provided for @validationMemberNameUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Please type the name in English letters. The ID card cannot print this name.'**
  String get validationMemberNameUnsupported;

  /// No description provided for @validationPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Please add a photo for the ID card.'**
  String get validationPhotoRequired;

  /// No description provided for @validationPhotoUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This photo could not be used. Please choose another.'**
  String get validationPhotoUnreadable;

  /// No description provided for @validationPhoneShort.
  ///
  /// In en, this message translates to:
  /// **'Phone number seems short. Please check it.'**
  String get validationPhoneShort;

  /// No description provided for @validationDonorRequired.
  ///
  /// In en, this message translates to:
  /// **'Please type the donor’s name.'**
  String get validationDonorRequired;

  /// No description provided for @validationPurposeRequired.
  ///
  /// In en, this message translates to:
  /// **'Please say what this offering is for.'**
  String get validationPurposeRequired;

  /// No description provided for @validationContactIncomplete.
  ///
  /// In en, this message translates to:
  /// **'This email or phone looks incomplete. Please check it.'**
  String get validationContactIncomplete;

  /// No description provided for @validationSponsorRequired.
  ///
  /// In en, this message translates to:
  /// **'Please add the sponsor’s name.'**
  String get validationSponsorRequired;

  /// No description provided for @validationTempleNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please keep a temple name.'**
  String get validationTempleNameRequired;

  /// No description provided for @validationTempleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please choose which temple this is for.'**
  String get validationTempleRequired;

  /// No description provided for @validationAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Please type the mailing address.'**
  String get validationAddressRequired;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bo', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bo':
      return AppLocalizationsBo();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
