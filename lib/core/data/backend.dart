import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../utils/json.dart';

/// The Cloud Functions backend (`functions/`). Every Firebase repository
/// calls through this, so region, timeout and emulator are decided once.
abstract interface class Backend {
  /// Long enough for a cold start, short enough not to leave someone waiting.
  static const defaultTimeout = Duration(seconds: 20);

  /// Calls the function deployed as [function] (`<feature>-<name>`). Raise
  /// [timeout] only for heavy work, such as getting a document back.
  Future<Map<String, Object?>> call(
    String function, {
    Map<String, Object?>? input,
    Duration timeout = defaultTimeout,
  });
}

final class FirebaseBackend implements Backend {
  FirebaseBackend(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, Object?>> call(
    String function, {
    Map<String, Object?>? input,
    Duration timeout = Backend.defaultTimeout,
  }) async {
    final result = await _functions
        .httpsCallable(
          function,
          options: HttpsCallableOptions(timeout: timeout),
        )
        .call<Object?>(input);
    return jsonObject(result.data);
  }
}

/// The port `firebase emulators:start` serves functions on (firebase.json).
const _emulatorPort = 5001;

final backendProvider = Provider<Backend>((ref) {
  final config = ref.watch(appConfigProvider);
  final functions = FirebaseFunctions.instanceFor(
    region: config.functionsRegion,
  );
  if (config.functionsEmulatorHost.isNotEmpty) {
    functions.useFunctionsEmulator(config.functionsEmulatorHost, _emulatorPort);
  }
  return FirebaseBackend(functions);
});
