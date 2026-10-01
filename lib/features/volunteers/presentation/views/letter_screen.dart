import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/selection.dart';
import '../../../outbox/domain/outbox.dart';
import '../../../outbox/presentation/outbox_actions.dart';
import '../../../outbox/presentation/send_preview_sheet.dart';
import '../../domain/letter_composer.dart';
import '../view_models/letter_view_model.dart';
import '../volunteer_labels.dart';

/// Thank-you letters, references and certificates of service. The draft is
/// written for the coordinator, who checks and edits it before it is sent.
class LetterScreen extends ConsumerWidget {
  const LetterScreen({super.key, this.volunteerId});

  /// Volunteer to start with; defaults to the first.
  final String? volunteerId;

  /// Longest excerpt of the letter shown in the send preview.
  static const _previewLength = 260;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = letterViewModelProvider(volunteerId);
    final letter = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);
    void back() => context.popOrGo(AppRoutes.home);

    Future<void> send(LetterState state) async {
      if (state.text.trim().isEmpty) {
        ref.toast(l10n.toastLetterEmpty);
        return;
      }
      final text = state.text.trim();
      final sent = await showSendPreview(
        context,
        OutgoingMessage(
          channel: DeliveryChannel.email,
          recipient: '${state.volunteer.name} · ${state.volunteer.email}',
          body: text.length > _previewLength
              ? '${text.substring(0, _previewLength)}…'
              : text,
          attachment: l10n.msgLetterAttachment(state.type.label(l10n)),
        ),
      );
      if (!sent || !context.mounted) return;
      context.go(AppRoutes.home);
      ref.toast(l10n.toastLetterSent(state.volunteer.name));
    }

    return AsyncValueView(
      value: letter,
      onRetry: () => ref.invalidate(provider),
      data: (state) => AppPage(
        backLabel: l10n.navHome,
        onBack: back,
        maxWidth: Breakpoints.wideContentMaxWidth,
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PrimaryButton(
              label: l10n.letterApproveSend,
              onPressed: () => send(state),
            ),
            LinkButton(
              label: l10n.letterPrint,
              minHeight: 48,
              expand: true,
              onPressed: () async {
                final printed = await ref
                    .read(outboxActionsProvider)
                    .printDocument(state.type.label(l10n));
                if (printed) ref.toast(l10n.toastPrinted);
              },
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeading(title: l10n.letterTitle, subtitle: l10n.letterIntro),
            const SizedBox(height: 14),
            AdaptiveColumns(
              primary: _Choices(state: state, viewModel: viewModel),
              secondary: _Draft(state: state, viewModel: viewModel),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({required this.state, required this.viewModel});

  final LetterState state;
  final LetterViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StepHeading(l10n.letterStepVolunteer),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final volunteer in state.volunteers)
              ChoicePill(
                label: volunteer.name,
                selected: volunteer.id == state.volunteer.id,
                onTap: () => viewModel.selectVolunteer(volunteer),
              ),
          ],
        ),
        const SizedBox(height: 18),
        StepHeading(l10n.letterStepType),
        const SizedBox(height: 14),
        for (final type in LetterType.values) ...[
          OptionTile(
            title: type.label(l10n),
            subtitle: type.description(l10n),
            selected: type == state.type,
            onTap: () => viewModel.selectType(type),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _Draft extends ConsumerWidget {
  const _Draft({required this.state, required this.viewModel});

  final LetterState state;
  final LetterViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A Wrap, so with large text the button drops below the heading
        // instead of squeezing it.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            StepHeading(l10n.letterStepDraft),
            SecondaryButton(
              label: state.improving
                  ? l10n.improveWordingBusy
                  : l10n.improveWording,
              icon: AppIcons.sparkle,
              expand: false,
              pill: true,
              minHeight: 48,
              fontSize: 15,
              busy: state.improving,
              onPressed: () async {
                if (await viewModel.improve()) {
                  ref.toast(l10n.toastWordingImproved);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppTextField(
          value: state.text,
          onChanged: viewModel.setText,
          minLines: 13,
          maxLines: null,
          fontSize: 16,
          documentStyle: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 14),
        Text(
          l10n.letterCheck,
          style: context.type.sans(
            15,
            color: context.colors.inkMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
