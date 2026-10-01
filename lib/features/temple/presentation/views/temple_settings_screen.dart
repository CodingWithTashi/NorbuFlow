import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/failure_text.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/accent_preset.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/avatars.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/selection.dart';
import '../temple_labels.dart';
import '../view_models/temple_settings_view_model.dart';

/// The details printed on this temple's ID cards and receipts, plus its
/// logo and accent colour. Admin only.
class TempleSettingsScreen extends ConsumerWidget {
  const TempleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final state = ref.watch(templeSettingsViewModelProvider);
    final viewModel = ref.read(templeSettingsViewModelProvider.notifier);
    final draft = state.draft;

    Future<void> save() async {
      if (!await viewModel.save() || !context.mounted) return;
      ref.toast(l10n.toastTempleSaved);
      context.popOrGo(AppRoutes.more);
    }

    return AppPage(
      backLabel: l10n.navMore,
      onBack: () => context.popOrGo(AppRoutes.more),
      bottom: PrimaryButton(
        label: l10n.templeSaveChanges,
        onPressed: save,
        busy: state.saving,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeading(title: l10n.templeSettingsTitle, subtitle: draft.url),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                TempleBadge(
                  monogram: draft.monogram,
                  logo: draft.logo,
                  size: 72,
                  background: draft.accent.color,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.templeSettingsLogo, style: type.sectionTitle),
                      const SizedBox(height: 6),
                      SecondaryButton(
                        label: l10n.templeSettingsUploadLogo,
                        expand: false,
                        pill: true,
                        minHeight: 48,
                        fontSize: 15,
                        onPressed: () async {
                          if (await viewModel.pickLogo()) {
                            ref.toast(l10n.toastLogoUpdated);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: l10n.templeFieldNameEn,
            value: draft.nameEn,
            onChanged: viewModel.setNameEn,
            fontSize: 17,
            errorText: state.nameIssue == null
                ? null
                : validationText(l10n, state.nameIssue!),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: l10n.templeFieldNameBo,
            value: draft.nameBo,
            onChanged: viewModel.setNameBo,
            fontSize: 17,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: l10n.templeFieldTradition,
            value: draft.tradition,
            onChanged: viewModel.setTradition,
            fontSize: 17,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: l10n.templeFieldAddress,
            value: draft.address,
            onChanged: viewModel.setAddress,
            fontSize: 17,
            keyboardType: TextInputType.streetAddress,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: l10n.templeFieldCharity,
            value: draft.charityRegistration,
            onChanged: viewModel.setCharityRegistration,
            fontSize: 17,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: l10n.templeFieldSignatory,
            value: draft.signatory,
            onChanged: viewModel.setSignatory,
            fontSize: 17,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          Text(l10n.templeAccentColour, style: type.sectionTitle),
          const SizedBox(height: 16),
          ResponsiveGrid(
            minItemWidth: 100,
            minColumns: 3,
            maxColumns: 6,
            spacing: 10,
            children: [
              for (final accent in AccentPreset.values)
                _AccentSwatch(
                  accent: accent,
                  selected: accent == draft.accent,
                  onTap: () => viewModel.setAccent(accent),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AccentPreset accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return SelectableCard(
      selected: selected,
      onTap: onTap,
      minHeight: 92,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.color,
              shape: BoxShape.circle,
              border: Border.all(color: AppPalette.gold, width: 2),
            ),
            child: selected
                ? const AppIcon(
                    AppIcons.check,
                    size: 20,
                    color: Colors.white,
                    strokeWidth: 3,
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            accent.label(context.l10n),
            textAlign: TextAlign.center,
            style: type.sans(14, weight: FontWeight.w600, height: 1.3),
          ),
        ],
      ),
    );
  }
}
