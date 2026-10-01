import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/selection.dart';
import '../../../outbox/domain/outbox.dart';
import '../../../outbox/presentation/send_preview_sheet.dart';
import '../../../temple/domain/temple.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../view_models/announcement_view_model.dart';

/// Make an announcement: pick a template, fill in the blanks, preview it as
/// a poster, email and WhatsApp message, then choose who receives it.
class AnnouncementScreen extends ConsumerWidget {
  const AnnouncementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final announcement = ref.watch(announcementViewModelProvider);
    final viewModel = ref.read(announcementViewModelProvider.notifier);
    final temple = ref.watch(currentTempleProvider);

    Future<void> send(AnnouncementState state) async {
      if (state.groupIds.isEmpty) return ref.toast(l10n.toastChooseGroup);
      if (state.title.trim().isEmpty) return ref.toast(l10n.toastAddTitle);

      final audience = state.audienceSize;
      final sent = await showSendPreview(
        context,
        OutgoingMessage(
          channel: DeliveryChannel.email,
          recipient: l10n.msgAnnouncementTo(
            state.selectedGroups.map((group) => group.name).join(', '),
            audience,
          ),
          body:
              '${state.title}\n${state.when}\n\n${state.details}\n\n'
              '— ${temple?.nameEn ?? ''}',
          attachment: l10n.msgAnnouncementAttachment,
        ),
        send: () async => (await viewModel.send()).isOk,
      );
      if (!sent || !context.mounted) return;
      context.go(AppRoutes.home);
      ref.toast(l10n.toastAnnouncementSent(audience));
    }

    return AsyncValueView(
      value: announcement,
      onRetry: () => ref.invalidate(announcementViewModelProvider),
      data: (state) => AppPage(
        backLabel: l10n.navHome,
        onBack: () => context.popOrGo(AppRoutes.home),
        maxWidth: Breakpoints.wideContentMaxWidth,
        bottom: PrimaryButton(
          label: state.audienceSize == 0
              ? l10n.announceSendCtaEmpty
              : l10n.announceSendCta(state.audienceSize),
          onPressed: () => send(state),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeading(title: l10n.announceTitle),
            const SizedBox(height: 14),
            AdaptiveColumns(
              primary: _Composer(state: state, viewModel: viewModel),
              secondary: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StepHeading(l10n.announceStepPreview),
                  const SizedBox(height: 14),
                  SegmentedPill<AnnouncementPreview>(
                    expand: true,
                    fontSize: 15,
                    segments: {
                      AnnouncementPreview.poster: l10n.announceViewPoster,
                      AnnouncementPreview.email: l10n.commonEmail,
                      AnnouncementPreview.whatsApp: l10n.commonWhatsApp,
                    },
                    selected: state.preview,
                    onChanged: viewModel.setPreview,
                  ),
                  const SizedBox(height: 14),
                  if (temple != null)
                    switch (state.preview) {
                      AnnouncementPreview.poster => _PosterPreview(
                        state: state,
                        temple: temple,
                      ),
                      AnnouncementPreview.email => _EmailPreview(
                        state: state,
                        temple: temple,
                      ),
                      AnnouncementPreview.whatsApp => _WhatsAppPreview(
                        state: state,
                        temple: temple,
                      ),
                    },
                  const SizedBox(height: 18),
                  StepHeading(l10n.announceStepSendTo),
                  const SizedBox(height: 14),
                  for (final group in state.groups) ...[
                    OptionTile(
                      indicator: OptionIndicator.checkbox,
                      title: group.name,
                      selected: state.groupIds.contains(group.id),
                      onTap: () => viewModel.toggleGroup(group.id),
                      minHeight: 60,
                      trailing: Text(
                        l10n.commonPeople(group.size),
                        style: context.type.sans(
                          15,
                          color: context.colors.inkMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends ConsumerWidget {
  const _Composer({required this.state, required this.viewModel});

  final AnnouncementState state;
  final AnnouncementViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepHeading(l10n.announceStepTemplate),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final template in state.templates)
              ChoicePill(
                label: template.name,
                selected: template.id == state.template.id,
                onTap: () => viewModel.selectTemplate(template),
              ),
          ],
        ),
        const SizedBox(height: 18),
        StepHeading(l10n.announceStepFill),
        const SizedBox(height: 14),
        AppTextField(
          label: l10n.announceFieldTitle,
          labelMuted: true,
          value: state.title,
          onChanged: viewModel.setTitle,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: l10n.announceFieldWhen,
          labelMuted: true,
          value: state.when,
          onChanged: viewModel.setWhen,
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: l10n.announceFieldDetails,
          labelMuted: true,
          value: state.details,
          onChanged: viewModel.setDetails,
          minLines: 4,
          maxLines: 8,
          fontSize: 17,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 14),
        SecondaryButton(
          label: state.improving
              ? l10n.improveWordingBusy
              : l10n.improveWording,
          icon: AppIcons.sparkle,
          minHeight: 52,
          fontSize: 16,
          busy: state.improving,
          onPressed: () async {
            if (await viewModel.improve()) ref.toast(l10n.toastWordingImproved);
          },
        ),
      ],
    );
  }
}

class _PosterPreview extends StatelessWidget {
  const _PosterPreview({required this.state, required this.temple});

  final AnnouncementState state;
  final Temple temple;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.colors.accent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        clipBehavior: Clip.antiAlias,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppPalette.gold),
        ),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PrayerFlagStripe(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                children: [
                  Text(
                    state.template.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: type.sans(
                      13,
                      weight: FontWeight.w700,
                      color: AppPalette.goldSoft,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.title,
                    textAlign: TextAlign.center,
                    style: type.serif(26, color: Colors.white, height: 1.25),
                  ),
                  const SizedBox(height: 12),
                  Container(width: 60, height: 1, color: AppPalette.gold),
                  const SizedBox(height: 12),
                  Text(
                    state.when,
                    textAlign: TextAlign.center,
                    style: type.sans(
                      17,
                      weight: FontWeight.w700,
                      color: AppPalette.goldSoft,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.details,
                    textAlign: TextAlign.center,
                    style: type.sans(
                      16,
                      color: AppPalette.parchment,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '${temple.nameEn} · ${temple.url}',
                    textAlign: TextAlign.center,
                    style: type.sans(14, color: AppPalette.parchment),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailPreview extends StatelessWidget {
  const _EmailPreview({required this.state, required this.temple});

  final AnnouncementState state;
  final Temple temple;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final l10n = context.l10n;
    const ink = AppPalette.paperInk;
    const bold = TextStyle(fontWeight: FontWeight.w700);

    return Container(
      decoration: BoxDecoration(
        color: AppPalette.paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${l10n.announceEmailFrom} ', style: bold),
                  TextSpan(text: '${temple.nameEn}\n'),
                  TextSpan(text: '${l10n.announceEmailSubject} ', style: bold),
                  TextSpan(text: '${state.title} — ${state.when}'),
                ],
              ),
              style: type.sans(15, color: ink, height: 1.5),
            ),
          ),
          const Divider(height: 1, color: AppPalette.paperLine),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
              '${l10n.announceEmailGreeting}\n\n'
              '${state.details}\n\n'
              '${l10n.announceEmailSignoff}\n'
              '${temple.nameEn}',
              style: type.sans(16, color: ink, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppPreview extends StatelessWidget {
  const _WhatsAppPreview({required this.state, required this.temple});

  final AnnouncementState state;
  final Temple temple;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    const ink = AppPalette.whatsAppInk;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.whatsAppWallpaper,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: 0.88,
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: AppPalette.whatsAppBubble,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
              bottomLeft: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.title,
                style: type.sans(
                  16,
                  weight: FontWeight.w700,
                  color: ink,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(state.when, style: type.sans(16, color: ink, height: 1.5)),
              const SizedBox(height: 6),
              Text(
                state.details,
                style: type.sans(16, color: ink, height: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                '— ${temple.nameEn}',
                style: type.sans(
                  16,
                  color: AppPalette.whatsAppInkMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
