import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/app/router/app_router.dart';
import 'package:norbu_flow/app/router/app_routes.dart';
import 'package:norbu_flow/core/feedback/app_messenger.dart';
import 'package:norbu_flow/features/settings/domain/app_preferences.dart';
import 'package:norbu_flow/features/settings/presentation/view_models/preferences_view_model.dart';
import 'package:norbu_flow/features/temple/domain/role.dart';
import 'package:norbu_flow/features/temple/presentation/view_models/temple_session.dart';

import 'support/test_app.dart';

const _phone = Size(390, 844);
const _tabletPortrait = Size(820, 1180);
const _tabletLandscape = Size(1180, 820);

/// Every in-app location, so layout problems anywhere fail a test.
const _locations = [
  AppRoutes.home,
  AppRoutes.letter,
  AppRoutes.announce,
  AppRoutes.hours,
  AppRoutes.reports,
  AppRoutes.tax,
  AppRoutes.prayers,
  AppRoutes.approve,
  AppRoutes.checkIn,
  AppRoutes.members,
  AppRoutes.addMember,
  '/members/m1',
  '/members/m4',
  AppRoutes.offerings,
  '/offerings/donation/other',
  AppRoutes.puja,
  AppRoutes.tsok,
  '/offerings/receipt/latest',
  AppRoutes.calendar,
  '/calendar/assign/2026-10-10',
  AppRoutes.plan,
  AppRoutes.more,
  AppRoutes.team,
  AppRoutes.templeSettings,
];

void main() {
  setUpAll(loadAppFonts);

  testWidgets('first run: splash → intro → sign in → temple → Home', (
    tester,
  ) async {
    tester.setScreenSize(_phone);
    final container = createContainer();
    await tester.pumpApp(container);

    expect(find.text('NorbuFlow'), findsOneWidget);
    await tester.tap(find.text('Tap to begin'));
    await tester.pumpAndSettle();

    expect(find.text('Members & ID cards'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to your temple'), findsOneWidget);
    await tester.tap(find.text('Email me a sign-in link'));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsOneWidget);
    await tester.tap(find.text('Demo only — pretend I tapped the link'));
    await tester.pumpAndSettle();

    expect(find.text('Choose your temple'), findsOneWidget);
    expect(find.text('You are: Temple Admin'), findsOneWidget);
    await tester.tap(find.text('Jangchub Choling'));
    await tester.pumpAndSettle();

    expect(find.text('Tashi Delek, Dolma'), findsOneWidget);
    expect(find.text('Add a Member'), findsOneWidget);
    expect(container.read(preferencesProvider).onboardingSeen, isTrue);
  });

  testWidgets('an empty email is rejected with a plain-words message', (
    tester,
  ) async {
    tester.setScreenSize(_phone);
    final container = createContainer();
    await tester.pumpApp(container);
    container.read(routerProvider).go(AppRoutes.login);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Email me a sign-in link'));
    await tester.pumpAndSettle();

    expect(find.text('Please type your email.'), findsOneWidget);
    expect(find.text('Sign in to your temple'), findsOneWidget);
  });

  testWidgets('signed-out visitors are sent to sign in', (tester) async {
    tester.setScreenSize(_phone);
    final container = createContainer();
    await tester.pumpApp(container);

    container.read(routerProvider).go(AppRoutes.members);
    await tester.pumpAndSettle();

    expect(find.text('Sign in to your temple'), findsOneWidget);
  });

  testWidgets('the phone tab bar hides on focused tasks', (tester) async {
    tester.setScreenSize(_phone);
    final container = await _signedInApp(tester);

    expect(find.text('Offerings'), findsOneWidget);
    container.read(routerProvider).go(AppRoutes.addMember);
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Offerings'), findsNothing);
  });

  testWidgets('tablets keep navigation visible on focused tasks', (
    tester,
  ) async {
    tester.setScreenSize(_tabletLandscape);
    final container = await _signedInApp(tester);

    container.read(routerProvider).go(AppRoutes.addMember);
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Offerings'), findsOneWidget);
  });

  testWidgets('a tablet shows the member card beside the list', (tester) async {
    tester.setScreenSize(_tabletLandscape);
    final container = await _signedInApp(tester);
    container.read(routerProvider).go(AppRoutes.members);
    await tester.pumpAndSettle();

    expect(find.text('Choose a member to see their ID card.'), findsOneWidget);
    await tester.tap(find.text('Sonam Wangchuk'));
    await tester.pumpAndSettle();

    expect(find.text('MEMBERSHIP CARD'), findsOneWidget);
    expect(find.text('Renew 1 year'), findsOneWidget);
    // Still on the list: the card opened in the second pane.
    expect(find.text('+ Add a Member'), findsOneWidget);
  });

  testWidgets('renewing from the ID card confirms with the new date', (
    tester,
  ) async {
    tester.setScreenSize(_phone);
    final container = await _signedInApp(tester);
    container.read(routerProvider).go('/members/m4');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Renew 1 year'));
    await tester.pumpAndSettle();

    expect(find.text('Renewed. Valid until Sep 30, 2027.'), findsOneWidget);
    expect(find.text('Renew 1 year'), findsNothing);
    container.read(appMessengerProvider.notifier).dismiss();
    await tester.pump();
  });

  testWidgets("an admin can preview another role's Home", (tester) async {
    tester.setScreenSize(_phone);
    final container = await _signedInApp(tester);

    container.read(rolePreviewProvider.notifier).preview(Role.geshe);
    await tester.pumpAndSettle();

    expect(find.text('Prayer Name Lists'), findsOneWidget);
    expect(find.text('Add a Member'), findsNothing);
    await tester.tap(find.text('Exit preview'));
    await tester.pumpAndSettle();
    expect(find.text('Temple team'), findsOneWidget);
  });

  for (final (name, size) in [
    ('phone', _phone),
    ('tablet portrait', _tabletPortrait),
    ('tablet landscape', _tabletLandscape),
  ]) {
    testWidgets('every screen lays out on a $name', (tester) async {
      tester.setScreenSize(size);
      final container = await _signedInApp(tester);
      await _visitEverything(tester, container);
    });
  }

  testWidgets('every screen lays out in dark mode', (tester) async {
    tester.setScreenSize(_phone);
    final container = await _signedInApp(tester);
    container.read(preferencesProvider.notifier).setDarkMode(true);
    await _visitEverything(tester, container);
  });

  testWidgets('every screen lays out in Tibetan with Simple Mode on a phone', (
    tester,
  ) async {
    tester.setScreenSize(_phone);
    final container = await _signedInApp(tester);
    container.read(preferencesProvider.notifier)
      ..setLanguage(AppLanguage.tibetan)
      ..setSimpleMode(true);
    await tester.pumpAndSettle();

    expect(find.textContaining('བཀྲ་ཤིས་བདེ་ལེགས།'), findsOneWidget);
    await _visitEverything(tester, container);
  });
}

Future<ProviderContainer> _signedInApp(WidgetTester tester) async {
  final container = createContainer();
  await tester.pumpApp(container);
  await tester.runAsync(() => signIn(container));
  await tester.pumpAndSettle();
  expect(find.textContaining('Dolma'), findsWidgets);
  return container;
}

Future<void> _visitEverything(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final router = container.read(routerProvider);
  // Collected rather than failing fast, so one run lists every bad screen.
  final problems = <String>[];
  for (final location in _locations) {
    router.go(location);
    await tester.pumpAndSettle();
    final exception = tester.takeException();
    if (exception != null) problems.add('$location: $exception');
    final shown = router.routerDelegate.currentConfiguration.uri.toString();
    if (shown != location) problems.add('$location redirected to $shown');
  }
  expect(problems, isEmpty, reason: problems.join('\n'));
}
