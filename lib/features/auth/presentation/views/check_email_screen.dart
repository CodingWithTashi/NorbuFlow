import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/buttons.dart';
import '../view_models/auth_view_model.dart';

/// Shown after a sign-in link has been requested. The person finishes
/// signing in from their email; the router moves them on once they have.
class CheckEmailScreen extends ConsumerWidget {
  const CheckEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final email = ref.watch(
      authViewModelProvider.select((auth) => auth.pendingEmail),
    );
    final auth = ref.read(authViewModelProvider.notifier);
    final demoMode = ref.watch(appConfigProvider).demoMode;

    void toLogin() => context.go(AppRoutes.login);

    Future<void> resend() async {
      if (email == null) return toLogin();
      final result = await auth.sendSignInLink(email);
      if (result.isOk) ref.toast(l10n.toastLinkResent);
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ContentFrame(
          maxWidth: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: BackLink(label: l10n.commonBack, onPressed: toLogin),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.card,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppPalette.gold,
                            width: 1.5,
                          ),
                        ),
                        child: AppIcon(
                          AppIcons.mail,
                          size: 46,
                          color: colors.accentText,
                          strokeWidth: 1.6,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.checkEmailTitle,
                        textAlign: TextAlign.center,
                        style: type.serif(28),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.checkEmailSentTo,
                        textAlign: TextAlign.center,
                        style: type.sans(17, color: colors.inkMuted),
                      ),
                      Text(
                        email ?? '',
                        textAlign: TextAlign.center,
                        style: type.sans(17, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        l10n.checkEmailHelp,
                        textAlign: TextAlign.center,
                        style: type.sans(16, color: colors.inkMuted),
                      ),
                      if (demoMode) ...[
                        const SizedBox(height: 18),
                        DemoButton(
                          label: l10n.checkEmailDemo,
                          onPressed: auth.completeSignIn,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PrimaryButton(
                      label: l10n.checkEmailOpenMail,
                      onPressed: () => ref.toast(l10n.toastOpeningMail),
                    ),
                    const SizedBox(height: 4),
                    EqualRow(
                      gap: 8,
                      children: [
                        LinkButton(
                          label: l10n.checkEmailResend,
                          fontSize: 16,
                          onPressed: resend,
                        ),
                        LinkButton(
                          label: l10n.checkEmailOther,
                          fontSize: 16,
                          onPressed: toLogin,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
