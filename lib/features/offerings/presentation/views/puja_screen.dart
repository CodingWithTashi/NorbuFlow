import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/calendar/tibetan_calendar.dart';
import '../../../../core/error/failure_text.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../core/widgets/success_view.dart';
import '../../../../core/widgets/tiles.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../offering_labels.dart';
import '../receipt_sharing.dart';
import '../view_models/puja_view_model.dart';

/// Puja / Tsok request: ceremony and date → names for prayers → sponsor and
/// offering → review. Saving issues a receipt and adds the names to the
/// Geshe's prayer list.
class PujaScreen extends ConsumerWidget {
  const PujaScreen({super.key, required this.tsok});

  /// Opened from the Tsok tile: starts on the feast offering.
  final bool tsok;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = pujaViewModelProvider(tsok);
    return AsyncValueView(
      value: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      data: (state) => _PujaFlow(tsok: tsok, state: state),
    );
  }
}

class _PujaFlow extends ConsumerWidget {
  const _PujaFlow({required this.tsok, required this.state});

  final bool tsok;
  final PujaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final viewModel = ref.read(pujaViewModelProvider(tsok).notifier);
    final temple = ref.watch(currentTempleProvider);

    final receipt = state.receipt;
    if (receipt != null && temple != null) {
      return SuccessView(
        title: l10n.offeringRecordedTitle,
        message: l10n.offeringRecordedPuja(
          state.ceremony.nameEn,
          Formats.dayTitle(state.date),
          receipt.number,
        ),
        primaryLabel: l10n.offeringViewReceipt,
        onPrimary: () => context.go(AppRoutes.receipt(receipt.number)),
        onDone: () => context.go(AppRoutes.offerings),
        shareActions: receiptShareActions(
          context,
          ref,
          receipt: receipt,
          temple: temple,
        ),
      );
    }

    return WizardScaffold(
      flowName: l10n.pujaFlowName,
      step: state.step.index + 1,
      stepCount: PujaStep.values.length,
      title: switch (state.step) {
        PujaStep.ceremony => l10n.pujaStepCeremony,
        PujaStep.names => l10n.pujaStepNames,
        PujaStep.sponsor => l10n.pujaStepSponsor,
        PujaStep.review => l10n.pujaStepReview,
      },
      onBack: () {
        if (!viewModel.back()) context.popOrGo(AppRoutes.offerings);
      },
      nextLabel: state.step == PujaStep.review
          ? l10n.pujaSubmit(Formats.money(state.amount))
          : l10n.commonNext,
      onNext: viewModel.next,
      busy: state.submitting,
      child: switch (state.step) {
        PujaStep.ceremony => _CeremonyStep(state: state, viewModel: viewModel),
        PujaStep.names => _NamesStep(state: state, viewModel: viewModel),
        PujaStep.sponsor => _SponsorStep(state: state, viewModel: viewModel),
        PujaStep.review => _ReviewStep(state: state),
      },
    );
  }
}

class _CeremonyStep extends ConsumerWidget {
  const _CeremonyStep({required this.state, required this.viewModel});

  final PujaState state;
  final PujaViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final calendar = ref.watch(tibetanCalendarProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.pujaCeremony, style: type.sans(17, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        for (final ceremony in state.ceremonies) ...[
          OptionTile(
            indicator: OptionIndicator.trailingCheck,
            title: ceremony.nameEn,
            titleWeight: FontWeight.w600,
            subtitleWidget: Text(
              ceremony.nameBo,
              style: type.tibetan(15, color: colors.inkMuted),
            ),
            selected: ceremony.id == state.ceremony.id,
            onTap: () => viewModel.setCeremony(ceremony),
            minHeight: 64,
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        Text(l10n.pujaDate, style: type.sans(17, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        for (final date in state.dates) ...[
          OptionTile(
            indicator: OptionIndicator.trailingCheck,
            title: Formats.dayTitle(date),
            titleWeight: FontWeight.w600,
            subtitleWidget: _PracticeDayLine(
              practice: calendar.practiceOn(date),
              day: calendar.dayOf(date),
            ),
            selected: date == state.date,
            onTap: () => viewModel.setDate(date),
            minHeight: 64,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// The practice day's mark and name, then the Tibetan date:
/// "Medicine Buddha Day · Tibetan month 9, day 8".
class _PracticeDayLine extends StatelessWidget {
  const _PracticeDayLine({required this.practice, required this.day});

  final PracticeDay? practice;
  final TibetanDay day;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tibetan = l10n.tibetanDate(day.month, day.day);
    final style = context.type.sans(
      14,
      color: context.colors.inkMuted,
      height: 1.4,
    );
    final practice = this.practice;
    if (practice == null) return Text(tibetan, style: style);
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 5),
              child: AppIcon(practice.icon, size: 12, color: AppPalette.gold),
            ),
          ),
          TextSpan(text: '${practice.label(l10n)} · $tibetan'),
        ],
      ),
      style: style,
    );
  }
}

class _NamesStep extends ConsumerWidget {
  const _NamesStep({required this.state, required this.viewModel});

  final PujaState state;
  final PujaViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;

    Widget group(PrayerGroup group, String title, String subtitle) {
      final names = state.names(group);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: type.sans(18, weight: FontWeight.w600)),
          Text(subtitle, style: type.sans(15, color: colors.inkMuted)),
          const SizedBox(height: 10),
          if (names.isNotEmpty) ...[
            GroupedCard(
              background: colors.card,
              children: [
                for (final (index, name) in names.indexed)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        4,
                        6,
                        4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: type.sans(18, height: 1.8),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              final before = viewModel.removeName(group, index);
                              ref.toast(
                                l10n.toastNameRemoved(name),
                                onUndo: () =>
                                    viewModel.restoreNames(group, before),
                              );
                            },
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              foregroundColor: colors.inkMuted,
                              textStyle: type
                                  .sans(
                                    15,
                                    weight: FontWeight.w500,
                                    height: 1.2,
                                  )
                                  .copyWith(
                                    decoration: TextDecoration.underline,
                                  ),
                            ),
                            child: Text(l10n.commonRemove),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  hint: l10n.pujaNameHint,
                  value: state.input(group),
                  onChanged: (value) => viewModel.setNameInput(group, value),
                  onSubmitted: (_) => viewModel.addName(group),
                  textInputAction: TextInputAction.done,
                  fontSize: 17,
                ),
              ),
              const SizedBox(width: 8),
              SecondaryButton(
                label: l10n.commonAdd,
                expand: false,
                minHeight: 58,
                onPressed: () => viewModel.addName(group),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        group(PrayerGroup.living, l10n.pujaLivingTitle, l10n.pujaLivingSub),
        const SizedBox(height: 22),
        group(PrayerGroup.deceased, l10n.pujaPassedTitle, l10n.pujaPassedSub),
      ],
    );
  }
}

class _SponsorStep extends StatelessWidget {
  const _SponsorStep({required this.state, required this.viewModel});

  final PujaState state;
  final PujaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: l10n.pujaSponsorName,
          value: state.sponsor,
          onChanged: viewModel.setSponsor,
          errorText: state.sponsorIssue == null
              ? null
              : validationText(l10n, state.sponsorIssue!),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          fontSize: 19,
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: l10n.pujaReceiptContact,
          value: state.contact,
          onChanged: viewModel.setContact,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          fontSize: 19,
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: l10n.pujaDedication,
          optionalTag: l10n.commonOptional,
          value: state.dedication,
          onChanged: viewModel.setDedication,
          minLines: 3,
          maxLines: 5,
          fontSize: 17,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 18),
        Text(
          l10n.pujaOfferingAmount,
          style: context.type.sans(17, weight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        AmountPicker(
          amounts: PujaState.amounts,
          selected: state.amount,
          onChanged: viewModel.setAmount,
          format: Formats.money,
        ),
      ],
    );
  }
}

class _ReviewStep extends ConsumerWidget {
  const _ReviewStep({required this.state});

  final PujaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final day = ref.watch(tibetanCalendarProvider).dayOf(state.date);

    String listed(List<String> names) =>
        names.isEmpty ? l10n.commonNone : names.join(', ');
    final rows = [
      (
        l10n.pujaCeremony,
        '${state.ceremony.nameEn} · ${state.ceremony.nameBo}',
      ),
      (
        l10n.pujaDate,
        '${Formats.dayTitle(state.date)} · '
            '${l10n.tibetanDate(day.month, day.day)}',
      ),
      (l10n.pujaReviewLiving, listed(state.living)),
      (l10n.pujaReviewPassed, listed(state.deceased)),
      (
        l10n.pujaReviewSponsor,
        [
          state.sponsor.trim(),
          state.contact.trim(),
        ].where((part) => part.isNotEmpty).join(' · '),
      ),
      (
        l10n.pujaDedication,
        state.dedication.trim().isEmpty
            ? l10n.commonEmDash
            : state.dedication.trim(),
      ),
      (l10n.pujaReviewOffering, Formats.moneyExact(state.amount)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.pujaReviewIntro,
          style: context.type.sans(17, color: colors.inkMuted, height: 1.5),
        ),
        const SizedBox(height: 12),
        GroupedCard(
          background: colors.card,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: LabeledValue(label: label, value: value),
              ),
          ],
        ),
      ],
    );
  }
}
