import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/calendar/tibetan_calendar.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../core/widgets/success_view.dart';
import '../../../outbox/domain/outbox.dart';
import '../../../outbox/presentation/send_preview_sheet.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../view_models/assign_view_model.dart';
import '../volunteer_labels.dart';

/// Fill a day's open shifts: pick the shift, tick the volunteers, confirm.
class AssignScreen extends ConsumerWidget {
  const AssignScreen({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assignViewModelProvider(day));
    final done = state.done;
    if (done != null) return _AssignedView(assignment: done);

    return AsyncValueView(
      value: ref.watch(assignBoardProvider(day)),
      data: (board) => _AssignForm(day: day, state: state, board: board),
    );
  }
}

class _AssignForm extends ConsumerWidget {
  const _AssignForm({
    required this.day,
    required this.state,
    required this.board,
  });

  final DateTime day;
  final AssignState state;
  final AssignBoard board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final viewModel = ref.read(assignViewModelProvider(day).notifier);
    final tibetan = ref.watch(tibetanCalendarProvider).dayOf(day);
    final current = board.current;
    final count = state.picked.length;

    void toggle(VolunteerChoice choice) {
      if (current == null) return;
      final name = choice.volunteer.name;
      switch (viewModel.toggle(choice, current)) {
        case PickOutcome.changed:
          break;
        case PickOutcome.away:
          ref.toast(l10n.toastVolunteerAway(name));
        case PickOutcome.alreadyOnShift:
          ref.toast(l10n.toastVolunteerBusy(name));
        case PickOutcome.shiftFull:
          ref.toast(l10n.toastShiftLimit(current.open));
      }
    }

    return AppPage(
      backLabel: l10n.navCalendar,
      onBack: () => context.popOrGo(AppRoutes.calendar),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      bottom: PrimaryButton(
        label: count == 0 ? l10n.assignCtaEmpty : l10n.assignCta(count),
        subdued: count == 0,
        busy: state.submitting,
        onPressed: () => viewModel.confirm(board),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.assignTitle, style: type.serif(24)),
          ),
          Text(
            '${Formats.dayTitle(day)} · '
            '${l10n.tibetanDate(tibetan.month, tibetan.day)}',
            style: type.sans(15, color: colors.inkMuted),
          ),
          const SizedBox(height: 12),
          if (board.openShifts.isEmpty)
            MessageView(message: l10n.toastAllShiftsFull)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final shift in board.openShifts)
                  SelectableCard(
                    selected: shift.id == current?.id,
                    onTap: () => viewModel.selectShift(shift.id),
                    minHeight: 56,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: shift.duty.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              shift.duty.label(l10n),
                              style: type.sans(
                                15,
                                weight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                            Text(
                              l10n.assignNeedsMore(shift.open),
                              style: type.sans(
                                13,
                                color: colors.inkMuted,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          SearchField(
            value: state.query,
            hint: l10n.commonSearchHint,
            onChanged: viewModel.setQuery,
          ),
          const SizedBox(height: 12),
          for (final choice in board.choices) ...[
            OptionTile(
              indicator: OptionIndicator.checkbox,
              title: choice.volunteer.name,
              titleWeight: FontWeight.w600,
              subtitle: choice.alreadyOnShift
                  ? l10n.assignAlreadyOnShift
                  : choice.volunteer.note,
              selected: choice.picked,
              dimmed: !choice.selectable,
              minHeight: 72,
              onTap: () => toggle(choice),
              trailing: StatusPill(
                label: choice.availability.label(l10n),
                icon: choice.availability.icon,
                tone: choice.availability.tone,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AssignedView extends ConsumerWidget {
  const _AssignedView({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final shift = assignment.shift.duty.label(l10n);
    final day = Formats.dayTitle(assignment.shift.date);
    final names = assignment.names;
    // "A, B and C"
    final listed = names.length < 2
        ? names.join()
        : l10n.listAnd(
            names.sublist(0, names.length - 1).join(', '),
            names.last,
          );

    return SuccessView(
      title: l10n.assignSuccessTitle,
      message: l10n.assignSuccessBody(listed, shift, day),
      primaryLabel: l10n.assignMessageThem,
      onPrimary: () async {
        final temple = ref.read(currentTempleProvider);
        final sent = await showSendPreview(
          context,
          OutgoingMessage(
            channel: DeliveryChannel.whatsApp,
            recipient: names.join(', '),
            body: l10n.msgShiftBody(shift, day, temple?.nameEn ?? ''),
            attachment: l10n.msgShiftAttachment,
          ),
        );
        if (sent) ref.toast(l10n.toastSentWhatsApp);
      },
      onDone: () => context.go(AppRoutes.calendar),
    );
  }
}
