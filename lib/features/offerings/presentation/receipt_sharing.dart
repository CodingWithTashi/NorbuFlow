import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_messenger.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/success_view.dart';
import '../../outbox/domain/outbox.dart';
import '../../outbox/presentation/outbox_actions.dart';
import '../../outbox/presentation/send_preview_sheet.dart';
import '../../temple/domain/temple.dart';
import '../domain/offering.dart';
import 'offering_labels.dart';

/// Print / Email / WhatsApp for a receipt. Shared by the receipt screen and
/// the confirmations that follow recording an offering, so the wording of
/// the message is written once.
List<ShareAction> receiptShareActions(
  BuildContext context,
  WidgetRef ref, {
  required Receipt receipt,
  required Temple temple,
}) {
  final l10n = context.l10n;
  final firstName = firstNameOf(receipt.receivedFrom);

  final puja = receipt.puja;
  final body = puja != null
      ? l10n.msgReceiptPujaBody(
          firstName,
          puja.ceremony.nameEn,
          Formats.dayTitle(puja.date),
          temple.nameEn,
        )
      : l10n.msgReceiptDonationBody(
          firstName,
          Formats.money(receipt.amount),
          receipt.donation!.kind.label(l10n).toLowerCase(),
          temple.nameEn,
        );

  Future<void> send(DeliveryChannel channel) async {
    final whatsApp = channel == DeliveryChannel.whatsApp;
    final sent = await showSendPreview(
      context,
      OutgoingMessage(
        channel: channel,
        recipient: whatsApp
            ? receipt.receivedFrom
            : (receipt.contact.isEmpty ? l10n.commonEmDash : receipt.contact),
        body: body,
        attachment: l10n.msgReceiptAttachment(receipt.number),
      ),
    );
    if (sent) {
      ref.toast(whatsApp ? l10n.toastSentWhatsApp : l10n.toastSentEmail);
    }
  }

  return [
    ShareAction(
      icon: AppIcons.print,
      label: l10n.commonPrint,
      onTap: () async {
        final printed = await ref
            .read(outboxActionsProvider)
            .printDocument(receipt.number);
        if (printed) ref.toast(l10n.toastPrinted);
      },
    ),
    ShareAction(
      icon: AppIcons.mail,
      label: l10n.commonEmail,
      onTap: () => send(DeliveryChannel.email),
    ),
    ShareAction(
      icon: AppIcons.chat,
      label: l10n.commonWhatsApp,
      onTap: () => send(DeliveryChannel.whatsApp),
    ),
  ];
}
