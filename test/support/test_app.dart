import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/app/app.dart';
import 'package:norbu_flow/core/config/app_config.dart';
import 'package:norbu_flow/core/error/provider_error_observer.dart';
import 'package:norbu_flow/core/utils/clock.dart';
import 'package:norbu_flow/features/auth/presentation/view_models/auth_view_model.dart';
import 'package:norbu_flow/features/temple/data/fake_temple_repository.dart';
import 'package:norbu_flow/features/temple/presentation/view_models/temple_session.dart';

/// Registers the app's bundled fonts, so widget tests measure text with real
/// glyph widths rather than the test font's full-width boxes.
Future<void> loadAppFonts() async {
  const families = {
    'AtkinsonHyperlegibleNext': ['AtkinsonHyperlegibleNext.ttf'],
    'SourceSerif4': ['SourceSerif4.ttf', 'SourceSerif4-Italic.ttf'],
    'NotoSerifTibetan': ['NotoSerifTibetan.ttf'],
  };
  for (final MapEntry(key: family, value: files) in families.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

/// The moment every test runs at: Wednesday 30 September 2026, 10:42.
final testNow = DateTime(2026, 9, 30, 10, 42);

/// Firebase off, so every repository is its in-memory fake, and no latency.
const testConfig = AppConfig(fakeLatency: Duration.zero);

/// Overrides that make the fakes instant and time fixed.
List<Override> testOverrides({AppConfig config = testConfig}) => [
  appConfigProvider.overrideWithValue(config),
  clockProvider.overrideWithValue(() => testNow),
];

/// A container for view-model tests, disposed with the test.
ProviderContainer createContainer({
  List<Override> overrides = const [],
  AppConfig config = testConfig,
}) {
  final container = ProviderContainer(
    overrides: [
      ...testOverrides(config: config),
      ...overrides,
    ],
    retry: appRetryPolicy,
  );
  addTearDown(container.dispose);
  return container;
}

/// A container already signed in and working in Jangchub Choling.
Future<ProviderContainer> createSignedInContainer({
  List<Override> overrides = const [],
  String templeId = FakeTemples.jangchubId,
}) async {
  final container = createContainer(overrides: overrides);
  await signIn(container, templeId: templeId);
  return container;
}

Future<void> signIn(
  ProviderContainer container, {
  String templeId = FakeTemples.jangchubId,
}) async {
  final auth = container.read(authViewModelProvider.notifier);
  await auth.sendSignInLink('dolma@jangchub.org');
  await auth.completeSignIn(container.read(appConfigProvider).demoSignInLink);
  await container.read(templesProvider.future);
  container.read(currentTempleIdProvider.notifier).select(templeId);
}

extension AppTester on WidgetTester {
  /// Sizes the test window in logical pixels.
  void setScreenSize(Size size) {
    view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(view.reset);
  }

  /// Pumps the whole app on top of [container].
  Future<void> pumpApp(ProviderContainer container) async {
    await pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const NorbuFlowApp(),
      ),
    );
    await pump();
  }

  /// Taps [label] and waits for [shown] when what comes between is real work
  /// (decoding an image, drawing a PDF) that the test's fake clock cannot run.
  Future<void> tapAndWaitFor(String label, Finder shown) async {
    await runAsync(() async {
      await tap(find.text(label));
      final patience = Stopwatch()..start();
      while (shown.evaluate().isEmpty &&
          patience.elapsed < const Duration(seconds: 10)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await pump();
      }
    });
    await pumpAndSettle();
    expect(shown, findsWidgets, reason: 'after tapping "$label"');
  }
}
