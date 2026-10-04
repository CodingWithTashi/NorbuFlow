import 'dart:ui';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/decor.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/volunteer.dart';

extension DutyPresentation on Duty {
  String label(AppLocalizations l10n) => switch (this) {
    Duty.kitchen => l10n.dutyKitchen,
    Duty.frontDesk => l10n.dutyFrontDesk,
    Duty.cleaning => l10n.dutyCleaning,
    Duty.shrine => l10n.dutyShrine,
    Duty.pujaSetup => l10n.dutyPujaSetup,
  };

  /// Calendar colour for the duty. Always shown alongside its name.
  Color get color => switch (this) {
    Duty.kitchen => AppPalette.amber,
    Duty.frontDesk => AppPalette.flagGreen,
    Duty.cleaning => AppPalette.flagBlue,
    Duty.shrine => AppPalette.flagRed,
    Duty.pujaSetup => AppPalette.flagYellow,
  };
}

extension AvailabilityPresentation on Availability {
  String label(AppLocalizations l10n) => switch (this) {
    Availability.available => l10n.availabilityAvailable,
    Availability.busy => l10n.availabilityBusy,
    Availability.away => l10n.availabilityAway,
  };

  AppIconData get icon => switch (this) {
    Availability.available => AppIcons.check,
    Availability.busy => AppIcons.hours,
    Availability.away => AppIcons.minus,
  };

  PillTone get tone => switch (this) {
    Availability.available => PillTone.success,
    Availability.busy => PillTone.warning,
    Availability.away => PillTone.neutral,
  };
}

/// "Needs 2", or a ticked "Full", for a shift.
StatusPill shiftStatusPill(AppLocalizations l10n, Shift shift) {
  return shift.isFull
      ? StatusPill(
          label: l10n.shiftFull,
          icon: AppIcons.check,
          tone: PillTone.success,
        )
      : StatusPill(label: l10n.shiftNeeds(shift.open), tone: PillTone.danger);
}
