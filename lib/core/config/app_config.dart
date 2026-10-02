import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Build-time switches: which backend the app talks to, and whether the
/// "Demo only" shortcuts are shown.
class AppConfig {
  const AppConfig({
    this.useFirebase = false,
    this.functionsRegion = 'us-central1',
    this.functionsEmulatorHost = '',
    this.demoMode = true,
    this.demoEmail = 'dolma@jangchub.org',
    this.demoSignInLink = 'https://norbuflow.app/demo-sign-in',
    this.fakeLatency = const Duration(milliseconds: 350),
    bool? demoMembers,
  }) : _demoMembers = demoMembers;

  /// This build's configuration. `--dart-define=USE_FIREBASE=false` runs it
  /// where no Firebase app is configured (web, desktop).
  const AppConfig.fromEnvironment()
    : this(
        useFirebase: const bool.fromEnvironment(
          'USE_FIREBASE',
          defaultValue: true,
        ),
        functionsEmulatorHost: const String.fromEnvironment(
          'FUNCTIONS_EMULATOR_HOST',
        ),
      );

  /// Off, every repository is an in-memory fake and Firebase is never
  /// initialised. Tests run this way.
  final bool useFirebase;

  /// Where the Cloud Functions run. Must match `functions/src/core/options.ts`.
  final String functionsRegion;

  /// Set to call functions served by `firebase emulators:start` instead of
  /// the deployed ones (`10.0.2.2` from the Android emulator). Empty for none.
  final String functionsEmulatorHost;

  /// Shows shortcuts that simulate actions the fake backend cannot perform.
  final bool demoMode;

  /// Address pre-filled on the sign-in screen when sign-in is simulated.
  final String demoEmail;

  /// What the "Demo only" button passes off as the emailed link.
  final String demoSignInLink;

  /// Round-trip delay simulated by the fake repositories.
  final Duration fakeLatency;

  final bool? _demoMembers;

  /// Whether sign-in is simulated: no email is sent, so a "Demo only" button
  /// stands in for tapping the link.
  bool get demoSignIn => demoMode && !useFirebase;

  /// Whether members are still the demo (the wizard and a drawn card), not
  /// New ID card and the backend's card. Follows [useFirebase] unless set.
  bool get demoMembers => _demoMembers ?? !useFirebase;
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => const AppConfig.fromEnvironment(),
);
