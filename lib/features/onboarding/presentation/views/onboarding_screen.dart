import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../settings/presentation/view_models/preferences_view_model.dart';
import '../../../settings/presentation/widgets/language_toggle.dart';
import '../view_models/onboarding_view_model.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final locale = ref.watch(localeProvider);
    final slide = ref.watch(onboardingViewModelProvider);
    final viewModel = ref.read(onboardingViewModelProvider.notifier);

    final (icon, title, body) = switch (slide) {
      OnboardingSlide.members => (
        AppIcons.idCard,
        l10n.onboardingMembersTitle,
        l10n.onboardingMembersBody,
      ),
      OnboardingSlide.offerings => (
        AppIcons.receipt,
        l10n.onboardingOfferingsTitle,
        l10n.onboardingOfferingsBody,
      ),
      OnboardingSlide.volunteers => (
        AppIcons.calendarDays,
        l10n.onboardingVolunteersTitle,
        l10n.onboardingVolunteersBody,
      ),
    };

    void toLogin() => context.go(AppRoutes.login);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            const PrayerFlagStripe(white: AppPalette.parchment),
            Expanded(
              child: ContentFrame(
                maxWidth: 560,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const LanguageToggle(),
                          LinkButton(
                            label: l10n.onboardingSkip,
                            minHeight: 48,
                            onPressed: () {
                              viewModel.finish();
                              toLogin();
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Column(
                              key: ValueKey(slide),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _SlideArt(icon: icon),
                                const SizedBox(height: 44),
                                Text(
                                  l10n.onboardingCount(
                                    Formats.digits(slide.index + 1, locale),
                                    Formats.digits(
                                      OnboardingSlide.values.length,
                                      locale,
                                    ),
                                  ),
                                  style: type.sans(
                                    14,
                                    weight: FontWeight.w700,
                                    color: AppPalette.saffronText,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: type.serif(28),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  body,
                                  textAlign: TextAlign.center,
                                  style: type.sans(
                                    18,
                                    color: colors.inkMuted,
                                    height: type.lineHeight + 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final item in OnboardingSlide.values) ...[
                                if (item.index > 0) const SizedBox(width: 8),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  width: item == slide ? 28 : 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: item == slide
                                        ? colors.accent
                                        : colors.line,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 22),
                          PrimaryButton(
                            label: slide == OnboardingSlide.values.last
                                ? l10n.onboardingStart
                                : l10n.onboardingNext,
                            onPressed: () {
                              if (viewModel.next()) toLogin();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The slide's line icon inside a double gold ring.
class _SlideArt extends StatelessWidget {
  const _SlideArt({required this.icon});

  final AppIconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppPalette.gold.withValues(alpha: 0.5)),
      ),
      child: Container(
        width: 216,
        height: 216,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.card,
          border: Border.all(color: AppPalette.gold, width: 1.5),
        ),
        child: AppIcon(
          icon,
          size: 92,
          color: colors.accentText,
          strokeWidth: 1.2,
        ),
      ),
    );
  }
}
