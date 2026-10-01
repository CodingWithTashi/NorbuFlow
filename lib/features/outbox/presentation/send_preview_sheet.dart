import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/dialogs.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon.dart';
import '../../../core/widgets/buttons.dart';
import '../domain/outbox.dart';
import 'outbox_actions.dart';

/// Shows exactly what will be sent and to whom, then sends it on "Send now".
/// Nothing leaves the app without this confirmation. Returns whether the
/// message was sent.
///
/// [send] replaces the default delivery for messages that have their own
/// backend call (an announcement goes to whole groups, not one recipient).
Future<bool> showSendPreview(
  BuildContext context,
  OutgoingMessage message, {
  Future<bool> Function()? send,
}) async {
  final l10n = context.l10n;
  final sent = await showAppSheet<bool>(
    context: context,
    title: switch (message.channel) {
      DeliveryChannel.email => l10n.sendPreviewEmail,
      DeliveryChannel.whatsApp => l10n.sendPreviewWhatsApp,
    },
    builder: (_) => _SendPreview(message: message, send: send),
  );
  return sent ?? false;
}

class _SendPreview extends ConsumerStatefulWidget {
  const _SendPreview({required this.message, this.send});

  final OutgoingMessage message;
  final Future<bool> Function()? send;

  @override
  ConsumerState<_SendPreview> createState() => _SendPreviewState();
}

class _SendPreviewState extends ConsumerState<_SendPreview> {
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    final send =
        widget.send ??
        () => ref.read(outboxActionsProvider).send(widget.message);
    final sent = await send();
    if (!mounted) return;
    if (sent) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final message = widget.message;
    final whatsApp = message.channel == DeliveryChannel.whatsApp;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: '${l10n.sendTo} ',
            children: [
              TextSpan(
                text: message.recipient,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
            ],
          ),
          style: type.sans(15, color: colors.inkMuted),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: whatsApp ? AppPalette.whatsAppPreview : AppPalette.paper,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.line),
          ),
          child: Text(
            message.body,
            style: type.sans(16, color: AppPalette.paperInk, height: 1.6),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.line),
          ),
          child: Row(
            children: [
              AppIcon(AppIcons.paperclip, size: 20, color: colors.inkMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message.attachment,
                  style: type.sans(15, color: colors.inkMuted, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PrimaryButton(label: l10n.sendNow, onPressed: _send, busy: _sending),
        LinkButton(
          label: l10n.sendNotYet,
          expand: true,
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
