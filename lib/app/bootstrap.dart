import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/error/error_reporter.dart';
import '../core/error/failure_mapper.dart';
import '../core/error/provider_error_observer.dart';
import '../features/auth/data/auth_repositories.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/view_models/auth_view_model.dart';
import '../features/settings/data/preferences_repositories.dart';
import '../features/settings/domain/app_preferences.dart';
import '../features/settings/presentation/view_models/preferences_view_model.dart';
import '../firebase_options.dart';
import 'app.dart';

/// Starts the app: connects Firebase, loads what the device has saved,
/// routes every uncaught error to [ErrorReporter], then runs [NorbuFlowApp].
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Saved state is read before the first frame so the app does not flash its
  // defaults. A throwaway container resolves the repositories it needs.
  final setup = ProviderContainer();
  if (setup.read(appConfigProvider).useFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  final preferencesRepository = setup.read(preferencesRepositoryProvider);
  final authRepository = setup.read(authRepositoryProvider);
  final reporter = setup.read(errorReporterProvider);
  setup.dispose();

  // Saved state that cannot be read is reported and replaced by [fallback].
  Future<T> load<T>(
    String source,
    Future<T> Function() read,
    T fallback,
  ) async {
    try {
      return await read();
    } catch (error, stackTrace) {
      reporter.report(
        FailureMapper.map(error),
        stackTrace: stackTrace,
        source: source,
      );
      return fallback;
    }
  }

  final (preferences, session) = await (
    load(
      'preferences.load',
      preferencesRepository.load,
      const AppPreferences(),
    ),
    load('auth.restore', authRepository.restore, const AuthSession()),
  ).wait;

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
        initialSessionProvider.overrideWithValue(session),
      ],
      child: const NorbuFlowApp(),
    ),
  );
}
