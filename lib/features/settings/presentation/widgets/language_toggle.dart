import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/selection.dart';
import '../../domain/app_preferences.dart';
import '../view_models/preferences_view_model.dart';

/// English / Tibetan switch. Available before sign-in too, so nobody has to
/// get through a screen they cannot read to reach it.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key, this.compactLabels = true});

  /// "EN" rather than "English".
  final bool compactLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return SegmentedPill<AppLanguage>(
      segments: {
        AppLanguage.english: compactLabels
            ? l10n.languageEnglishShort
            : l10n.languageEnglish,
        AppLanguage.tibetan: l10n.languageTibetan,
      },
      selected: ref.watch(preferencesProvider.select((p) => p.language)),
      onChanged: ref.read(preferencesProvider.notifier).setLanguage,
    );
  }
}
