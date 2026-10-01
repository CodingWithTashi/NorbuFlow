import '../../../core/theme/accent_preset.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/role.dart';

/// Display names for temple-domain enums, kept out of the domain layer so it
/// stays free of localisation.
extension RoleLabels on Role {
  String label(AppLocalizations l10n) => switch (this) {
    Role.admin => l10n.roleAdmin,
    Role.geshe => l10n.roleGeshe,
    Role.accountant => l10n.roleAccountant,
    Role.frontDesk => l10n.roleFrontDesk,
    Role.coordinator => l10n.roleCoordinator,
    Role.volunteer => l10n.roleVolunteer,
    Role.member => l10n.roleMember,
  };

  String description(AppLocalizations l10n) => switch (this) {
    Role.admin => l10n.roleAdminDesc,
    Role.geshe => l10n.roleGesheDesc,
    Role.accountant => l10n.roleAccountantDesc,
    Role.frontDesk => l10n.roleFrontDeskDesc,
    Role.coordinator => l10n.roleCoordinatorDesc,
    Role.volunteer => l10n.roleVolunteerDesc,
    Role.member => l10n.roleMemberDesc,
  };
}

extension AccentLabels on AccentPreset {
  String label(AppLocalizations l10n) => switch (this) {
    AccentPreset.maroon => l10n.accentMaroon,
    AccentPreset.saffron => l10n.accentSaffron,
    AccentPreset.lapisBlue => l10n.accentLapisBlue,
    AccentPreset.jadeGreen => l10n.accentJadeGreen,
    AccentPreset.turquoise => l10n.accentTurquoise,
    AccentPreset.deepGold => l10n.accentDeepGold,
  };
}
