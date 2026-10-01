import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Build-time switches for the app.
///
/// While the backend is faked this is the one place that says so; flipping
/// [demoMode] off hides the "Demo only" shortcuts that stand in for things a
/// real backend does (tapping the email link, scanning a QR code).
class AppConfig {
  const AppConfig({
    this.demoMode = true,
    this.demoEmail = 'dolma@jangchub.org',
    this.fakeLatency = const Duration(milliseconds: 350),
  });

  /// Shows shortcuts that simulate actions the fake backend cannot perform.
  final bool demoMode;

  /// Address pre-filled on the sign-in screen in demo mode.
  final String demoEmail;

  /// Round-trip delay simulated by the fake repositories.
  final Duration fakeLatency;
}

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());
