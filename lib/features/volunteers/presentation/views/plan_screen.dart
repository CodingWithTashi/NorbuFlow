import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/calendar/tibetan_calendar.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/avatars.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../offerings/presentation/offering_labels.dart';
import '../../../outbox/domain/outbox.dart';
import '../../../outbox/presentation/outbox_actions.dart';
import '../../../outbox/presentation/send_preview_sheet.dart';
import '../../../temple/domain/temple.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../domain/volunteer.dart';
import '../view_models/calendar_view_model.dart';
import '../view_models/plan_view_model.dart';
import '../volunteer_labels.dart';

/// The volunteer rota as a printable page, by week or by month.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final state = ref.watch(planViewModelProvider);
    final viewModel = ref.read(planViewModelProvider.notifier);
    final shifts = ref.watch(monthShiftsProvider(state.month));
    final volunteerCount = ref.watch(volunteersProvider).value?.length ?? 0;
    final temple = ref.watch(currentTempleProvider);
    final calendar = ref.watch(tibetanCalendarProvider);
    final today = ref.watch(todayProvider);

    final range = switch (state.mode) {
      PlanMode.month => Formats.monthYear(state.month),
      PlanMode.week => l10n.planWeekOf(
        '${Formats.dayRange(state.week.first, state.week.last)}, '
        '${state.month.year}',
      ),
    };

    Future<void> share(DeliveryChannel channel) async {
      final whatsApp = channel == DeliveryChannel.whatsApp;
      final sent = await showSendPreview(
        context,
        OutgoingMessage(
          channel: channel,
          recipient: l10n.msgPlanTo(volunteerCount),
          body: l10n.msgPlanBody(range, temple?.nameEn ?? ''),
          attachment: l10n.msgPlanAttachment(range),
        ),
      );
      if (sent) {
        ref.toast(whatsApp ? l10n.toastSentWhatsApp : l10n.toastSentEmail);
      }
    }

    return AppPage(
      backLabel: l10n.navCalendar,
      onBack: () => context.popOrGo(AppRoutes.calendar),
      maxWidth: Breakpoints.wideContentMaxWidth,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: l10n.planDownload,
            icon: AppIcons.download,
            onPressed: () async {
              final saved = await ref
                  .read(outboxActionsProvider)
                  .export(range, ExportFormat.pdf);
              if (saved) ref.toast(l10n.toastPlanSaved);
            },
          ),
          const SizedBox(height: 8),
          EqualRow(
            children: [
              SecondaryButton(
                label: l10n.planEmailTeam,
                minHeight: 52,
                fontSize: 16,
                onPressed: () => share(DeliveryChannel.email),
              ),
              SecondaryButton(
                label: l10n.commonWhatsApp,
                minHeight: 52,
                fontSize: 16,
                onPressed: () => share(DeliveryChannel.whatsApp),
              ),
            ],
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              header: true,
              child: Text(l10n.planTitle, style: context.type.serif(24)),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedPill<PlanMode>(
            expand: true,
            minHeight: 52,
            segments: {
              PlanMode.week: l10n.planWeekly,
              PlanMode.month: l10n.planMonthly,
            },
            selected: state.mode,
            onChanged: viewModel.setMode,
          ),
          if (state.mode == PlanMode.week) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (index, week) in state.weeks.indexed)
                  ChoicePill(
                    label: Formats.dayRange(week.first, week.last),
                    selected: index == state.weekIndex,
                    onTap: () => viewModel.setWeek(index),
                    minHeight: 48,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: AsyncValueView(
              value: shifts,
              onRetry: () => ref.invalidate(monthShiftsProvider(state.month)),
              data: (shifts) => temple == null
                  ? const SizedBox.shrink()
                  : _PlanPage(
                      temple: temple,
                      range: range,
                      printedOn: today,
                      table: _PlanTable.build(
                        l10n: l10n,
                        state: state,
                        shifts: shifts,
                        calendar: calendar,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How a cell in the plan is drawn.
enum _CellKind { heading, shift, noShift }

@immutable
class _PlanCell {
  const _PlanCell(
    this.text, {
    this.note = '',
    this.noteIcon,
    this.kind = _CellKind.shift,
    this.noteColor = AppPalette.danger,
    this.stripe,
    this.tinted = false,
  });

  final String text;

  /// Second line: "Needs 2", a practice day, or a shift's hours.
  final String note;

  /// A practice day's mark, drawn before [note].
  final AppIconData? noteIcon;
  final _CellKind kind;
  final Color noteColor;

  /// Coloured left edge identifying a duty.
  final Color? stripe;

  /// Cream background (weekends, row headings).
  final bool tinted;
}

/// The rota laid out for printing. Built from data here so the page widget
/// only draws.
@immutable
class _PlanTable {
  const _PlanTable({
    required this.header,
    required this.columnWidths,
    required this.rows,
  });

  /// Column titles, each optionally followed by a practice-day mark.
  final List<(String, AppIconData?)> header;
  final Map<int, TableColumnWidth> columnWidths;
  final List<List<_PlanCell>> rows;

  static _PlanTable build({
    required AppLocalizations l10n,
    required PlanState state,
    required List<Shift> shifts,
    required TibetanCalendar calendar,
  }) {
    final byId = {for (final shift in shifts) shift.id: shift};

    _PlanCell shiftCell(DateTime day, Duty duty) {
      final shift = byId[Shift.idFor(day, duty)];
      if (shift == null) return const _PlanCell('', kind: _CellKind.noShift);
      return _PlanCell(
        shift.volunteers.isEmpty
            ? l10n.commonEmDash
            : shift.volunteers.join(', '),
        note: shift.isFull ? '' : l10n.shiftNeeds(shift.open),
      );
    }

    List<_PlanCell> dayRow(DateTime day) {
      final tibetan = calendar.dayOf(day);
      final practice = calendar.practiceOn(day);
      final weekend =
          day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
      return [
        _PlanCell(
          Formats.weekdayDay(day),
          kind: _CellKind.heading,
          note: practice?.label(l10n) ?? '',
          noteIcon: practice?.icon,
          noteColor: AppPalette.planPracticeInk,
          tinted: weekend,
        ),
        _PlanCell(l10n.tibetanMonthShort(tibetan.month, tibetan.day)),
        for (final duty in Duty.values) shiftCell(day, duty),
      ];
    }

    if (state.mode == PlanMode.month) {
      return _PlanTable(
        header: [
          (l10n.planColDate, null),
          (l10n.planColTibetan, null),
          for (final duty in Duty.values) (duty.label(l10n), null),
        ],
        columnWidths: const {0: FixedColumnWidth(120), 1: FixedColumnWidth(96)},
        rows: [
          for (var d = 0; d < state.month.daysInMonth; d++)
            dayRow(state.month.addDays(d)),
        ],
      );
    }

    final week = state.week;
    return _PlanTable(
      header: [
        (l10n.planColDuty, null),
        for (final day in week)
          (Formats.weekdayDay(day), calendar.practiceOn(day)?.icon),
      ],
      columnWidths: const {0: FixedColumnWidth(130)},
      rows: [
        for (final duty in Duty.values)
          [
            _PlanCell(
              duty.label(l10n),
              kind: _CellKind.heading,
              note:
                  shifts
                      .where((shift) => shift.duty == duty)
                      .map((shift) => shift.time)
                      .firstOrNull ??
                  '',
              noteColor: AppPalette.paperInkMuted,
              stripe: duty.color,
              tinted: true,
            ),
            for (final day in week) shiftCell(day, duty),
          ],
      ],
    );
  }
}

/// The printed page, scaled down to fit the screen like a print preview.
class _PlanPage extends StatelessWidget {
  const _PlanPage({
    required this.temple,
    required this.range,
    required this.printedOn,
    required this.table,
  });

  final Temple temple;
  final String range;
  final DateTime printedOn;
  final _PlanTable table;

  /// Width the page is laid out at before scaling.
  static const pageWidth = 760.0;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final l10n = context.l10n;
    const ink = AppPalette.paperInk;
    const muted = AppPalette.paperInkMuted;

    Widget cell(_PlanCell cell) {
      return Container(
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: switch (cell.kind) {
            _CellKind.noShift => AppPalette.planNoShift,
            _ => cell.tinted ? AppPalette.cream : Colors.white,
          },
          border: cell.stripe == null
              ? null
              : Border(left: BorderSide(color: cell.stripe!, width: 5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cell.text,
              style: type.sans(
                14,
                weight: cell.kind == _CellKind.heading
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: ink,
                height: 1.35,
              ),
            ),
            if (cell.note.isNotEmpty)
              Row(
                children: [
                  if (cell.noteIcon != null) ...[
                    AppIcon(cell.noteIcon!, size: 10, color: cell.noteColor),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      cell.note,
                      style: type.sans(
                        12,
                        weight: FontWeight.w700,
                        color: cell.noteColor,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    final page = Container(
      width: pageWidth,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              TempleBadge(
                monogram: temple.monogram,
                logo: temple.logo,
                size: 56,
                background: context.colors.accent,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.planDocumentTitle(temple.nameEn),
                      style: type.serif(26, color: ink, height: 1.2),
                    ),
                    Text(range, style: type.sans(17, color: muted)),
                  ],
                ),
              ),
              Text(
                l10n.planPrinted(Formats.date(printedOn)),
                style: type.sans(14, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Double rule under the letterhead.
          Container(height: 1, color: AppPalette.gold),
          const SizedBox(height: 1),
          Container(height: 1, color: AppPalette.gold),
          const SizedBox(height: 16),
          Table(
            columnWidths: table.columnWidths,
            defaultColumnWidth: const FlexColumnWidth(),
            // Every cell stretches to its row so backgrounds and stripes fill it.
            defaultVerticalAlignment:
                TableCellVerticalAlignment.intrinsicHeight,
            border: TableBorder.all(color: AppPalette.paperLine),
            children: [
              TableRow(
                decoration: const BoxDecoration(color: AppPalette.parchment),
                children: [
                  for (final (title, mark) in table.header)
                    TableCell(
                      verticalAlignment: TableCellVerticalAlignment.top,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: type.sans(
                                  15,
                                  weight: FontWeight.w700,
                                  color: ink,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (mark != null) ...[
                              const SizedBox(width: 5),
                              AppIcon(mark, size: 11, color: AppPalette.gold),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              for (final row in table.rows)
                TableRow(children: [for (final item in row) cell(item)]),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              Text.rich(
                TextSpan(
                  text: '${l10n.shiftNeeds(2)} ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.danger,
                  ),
                  children: [
                    TextSpan(
                      text: l10n.planLegendNeeds,
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        color: muted,
                      ),
                    ),
                  ],
                ),
                style: type.sans(13),
              ),
              Text(l10n.planLegendGrey, style: type.sans(13, color: muted)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final practice in PracticeDay.values) ...[
                    AppIcon(practice.icon, size: 11, color: AppPalette.gold),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    l10n.planLegendPractice,
                    style: type.sans(13, color: muted),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    // Text inside the page is part of the document, not the interface: it
    // scales with the page, not with the reader's text size.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: pageWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: MediaQuery.withNoTextScaling(child: page),
          ),
        ),
      ),
    );
  }
}
