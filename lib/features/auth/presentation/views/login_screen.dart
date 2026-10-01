import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/failure_text.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../settings/presentation/widgets/language_toggle.dart';
import '../view_models/login_view_model.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final state = ref.watch(loginViewModelProvider);
    final viewModel = ref.read(loginViewModelProvider.notifier);

    Future<void> submit() async {
      if (await viewModel.submit() && context.mounted) {
        context.go(AppRoutes.checkEmail);
      }
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ContentFrame(
          maxWidth: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: LanguageToggle(),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppPalette.gold,
                              width: 2,
                            ),
                          ),
                          child: const JewelLogo(
                            size: 52,
                            color: AppPalette.gold,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.loginWelcome,
                        textAlign: TextAlign.center,
                        style: type.serif(30),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.loginSubtitle,
                        textAlign: TextAlign.center,
                        style: type.sans(17, color: colors.inkMuted),
                      ),
                      const SizedBox(height: 28),
                      AppTextField(
                        label: l10n.loginEmailLabel,
                        hint: l10n.commonEmailHint,
                        value: state.email,
                        onChanged: viewModel.setEmail,
                        onSubmitted: (_) => submit(),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.go,
                        autofillHints: const [AutofillHints.email],
                        fontSize: 19,
                        errorText: state.issue == null
                            ? null
                            : validationText(l10n, state.issue!),
                      ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colors.card,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: AppIcon(
                                AppIcons.lock,
                                color: colors.accentText,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.loginInviteOnlyTitle,
                                    style: type.sans(
                                      16,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.loginInviteOnlyBody,
                                    style: type.sans(
                                      15,
                                      color: colors.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: PrimaryButton(
                  label: l10n.loginSendLink,
                  onPressed: submit,
                  busy: state.submitting,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
