import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
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
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/tiles.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../members/domain/member.dart' show MembershipStatus;
import '../../../members/presentation/member_labels.dart';
import '../../../members/presentation/view_models/members_view_model.dart';
import '../../../outbox/domain/outbox.dart';
import '../../../outbox/presentation/outbox_actions.dart';
import '../../domain/report.dart';
import '../view_models/report_view_models.dart';

extension on ReportCategory {
  String label(AppLocalizations l10n) => switch (this) {
    ReportCategory.pujaTsok => l10n.reportCategoryPuja,
    ReportCategory.membership => l10n.reportCategoryMembership,
    ReportCategory.buildingFund => l10n.reportCategoryBuildingFund,
    ReportCategory.butterLamp => l10n.reportCategoryButterLamp,
    ReportCategory.general => l10n.reportCategoryGeneral,
  };
}

/// This month at a glance: offerings by type and memberships needing renewal.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final report = ref.watch(monthlyReportProvider);
    final month = ref.watch(todayProvider).firstOfMonth;
    final title = '${l10n.reportsTitle} · ${Formats.monthYear(month)}';

    Future<void> export(ExportFormat format, String done) async {
      final saved = await ref.read(outboxActionsProvider).export(title, format);
      if (saved) ref.toast(done);
    }

    return AppPage(
      backLabel: l10n.navHome,
      onBack: () => context.popOrGo(AppRoutes.home),
      maxWidth: Breakpoints.wideContentMaxWidth,
      bottom: EqualRow(
        children: [
          PrimaryButton(
            label: l10n.reportsExportPdf,
            fontSize: 17,
            onPressed: () => export(ExportFormat.pdf, l10n.toastReportPdf),
          ),
          SecondaryButton(
            label: l10n.reportsExportExcel,
            minHeight: 60,
            onPressed: () => export(ExportFormat.excel, l10n.toastReportExcel),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeading(
            title: l10n.reportsTitle,
            subtitle: Formats.monthYear(month),
          ),
          const SizedBox(height: 14),
          AsyncValueView(
            value: report,
            onRetry: () => ref.invalidate(monthlyReportProvider),
            data: (report) => AdaptiveColumns(
              primary: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TotalCard(report: report),
                  const SizedBox(height: 14),
                  _ByTypeCard(report: report),
                ],
              ),
              secondary: const _MembershipsDueCard(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final previous = Formats.monthName(
      DateTime(report.month.year, report.month.month - 1),
    );
    final up = report.changePercent >= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.reportsOfferingsThisMonth,
            style: type.sans(16, color: colors.inkMuted),
          ),
          const SizedBox(height: 6),
          Text(
            Formats.money(report.total),
            style: type.serif(44, height: 1.05),
          ),
          const SizedBox(height: 6),
          StatusPill(
            label: up
                ? l10n.reportsChangeUp(report.changePercent, previous)
                : l10n.reportsChangeDown(report.changePercent.abs(), previous),
            icon: up ? AppIcons.arrowUp : AppIcons.arrowDown,
            tone: up ? PillTone.success : PillTone.warning,
            height: 30,
            fontSize: 14,
          ),
        ],
      ),
    );
  }
}

class _ByTypeCard extends StatelessWidget {
  const _ByTypeCard({required this.report});

  final MonthlyReport report;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final largest = report.byCategory.fold(
      0,
      (max, c) => c.amount > max ? c.amount : max,
    );

    return _Card(
      title: l10n.reportsByType,
      children: [
        for (final item in report.byCategory) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(item.category.label(l10n), style: type.sans(16)),
              ),
              Text(
                Formats.money(item.amount),
                style: type.sans(16, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ProgressBar(
            fraction: largest == 0 ? 0 : item.amount / largest,
            color: colors.accent,
            height: 14,
            radius: 4,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MembershipsDueCard extends ConsumerWidget {
  const _MembershipsDueCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = context.type;
    final l10n = context.l10n;
    final due = ref.watch(membershipDueProvider);

    Widget stat(
      int count,
      MembershipStatus status,
      Color background,
      Color foreground,
    ) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count', style: type.serif(32, color: foreground, height: 1)),
            const SizedBox(height: 2),
            IconLabel(
              icon: status.icon,
              label: status.label(l10n),
              style: type.sans(
                15,
                weight: FontWeight.w700,
                color: foreground,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return _Card(
      title: l10n.reportsMembershipsDue,
      children: [
        EqualRow(
          children: [
            stat(
              due.expiring,
              MembershipStatus.expiring,
              AppPalette.warningBg,
              AppPalette.warningFg,
            ),
            stat(
              due.expired,
              MembershipStatus.expired,
              AppPalette.dangerBg,
              AppPalette.dangerFg,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: l10n.reportsSeeMembers,
          minHeight: 52,
          fontSize: 16,
          onPressed: () => context.go(AppRoutes.members),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.line, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.type.sectionTitle),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
