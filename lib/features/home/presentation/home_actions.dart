import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../members/presentation/view_models/members_view_model.dart';
import '../../offerings/presentation/view_models/offering_providers.dart';
import '../../temple/domain/role.dart';

/// How each [HomeAction] is presented and where it leads. Adding an action
/// means adding it to the enum and to each switch here; the compiler points
/// out anything missed.
extension HomeActionPresentation on HomeAction {
  AppIconData get icon => switch (this) {
    HomeAction.addMember || HomeAction.assign => AppIcons.addPerson,
    HomeAction.renew => AppIcons.renew,
    HomeAction.donate || HomeAction.pujaRequests => AppIcons.lamp,
    HomeAction.receipt => AppIcons.receipt,
    HomeAction.checkIn => AppIcons.qr,
    HomeAction.volunteers || HomeAction.calendar => AppIcons.calendar,
    HomeAction.announce => AppIcons.announce,
    HomeAction.letter || HomeAction.prayers => AppIcons.letter,
    HomeAction.hours || HomeAction.myShifts => AppIcons.hours,
    HomeAction.reports => AppIcons.chart,
    HomeAction.tax => AppIcons.bundle,
    HomeAction.team => AppIcons.members,
    HomeAction.approve => AppIcons.check,
    HomeAction.plan => AppIcons.document,
    HomeAction.myCard => AppIcons.idCard,
  };

  String label(AppLocalizations l10n) => switch (this) {
    HomeAction.addMember => l10n.actionAddMember,
    HomeAction.renew => l10n.actionRenew,
    HomeAction.donate => l10n.actionDonate,
    HomeAction.receipt => l10n.actionReceipt,
    HomeAction.checkIn => l10n.actionCheckIn,
    HomeAction.volunteers => l10n.actionVolunteers,
    HomeAction.announce => l10n.actionAnnounce,
    HomeAction.assign => l10n.actionAssign,
    HomeAction.letter => l10n.actionLetter,
    HomeAction.hours => l10n.actionHours,
    HomeAction.reports => l10n.actionReports,
    HomeAction.tax => l10n.actionTax,
    HomeAction.team => l10n.actionTeam,
    HomeAction.prayers => l10n.actionPrayers,
    HomeAction.pujaRequests => l10n.actionPujaRequests,
    HomeAction.calendar => l10n.actionCalendar,
    HomeAction.approve => l10n.actionApprove,
    HomeAction.plan => l10n.actionPlan,
    HomeAction.myShifts => l10n.actionMyShifts,
    HomeAction.myCard => l10n.actionMyCard,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    HomeAction.addMember => l10n.actionAddMemberSub,
    HomeAction.renew => l10n.actionRenewSub,
    HomeAction.donate => l10n.actionDonateSub,
    HomeAction.receipt => l10n.actionReceiptSub,
    HomeAction.checkIn => l10n.actionCheckInSub,
    HomeAction.volunteers => l10n.actionVolunteersSub,
    HomeAction.announce => l10n.actionAnnounceSub,
    HomeAction.assign => l10n.actionAssignSub,
    HomeAction.letter => l10n.actionLetterSub,
    HomeAction.hours => l10n.actionHoursSub,
    HomeAction.reports => l10n.actionReportsSub,
    HomeAction.tax => l10n.actionTaxSub,
    HomeAction.team => l10n.actionTeamSub,
    HomeAction.prayers => l10n.actionPrayersSub,
    HomeAction.pujaRequests => l10n.actionPujaRequestsSub,
    HomeAction.calendar => l10n.actionCalendarSub,
    HomeAction.approve => l10n.actionApproveSub,
    HomeAction.plan => l10n.actionPlanSub,
    HomeAction.myShifts => l10n.actionMyShiftsSub,
    HomeAction.myCard => l10n.actionMyCardSub,
  };

  void open(BuildContext context, WidgetRef ref) {
    final location = switch (this) {
      HomeAction.addMember => AppRoutes.addMember,
      HomeAction.renew => AppRoutes.members,
      HomeAction.donate => AppRoutes.offerings,
      HomeAction.receipt => AppRoutes.receipt(latestReceiptKey),
      HomeAction.checkIn => AppRoutes.checkIn,
      HomeAction.volunteers ||
      HomeAction.assign ||
      HomeAction.calendar ||
      HomeAction.myShifts => AppRoutes.calendar,
      HomeAction.announce => AppRoutes.announce,
      HomeAction.letter => AppRoutes.letters,
      HomeAction.hours => AppRoutes.hours,
      HomeAction.reports => AppRoutes.reports,
      HomeAction.tax => AppRoutes.tax,
      HomeAction.team => AppRoutes.team,
      HomeAction.prayers => AppRoutes.prayers,
      HomeAction.pujaRequests => AppRoutes.puja,
      HomeAction.approve => AppRoutes.approve,
      HomeAction.plan => AppRoutes.plan,
      HomeAction.myCard => _myCardLocation(ref),
    };
    context.go(location);
  }

  /// The demo has no link between a login and a member record yet, so "My
  /// ID Card" opens the first member's card.
  static String _myCardLocation(WidgetRef ref) {
    final members = ref.read(membersProvider).value;
    return members == null || members.isEmpty
        ? AppRoutes.members
        : AppRoutes.member(members.first.id);
  }
}
