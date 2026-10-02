import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../feedback/dialogs.dart';
import '../models/phone_country.dart';
import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'app_text_field.dart';
import 'selection.dart';

extension PhoneCountryLabels on PhoneCountry {
  String label(AppLocalizations l10n) => switch (this) {
    PhoneCountry.canada => l10n.countryCanada,
    PhoneCountry.unitedStates => l10n.countryUnitedStates,
    PhoneCountry.india => l10n.countryIndia,
    PhoneCountry.nepal => l10n.countryNepal,
    PhoneCountry.taiwan => l10n.countryTaiwan,
    PhoneCountry.france => l10n.countryFrance,
    PhoneCountry.australia => l10n.countryAustralia,
    PhoneCountry.switzerland => l10n.countrySwitzerland,
    PhoneCountry.unitedKingdom => l10n.countryUnitedKingdom,
  };

  /// `CA +1`: short enough to sit beside the number.
  String get code => '$isoCode +$callingCode';
}

/// A phone number and the country it is from. The country decides the code
/// the number is saved with, so only the number itself is typed.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.country,
    required this.onCountryChanged,
    required this.value,
    required this.onChanged,
    required this.label,
    this.optionalTag,
    this.hint,
    this.errorText,
    this.textInputAction,
    this.fontSize = 18,
  });

  final PhoneCountry country;
  final ValueChanged<PhoneCountry> onCountryChanged;
  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final String? optionalTag;
  final String? hint;
  final String? errorText;
  final TextInputAction? textInputAction;
  final double fontSize;

  Future<void> _pickCountry(BuildContext context) async {
    final chosen = await showAppSheet<PhoneCountry>(
      context: context,
      title: context.l10n.phoneCountryTitle,
      builder: (_) => _CountryChoices(selected: country),
    );
    if (chosen != null) onCountryChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      optionalTag: optionalTag,
      hint: hint,
      value: value,
      onChanged: onChanged,
      errorText: errorText,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      fontSize: fontSize,
      // The keyboard's Next goes from the field before to the number itself,
      // not to the country, which is right far more often than not.
      leading: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        descendantsAreTraversable: false,
        child: _CountryButton(
          country: country,
          fontSize: fontSize,
          onTap: () => _pickCountry(context),
        ),
      ),
    );
  }
}

class _CountryButton extends StatelessWidget {
  const _CountryButton({
    required this.country,
    required this.fontSize,
    required this.onTap,
  });

  final PhoneCountry country;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: l10n.phoneCountrySemantics(country.label(l10n)),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.fieldRadius,
          side: BorderSide(color: colors.line, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 14, end: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Text(
                  country.code,
                  style: context.type.sans(fontSize, height: 1.4),
                ),
                AppIcon(
                  AppIcons.chevronDown,
                  size: 18,
                  color: colors.inkMuted,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountryChoices extends StatelessWidget {
  const _CountryChoices({required this.selected});

  final PhoneCountry selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        for (final country in PhoneCountry.values)
          OptionTile(
            title: country.label(l10n),
            selected: country == selected,
            onTap: () => Navigator.of(context).pop(country),
            minHeight: 56,
            titleWeight: FontWeight.w600,
            trailing: Text(
              '+${country.callingCode}',
              style: context.type.sans(16, color: context.colors.inkMuted),
            ),
          ),
      ],
    );
  }
}
