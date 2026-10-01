import 'package:flutter/widgets.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/decor.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../temple/domain/temple.dart';
import '../domain/member.dart';

extension MembershipTypeLabels on MembershipType {
  String label(AppLocalizations l10n) => switch (this) {
    MembershipType.individual => l10n.membershipIndividual,
    MembershipType.family => l10n.membershipFamily,
    MembershipType.seniorStudent => l10n.membershipSenior,
    MembershipType.life => l10n.membershipLife,
  };

  String description(AppLocalizations l10n) => switch (this) {
    MembershipType.individual => l10n.membershipIndividualSub,
    MembershipType.family => l10n.membershipFamilySub,
    MembershipType.seniorStudent => l10n.membershipSeniorSub,
    MembershipType.life => l10n.membershipLifeSub,
  };
}

extension PaymentMethodLabels on PaymentMethod {
  String label(AppLocalizations l10n) => switch (this) {
    PaymentMethod.cash => l10n.payCash,
    PaymentMethod.card => l10n.payCard,
    PaymentMethod.transfer => l10n.payTransfer,
    PaymentMethod.cheque => l10n.payCheque,
  };
}

extension MembershipStatusPresentation on MembershipStatus {
  String label(AppLocalizations l10n) => switch (this) {
    MembershipStatus.active => l10n.statusActive,
    MembershipStatus.expiring => l10n.statusExpiring,
    MembershipStatus.expired => l10n.statusExpired,
  };

  /// Paired with the label so status never depends on colour alone.
  AppIconData get icon => switch (this) {
    MembershipStatus.active => AppIcons.check,
    MembershipStatus.expiring => AppIcons.hours,
    MembershipStatus.expired => AppIcons.alert,
  };

  PillTone get tone => switch (this) {
    MembershipStatus.active => PillTone.success,
    MembershipStatus.expiring => PillTone.warning,
    MembershipStatus.expired => PillTone.danger,
  };
}

/// `JC-0142`: the temple's monogram and the zero-padded member number.
String memberNumberLabel(Temple temple, int number) =>
    '${temple.monogram}-${number.toString().padLeft(4, '0')}';

class MembershipStatusPill extends StatelessWidget {
  const MembershipStatusPill(this.status, {super.key});

  final MembershipStatus status;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: status.label(context.l10n),
      icon: status.icon,
      tone: status.tone,
    );
  }
}
