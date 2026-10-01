import 'package:flutter/foundation.dart';

enum DeliveryChannel { email, whatsApp }

enum ExportFormat { pdf, excel }

/// Something the temple sends to people: a receipt, an ID card, a letter.
@immutable
class OutgoingMessage {
  const OutgoingMessage({
    required this.channel,
    required this.recipient,
    required this.body,
    required this.attachment,
  });

  final DeliveryChannel channel;

  /// Who it goes to, as shown in the preview ("Tenzin Dolkar · 416 555 0142").
  final String recipient;
  final String body;

  /// Description of what is attached ("Receipt R-2026-0917.pdf").
  final String attachment;
}

/// Everything that leaves the app: messages, print jobs and exported files.
/// One seam, so the Cloud Functions that will do this for real have a single
/// place to plug in.
abstract interface class OutboxRepository {
  Future<void> send(OutgoingMessage message);

  Future<void> printDocument(String title);

  Future<void> export(String title, ExportFormat format);

  Future<void> addToWallet(String title);
}
