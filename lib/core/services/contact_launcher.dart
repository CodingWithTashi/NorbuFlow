import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../error/app_failure.dart';

/// Opens another app to get in touch with someone. Nothing is sent from
/// here: the person writes and sends the message themselves.
abstract interface class ContactLauncher {
  /// Opens the device's mail app with a new message to [address].
  Future<void> email(String address);

  /// Opens a WhatsApp chat with [digits]: the country code first, no plus.
  Future<void> whatsApp(String digits);
}

final class DeviceContactLauncher implements ContactLauncher {
  const DeviceContactLauncher();

  @override
  Future<void> email(String address) async {
    final opened = await _open(Uri(scheme: 'mailto', path: address));
    if (!opened) throw const UnavailableFailure();
  }

  @override
  Future<void> whatsApp(String digits) async {
    // The app itself if it is installed, else WhatsApp's page in the
    // browser, which offers to install it.
    final opened =
        await _open(
          Uri(
            scheme: 'whatsapp',
            host: 'send',
            queryParameters: {'phone': digits},
          ),
        ) ||
        await _open(Uri.https('wa.me', '/$digits'));
    if (!opened) throw const UnavailableFailure();
  }

  /// Whether some other app took [link]. A device with no app for it says
  /// so by throwing or by answering false, depending on the platform.
  Future<bool> _open(Uri link) async {
    try {
      return await launchUrl(link, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}

final contactLauncherProvider = Provider<ContactLauncher>(
  (ref) => const DeviceContactLauncher(),
);
