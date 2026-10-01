import '../../../core/calendar/tibetan_calendar.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/offering.dart';

extension OfferingKindLabels on OfferingKind {
  String label(AppLocalizations l10n) => switch (this) {
    OfferingKind.donation => l10n.offeringDonation,
    OfferingKind.butterLamp => l10n.offeringButterLamp,
    OfferingKind.buildingFund => l10n.offeringBuildingFund,
    OfferingKind.other => l10n.offeringOther,
  };

  /// Example text for the note field, suited to the kind of offering.
  String noteHint(AppLocalizations l10n) => switch (this) {
    OfferingKind.donation => l10n.donationNoteHintDonation,
    OfferingKind.butterLamp => l10n.donationNoteHintButterLamp,
    OfferingKind.buildingFund => l10n.donationNoteHintBuildingFund,
    OfferingKind.other => l10n.donationNoteHintOther,
  };
}

extension PracticeDayLabels on PracticeDay {
  /// The mark shown beside the day on calendars, so practice days are
  /// recognisable without relying on colour.
  AppIconData get icon => switch (this) {
    PracticeDay.medicineBuddha => AppIcons.diamond,
    PracticeDay.guruRinpoche => AppIcons.star,
    PracticeDay.fullMoon => AppIcons.disc,
    PracticeDay.dakini => AppIcons.quadDiamond,
    PracticeDay.newMoon => AppIcons.ring,
  };

  String label(AppLocalizations l10n) => switch (this) {
    PracticeDay.medicineBuddha => l10n.practiceMedicineBuddha,
    PracticeDay.guruRinpoche => l10n.practiceGuruRinpoche,
    PracticeDay.fullMoon => l10n.practiceFullMoon,
    PracticeDay.dakini => l10n.practiceDakini,
    PracticeDay.newMoon => l10n.practiceNewMoon,
  };
}

extension ReceiptLabels on Receipt {
  /// What the offering was for, as printed on the receipt.
  String purpose(AppLocalizations l10n) {
    if (puja case final puja?) {
      return '${puja.ceremony.nameEn} — ${Formats.monthDay(puja.date)}';
    }
    final donation = this.donation!;
    final kind = donation.kind.label(l10n);
    return donation.note.isEmpty ? kind : '$kind — ${donation.note}';
  }

  /// Everyone being prayed for, with those who have passed marked as such.
  String prayerNames(AppLocalizations l10n) {
    final puja = this.puja;
    if (puja == null) return '';
    return [
      ...puja.living,
      for (final name in puja.deceased) l10n.receiptPassedSuffix(name),
    ].join(', ');
  }
}
