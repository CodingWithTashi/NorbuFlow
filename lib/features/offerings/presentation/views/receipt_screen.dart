import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/calendar/tibetan_calendar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/avatars.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/success_view.dart';
import '../../../members/presentation/member_labels.dart';
import '../../../settings/presentation/view_models/preferences_view_model.dart';
import '../../../temple/domain/temple.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../domain/offering.dart';
import '../offering_labels.dart';
import '../receipt_sharing.dart';
import '../view_models/offering_providers.dart';

/// An official donation receipt, ready to print, email or WhatsApp.
class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key, required this.number});

  /// A receipt number, or [latestReceiptKey].
  final String number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final receipt = ref.watch(receiptProvider(number));
    final temple = ref.watch(currentTempleProvider);
    void back() => context.popOrGo(AppRoutes.offerings);

    return AsyncValueView(
      value: receipt,
      onRetry: () => ref.invalidate(receiptProvider(number)),
      data: (receipt) {
        if (receipt == null || temple == null) {
          return AppPage(
            backLabel: l10n.navOfferings,
            onBack: back,
            child: MessageView(message: l10n.receiptEmpty),
          );
        }
        return AppPage(
          backLabel: l10n.navOfferings,
          onBack: back,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          bottom: ShareActionRow(
            filled: true,
            actions: receiptShareActions(
              context,
              ref,
              receipt: receipt,
              temple: temple,
            ),
          ),
          child: _ReceiptDocument(receipt: receipt, temple: temple),
        );
      },
    );
  }
}

/// The receipt as it prints: always light "paper", whatever the app theme.
class _ReceiptDocument extends ConsumerWidget {
  const _ReceiptDocument({required this.receipt, required this.temple});

  final Receipt receipt;
  final Temple temple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = context.type;
    final l10n = context.l10n;
    final locale = ref.watch(localeProvider);
    final tibetan = ref.watch(tibetanCalendarProvider).dayOf(receipt.issuedOn);
    const ink = AppPalette.paperInk;
    const muted = AppPalette.paperInkMuted;

    final issued = locale.languageCode == 'bo'
        ? Formats.homeDate(receipt.issuedOn, locale)
        : '${Formats.date(receipt.issuedOn)} · '
              '${l10n.tibetanDate(tibetan.month, tibetan.day)}';
    final names = receipt.prayerNames(l10n);
    final payment = receipt.donation?.payment;
    final letterhead = [
      temple.address,
      temple.charityRegistration,
    ].where((line) => line.isNotEmpty).join('\n');

    final rows = [
      (l10n.receiptDate, issued),
      (l10n.receiptFrom, receipt.receivedFrom),
      (l10n.receiptFor, receipt.purpose(l10n)),
      if (names.isNotEmpty) (l10n.receiptNames, names),
      if (payment != null) (l10n.commonPayment, payment.label(l10n)),
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppPalette.paper,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: AppPalette.espresso.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: AppPalette.gold, width: 2),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(border: Border.all(color: AppPalette.gold)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: TempleBadge(
                  monogram: temple.monogram,
                  logo: temple.logo,
                  size: 52,
                  background: context.colors.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                temple.nameEn,
                textAlign: TextAlign.center,
                style: type.serif(19, color: ink, height: 1.25),
              ),
              if (temple.nameBo.isNotEmpty)
                Text(
                  temple.nameBo,
                  textAlign: TextAlign.center,
                  style: type.tibetan(17, color: AppPalette.paperInkSoft),
                ),
              // Until a temple has given them, there is nothing to print here.
              if (letterhead.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  letterhead,
                  textAlign: TextAlign.center,
                  style: type.sans(12.5, color: muted, height: 1.5),
                ),
              ],
              const SizedBox(height: 14),
              const PrayerFlagStripe(height: 4, white: AppPalette.parchment),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      l10n.receiptTitle,
                      style: type.serif(18, color: ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    receipt.number,
                    style: type.sans(13, color: muted, height: 1.3),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final (label, value) in rows)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppPalette.paperLine),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: type.sans(13, color: muted, height: 1.9),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          style: type.sans(
                            15,
                            weight: FontWeight.w500,
                            color: ink,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.parchment,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.receiptAmount,
                        style: type.sans(
                          15,
                          weight: FontWeight.w600,
                          color: ink,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Text(
                      Formats.moneyExact(receipt.amount),
                      style: type.serif(
                        26,
                        color: AppPalette.maroonDeep,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${l10n.receiptTax} ${l10n.receiptThanks}',
                style: type.sans(
                  13,
                  color: AppPalette.paperInkSoft,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                temple.signatory,
                style: type.serif(
                  22,
                  weight: FontWeight.w400,
                  style: FontStyle.italic,
                  color: ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(width: 180, height: 1, color: ink),
              ),
              const SizedBox(height: 2),
              Text(
                '${l10n.receiptSignature} · ${Formats.date(receipt.issuedOn)}',
                style: type.sans(12, color: muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
