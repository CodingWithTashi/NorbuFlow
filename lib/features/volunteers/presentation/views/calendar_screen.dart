import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/calendar/tibetan_calendar.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../offerings/presentation/offering_labels.dart';
import '../../domain/volunteer.dart';
import '../view_models/calendar_view_model.dart';
import '../volunteer_labels.dart';

/// The volunteer calendar: a month of shifts with practice days marked, and
/// the chosen day's shifts with a way to fill the gaps.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(calendarViewModelProvider);
    final shifts = ref.watch(monthShiftsProvider(state.month));
    final dayShifts = ref.watch(dayShiftsProvider(state.selectedDay));
    final hasOpen = dayShifts.value?.any((shift) => !shift.isFull) ?? false;

    final assignButton = PrimaryButton(
      label: hasOpen ? l10n.calendarAssign : l10n.calendarAllFull,
      subdued: !hasOpen,
      onPressed: () {
        if (!hasOpen) {
          ref.toast(l10n.toastAllShiftsFull);
          return;
        }
        context.go(AppRoutes.assign(state.selectedDay.isoDate));
      },
    );

    final month = AsyncValueView(
      value: shifts,
      onRetry: () => ref.invalidate(monthShiftsProvider(state.month)),
      data: (shifts) => _MonthGrid(state: state, shifts: shifts),
    );
    final day = AsyncValueView(
      value: dayShifts,
      data: (shifts) => _DayPanel(day: state.selectedDay, shifts: shifts),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= Breakpoints.twoPane;
        return AppPage(
          maxWidth: Breakpoints.wideContentMaxWidth,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          bottom: twoPane ? null : assignButton,
          child: twoPane
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _MonthHeader(),
                          const SizedBox(height: 10),
                          month,
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _PlanButton(),
                          const SizedBox(height: 14),
                          day,
                          const SizedBox(height: 14),
                          assignButton,
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _MonthHeader(),
                    const SizedBox(height: 10),
                    const _PlanButton(),
                    const SizedBox(height: 10),
                    month,
                    const SizedBox(height: 14),
                    day,
                  ],
                ),
        );
      },
    );
  }
}

class _MonthHeader extends ConsumerWidget {
  const _MonthHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final month = ref.watch(calendarViewModelProvider.select((s) => s.month));
    final viewModel = ref.read(calendarViewModelProvider.notifier);
    final calendar = ref.watch(tibetanCalendarProvider);

    final first = calendar.dayOf(month).month;
    final last = calendar.dayOf(month.addDays(month.daysInMonth - 1)).month;

    Widget arrow(AppIconData icon, String label, VoidCallback onTap) {
      return Semantics(
        button: true,
        label: label,
        child: Material(
          color: colors.surface,
          shape: CircleBorder(side: BorderSide(color: colors.line, width: 1.5)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: 52,
              child: Center(
                child: AppIcon(
                  icon,
                  size: 22,
                  color: colors.ink,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        arrow(
          AppIcons.chevronLeft,
          l10n.calendarPreviousMonth,
          viewModel.previousMonth,
        ),
        Expanded(
          child: Column(
            children: [
              Semantics(
                header: true,
                child: Text(
                  Formats.monthYear(month),
                  textAlign: TextAlign.center,
                  style: type.serif(23, height: 1.25),
                ),
              ),
              Text(
                first == last
                    ? l10n.tibetanMonth(first)
                    : l10n.tibetanMonths(first, last),
                textAlign: TextAlign.center,
                style: type.sans(14, color: colors.inkMuted, height: 1.4),
              ),
            ],
          ),
        ),
        arrow(
          AppIcons.chevronRight,
          l10n.calendarNextMonth,
          viewModel.nextMonth,
        ),
      ],
    );
  }
}

class _PlanButton extends StatelessWidget {
  const _PlanButton();

  @override
  Widget build(BuildContext context) {
    return SecondaryButton(
      label: context.l10n.calendarPlanButton,
      icon: AppIcons.document,
      minHeight: 52,
      fontSize: 16,
      onPressed: () => context.go(AppRoutes.plan),
    );
  }
}

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({required this.state, required this.shifts});

  final CalendarState state;
  final List<Shift> shifts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final calendar = ref.watch(tibetanCalendarProvider);
    final viewModel = ref.read(calendarViewModelProvider.notifier);

    final byDay = <int, List<Shift>>{};
    for (final shift in shifts) {
      byDay.putIfAbsent(shift.date.day, () => []).add(shift);
    }

    // Sunday-first grid: blanks before the 1st, then the days.
    final leading = state.month.weekday % 7;
    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= state.month.daysInMonth; day++)
        _DayCell(
          date: DateTime(state.month.year, state.month.month, day),
          selected: day == state.selectedDay.day,
          practice: calendar.practiceOn(
            DateTime(state.month.year, state.month.month, day),
          ),
          shifts: byDay[day] ?? const [],
          onTap: viewModel.selectDay,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final initial in Formats.weekdayInitials)
              Expanded(
                child: Text(
                  initial,
                  textAlign: TextAlign.center,
                  style: type.sans(
                    13,
                    weight: FontWeight.w600,
                    color: colors.inkMuted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        for (var row = 0; row * 7 < cells.length; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++) ...[
                  if (col > 0) const SizedBox(width: 3),
                  Expanded(
                    child: row * 7 + col < cells.length
                        ? cells[row * 7 + col]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final duty in Duty.values)
              _LegendItem(
                marker: _Dot(color: duty.color, size: 10),
                label: duty.label(l10n),
              ),
            _LegendItem(
              marker: const _Dot(open: true, size: 10),
              label: l10n.calendarNeedsPeople,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final practice in PracticeDay.values)
              _LegendItem(
                marker: AppIcon(
                  practice.icon,
                  size: 12,
                  color: AppPalette.gold,
                ),
                label: practice.label(l10n),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.practice,
    required this.shifts,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final PracticeDay? practice;
  final List<Shift> shifts;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      button: true,
      selected: selected,
      label: Formats.dayTitle(date),
      child: Material(
        color: selected ? colors.accent : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: selected
              ? BorderSide(color: colors.accent, width: 2)
              : BorderSide(color: colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(date),
          child: SizedBox(
            height: 58,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ExcludeSemantics(
                          child: Text(
                            '${date.day}',
                            textScaler: TextScaler.noScaling,
                            style: type.sans(
                              16,
                              weight: FontWeight.w600,
                              color: selected ? Colors.white : colors.ink,
                              height: 1.1,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final (index, shift) in shifts.indexed) ...[
                              if (index > 0) const SizedBox(width: 2),
                              _Dot(
                                color: shift.duty.color,
                                open: !shift.isFull,
                                size: 6,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (practice != null)
                  Positioned(
                    top: 3,
                    right: 4,
                    child: AppIcon(
                      practice!.icon,
                      size: 10,
                      color: AppPalette.gold,
                      strokeWidth: 2.4,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A shift marker: filled in the duty's colour, or a red ring when the shift
/// still needs people.
class _Dot extends StatelessWidget {
  const _Dot({this.color, this.open = false, required this.size});

  final Color? color;
  final bool open;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: open ? Colors.transparent : color,
        border: open ? Border.all(color: AppPalette.danger, width: 2) : null,
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.marker, required this.label});

  final Widget marker;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        marker,
        const SizedBox(width: 5),
        Text(
          label,
          style: context.type.sans(
            13,
            color: context.colors.inkMuted,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// The selected day's shifts and who is on them.
class _DayPanel extends ConsumerWidget {
  const _DayPanel({required this.day, required this.shifts});

  final DateTime day;
  final List<Shift> shifts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final calendar = ref.watch(tibetanCalendarProvider);
    final tibetan = calendar.dayOf(day);
    final practice = calendar.practiceOn(day);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Formats.dayTitle(day), style: type.serif(19)),
          Text.rich(
            TextSpan(
              text: l10n.tibetanDate(tibetan.month, tibetan.day),
              children: [
                if (practice != null) ...[
                  const TextSpan(text: ' · '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 5),
                      child: AppIcon(
                        practice.icon,
                        size: 12,
                        color: AppPalette.gold,
                      ),
                    ),
                  ),
                  TextSpan(text: practice.label(l10n)),
                ],
              ],
            ),
            style: type.sans(14, color: colors.inkMuted, height: 1.5),
          ),
          if (shifts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                l10n.calendarNoShifts,
                style: type.sans(15, color: colors.inkMuted),
              ),
            ),
          for (final shift in shifts) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: colors.line),
            const SizedBox(height: 8),
            _ShiftRow(shift: shift),
          ],
        ],
      ),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  const _ShiftRow({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 6,
            decoration: BoxDecoration(
              color: shift.duty.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: shift.duty.label(l10n),
                    children: [
                      TextSpan(
                        text: ' · ${shift.time}',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  style: type.sans(16, weight: FontWeight.w600, height: 1.3),
                ),
                Text(
                  shift.volunteers.isEmpty
                      ? l10n.shiftNoOneYet
                      : shift.volunteers.join(', '),
                  style: type.sans(14, color: colors.inkMuted, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Align(
            alignment: Alignment.topCenter,
            child: shiftStatusPill(l10n, shift),
          ),
        ],
      ),
    );
  }
}
