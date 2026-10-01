import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/error/error_reporter.dart';
import '../core/error/failure_mapper.dart';
import '../core/error/provider_error_observer.dart';
import '../features/settings/data/preferences_repositories.dart';
import '../features/settings/domain/app_preferences.dart';
import '../features/settings/presentation/view_models/preferences_view_model.dart';
import 'app.dart';

/// Starts the app: loads saved preferences, installs the error hooks, then
/// runs [NorbuFlowApp].
///
/// Every uncaught error — from a widget, the platform, or a provider — ends
/// up at the same [ErrorReporter].
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preferences are read before the first frame so the app opens in the
  // saved language and theme instead of flashing the defaults. A throwaway
  // container resolves the repository; the same instance is then handed to
  // the real container.
  final setup = ProviderContainer();
  final preferencesRepository = setup.read(preferencesRepositoryProvider);
  final reporter = setup.read(errorReporterProvider);
  setup.dispose();

  AppPreferences preferences;
  try {
    preferences = await preferencesRepository.load();
  } catch (error, stackTrace) {
    reporter.report(
      FailureMapper.map(error),
      stackTrace: stackTrace,
      source: 'preferences.load',
    );
    preferences = const AppPreferences();
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reporter.report(
      FailureMapper.map(details.exception),
      stackTrace: details.stack,
      source: 'flutter',
    );
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    reporter.report(
      FailureMapper.map(error),
      stackTrace: stackTrace,
      source: 'platform',
    );
    return true;
  };

  runApp(
    ProviderScope(
      observers: const [ProviderErrorObserver()],
      retry: appRetryPolicy,
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(preferencesRepository),
        errorReporterProvider.overrideWithValue(reporter),
        initialPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const NorbuFlowApp(),
    ),
  );
}
