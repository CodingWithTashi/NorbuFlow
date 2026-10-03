import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/core/calendar/tibetan_calendar.dart';
import 'package:norbu_flow/core/config/app_config.dart';
import 'package:norbu_flow/core/data/backend.dart';
import 'package:norbu_flow/core/error/app_failure.dart';
import 'package:norbu_flow/core/error/validation_issue.dart';
import 'package:norbu_flow/core/feedback/app_messenger.dart';
import 'package:norbu_flow/core/models/photo_source.dart';
import 'package:norbu_flow/core/theme/accent_preset.dart';
import 'package:norbu_flow/features/auth/data/auth_repositories.dart';
import 'package:norbu_flow/features/auth/data/fake_auth_repository.dart';
import 'package:norbu_flow/features/auth/presentation/view_models/auth_view_model.dart';
import 'package:norbu_flow/features/offerings/presentation/view_models/offering_providers.dart';
import 'package:norbu_flow/features/offerings/presentation/view_models/puja_view_model.dart';
import 'package:norbu_flow/features/temple/data/fake_temple_repository.dart';
import 'package:norbu_flow/features/temple/data/firebase_temple_repository.dart';
import 'package:norbu_flow/features/temple/data/temple_repositories.dart';
import 'package:norbu_flow/features/temple/domain/role.dart';
import 'package:norbu_flow/features/temple/domain/temple_features.dart';
import 'package:norbu_flow/features/temple/presentation/view_models/team_view_model.dart';
import 'package:norbu_flow/features/temple/presentation/view_models/temple_session.dart';
import 'package:norbu_flow/features/volunteers/presentation/view_models/assign_view_model.dart';
import 'package:norbu_flow/features/volunteers/presentation/view_models/calendar_view_model.dart';
import 'package:norbu_flow/features/volunteers/presentation/view_models/plan_view_model.dart';

import '../support/cards.dart';
import '../support/fake_backend.dart';
import '../support/test_app.dart';

void main() {
  group('FirebaseTempleRepository', () {
    late FakeBackend backend;
    late FirebaseTempleRepository repository;

    setUp(() {
      backend = FakeBackend({
        'temples': <Object?>[
          <Object?, Object?>{
            'id': 'drolma-ling-centre',
            'name': 'Drolma Ling Centre',
            'description': 'Kagyu tradition · Vancouver',
            'role': 'admin',
            'logo': base64Encode(frontPage),
            'features': ['tab.members', 'home.addMember', 'home.letter'],
          },
          <Object?, Object?>{
            'id': 'drepung-loseling-canada',
            'name': 'Drepung Loseling Canada',
            'description': '',
            'role': 'frontDesk',
            'logo': null,
          },
        ],
      });
      repository = FirebaseTempleRepository(backend);
    });

    test('lists the temples the backend assigned to whoever is signed in, '
        'with their role at each', () async {
      final memberships = await repository.fetchMemberships('uid-lama');

      // The backend knows who is calling: nothing is sent.
      expect(backend.calls, ['temples-list']);
      expect(backend.inputs.single, isNull);
      expect(memberships.map((membership) => membership.role), [
        Role.admin,
        Role.frontDesk,
      ]);
      final temple = memberships.first.temple;
      expect(temple.id, 'drolma-ling-centre');
      expect(temple.nameEn, 'Drolma Ling Centre');
      expect(temple.tradition, 'Kagyu tradition · Vancouver');
      expect(temple.monogram, 'DL');
      expect((temple.logo! as MemoryPhoto).bytes, frontPage);
      expect(memberships.last.temple.logo, isNull);
    });

    test('shows the tabs and Home cards the backend says each temple shows, '
        'and everything when it says nothing', () async {
      final [drolma, loseling] = await repository.fetchMemberships('uid-lama');

      final shown = drolma.temple.features;
      expect(TempleTab.values.where(shown.shows), [TempleTab.members]);
      expect(HomeAction.values.where(shown.showsHome), [
        HomeAction.addMember,
        HomeAction.letter,
      ]);
      final everything = loseling.temple.features;
      expect(TempleTab.values.every(everything.shows), isTrue);
      expect(HomeAction.values.every(everything.showsHome), isTrue);
    });

    test('skips newer names, and anything that is not a name', () async {
      backend.response = {
        'temples': <Object?>[
          <Object?, Object?>{
            'id': 'drolma-ling-centre',
            'name': 'Drolma Ling Centre',
            'description': '',
            'role': 'admin',
            'logo': null,
            'features': <Object?>[
              'tab.calendar',
              'tab.library',
              'home.bless',
              null,
            ],
          },
        ],
      };

      final [drolma] = await repository.fetchMemberships('uid-lama');

      final shown = drolma.temple.features;
      expect(TempleTab.values.where(shown.shows), [TempleTab.calendar]);
      expect(HomeAction.values.where(shown.showsHome), isEmpty);
    });

    test('says so when no temple was assigned to them', () async {
      backend.error = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'On no team.',
        details: {'reason': 'notOnTeam'},
      );

      await expectLater(
        repository.fetchMemberships('uid-stranger'),
        throwsA(
          isA<PermissionFailure>().having(
            (failure) => failure.reason,
            'reason',
            PermissionReason.notOnTeam,
          ),
        ),
      );
    });

    test('does not save temple settings yet, and says so rather than '
        'pretending', () async {
      final temple = (await repository.fetchMemberships('uid')).first.temple;

      await expectLater(
        repository.updateTemple(temple.copyWith(nameEn: 'Renamed')),
        throwsA(isA<UnavailableFailure>()),
      );
      expect(backend.calls, ['temples-list']);
    });

    test('is what the app uses once the backend is on', () async {
      final container = createContainer(
        config: const AppConfig(useFirebase: true, fakeLatency: Duration.zero),
        overrides: [
          backendProvider.overrideWithValue(backend),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(Duration.zero),
          ),
        ],
      );
      final auth = container.read(authViewModelProvider.notifier);
      await auth.sendSignInLink('lama.karma@drolmaling.ca');
      await auth.completeSignIn('the link');

      expect(
        container.read(templeRepositoryProvider),
        isA<FirebaseTempleRepository>(),
      );
      final temples = await container.read(templesProvider.future);
      expect(temples.map((membership) => membership.temple.nameEn), [
        'Drolma Ling Centre',
        'Drepung Loseling Canada',
      ]);
      // A temple the demo knows nothing of still has a team screen.
      container
          .read(currentTempleIdProvider.notifier)
          .select('drolma-ling-centre');
      expect(await container.read(teamProvider.future), isEmpty);
    });
  });

  group('choosing a temple', () {
    setUpAll(loadAppFonts);

    testWidgets('offers "Add a temple" locked: it only says who adds them', (
      tester,
    ) async {
      tester.setScreenSize(const Size(390, 844));
      final container = createContainer();
      await tester.pumpApp(container);
      final auth = container.read(authViewModelProvider.notifier);
      await tester.runAsync(() async {
        await auth.sendSignInLink('dolma@jangchub.org');
        await auth.completeSignIn('the link');
      });
      await tester.pumpAndSettle();

      expect(find.text('Choose your temple'), findsOneWidget);
      expect(find.text('Add a temple'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);

      await tester.ensureVisible(find.text('Add a temple'));
      await tester.tap(find.text('Add a temple'));
      await tester.pumpAndSettle();

      // Still choosing: nothing was added and nowhere else was opened.
      expect(find.text('Choose your temple'), findsOneWidget);
      expect(
        container.read(appMessengerProvider)?.text,
        'Temples are added by NorbuFlow. Contact us to add another.',
      );
      expect(container.read(currentTempleIdProvider), isNull);
      container.read(appMessengerProvider.notifier).dismiss();
      await tester.pump();
    });

    testWidgets('offers it in the temple switcher too', (tester) async {
      tester.setScreenSize(const Size(390, 844));
      final container = createContainer();
      await tester.pumpApp(container);
      await tester.runAsync(() => signIn(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jangchub Choling'));
      await tester.pumpAndSettle();

      expect(find.text('Which temple?'), findsOneWidget);
      expect(find.text('Add a temple'), findsOneWidget);
      expect(find.text('Locked'), findsOneWidget);
    });
  });

  group('session', () {
    test('role and accent follow the chosen temple', () async {
      final container = await createSignedInContainer();
      expect(container.read(myRoleProvider), Role.admin);
      expect(
        container.read(currentTempleProvider)?.accent,
        AccentPreset.maroon,
      );

      container.read(currentTempleIdProvider.notifier).select('dl');
      expect(container.read(myRoleProvider), Role.accountant);
      expect(
        container.read(currentTempleProvider)?.accent,
        AccentPreset.lapisBlue,
      );
    });

    test('signing out clears the temple and any role preview', () async {
      final container = await createSignedInContainer();
      container.read(rolePreviewProvider.notifier).preview(Role.geshe);
      expect(container.read(homeRoleProvider), Role.geshe);

      await container.read(authViewModelProvider.notifier).signOut();

      expect(container.read(currentTempleIdProvider), isNull);
      expect(container.read(rolePreviewProvider), isNull);
    });

    test("Home shows the role's cards that the temple has on, for a "
        'previewed role too', () async {
      final container = await createSignedInContainer(
        overrides: [
          currentTempleProvider.overrideWith(
            (ref) => FakeTemples.all.first.copyWith(
              features: const TempleFeatures(
                tabs: {TempleTab.members},
                homeActions: {
                  HomeAction.letter,
                  HomeAction.addMember,
                  HomeAction.tax,
                },
              ),
            ),
          ),
        ],
      );
      expect(container.read(homeActionsProvider), [
        HomeAction.addMember,
        HomeAction.letter,
      ]);

      final preview = container.read(rolePreviewProvider.notifier);
      preview.preview(Role.coordinator);
      expect(container.read(homeActionsProvider), [HomeAction.letter]);
      preview.preview(Role.geshe);
      expect(container.read(homeActionsProvider), isEmpty);
    });

    test('Home shows all of the role\'s cards in the demo', () async {
      final container = await createSignedInContainer();

      expect(container.read(homeActionsProvider), Role.admin.homeActions);
    });
  });

  group('team', () {
    test(
      'inviting an existing address is flagged on the email field',
      () async {
        final container = await createSignedInContainer();
        await container.read(teamProvider.future);
        final subscription = container.listen(
          inviteViewModelProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final invite = container.read(inviteViewModelProvider.notifier)
          ..setEmail('Sonam.W@gmail.com');

        expect(await invite.submit(), isNull);
        expect(
          container.read(inviteViewModelProvider).issue,
          ValidationIssue.alreadyOnTeam,
        );
        // Shown inline, so no toast as well.
        expect(container.read(appMessengerProvider), isNull);
      },
    );

    test('a new invite joins the team as pending', () async {
      final container = await createSignedInContainer();
      await container.read(teamProvider.future);
      final subscription = container.listen(inviteViewModelProvider, (_, _) {});
      addTearDown(subscription.close);
      final invite = container.read(inviteViewModelProvider.notifier)
        ..setEmail('lhakpa.tsering@example.com')
        ..setRole(Role.volunteer);

      final invited = await invite.submit();

      expect(invited?.name, 'Lhakpa Tsering');
      expect(invited?.invitePending, isTrue);
      expect(container.read(teamProvider).requireValue, hasLength(7));
    });

    test('people cannot change their own role', () async {
      final container = await createSignedInContainer();
      final team = await container.read(teamProvider.future);
      final me = team.firstWhere((member) => member.isYou);

      final result = await container
          .read(teamProvider.notifier)
          .updateRole(me, Role.volunteer);

      expect(
        result.failureOrNull,
        isA<PermissionFailure>().having(
          (f) => f.reason,
          'reason',
          PermissionReason.ownRole,
        ),
      );
      container.read(appMessengerProvider.notifier).dismiss();
    });

    test('a removed member can be restored (Undo)', () async {
      final container = await createSignedInContainer();
      final team = await container.read(teamProvider.future);
      final viewModel = container.read(teamProvider.notifier);
      final ruth = team.firstWhere((member) => member.name == 'Ruth Abernathy');

      await viewModel.remove(ruth);
      expect(container.read(teamProvider).requireValue, hasLength(5));

      await viewModel.restore(ruth);
      expect(await container.read(teamProvider.future), hasLength(6));
    });
  });

  group('offerings', () {
    test(
      'a Puja request issues a receipt and feeds the prayer lists',
      () async {
        final container = await createSignedInContainer();
        final provider = pujaViewModelProvider(false);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        await container.read(provider.future);
        final before = await container.read(prayerListsProvider.future);
        final viewModel = container.read(provider.notifier);

        await viewModel.next(); // ceremony → names
        viewModel
          ..setNameInput(PrayerGroup.living, '  Yangchen Dolma ')
          ..addName(PrayerGroup.living);
        await viewModel.next(); // names → sponsor
        await viewModel.next(); // blocked: no sponsor yet
        expect(
          container.read(provider).requireValue.sponsorIssue,
          ValidationIssue.sponsorRequired,
        );
        viewModel.setSponsor('Yangchen Dolma');
        await viewModel.next(); // sponsor → review
        await viewModel.next(); // save

        final state = container.read(provider).requireValue;
        expect(state.receipt?.amount, 108);
        expect(state.receipt?.number, startsWith('R-2026-'));

        final after = await container.read(prayerListsProvider.future);
        final names = after.expand((list) => list.living);
        expect(names, contains('Yangchen Dolma'));
        expect(names.length, before.expand((list) => list.living).length + 1);
      },
    );
  });

  group('volunteers', () {
    test('assigning fills the shift and refreshes the calendar', () async {
      final container = await createSignedInContainer();
      final month = DateTime(2026, 10);
      final shifts = await container.read(monthShiftsProvider(month).future);
      final open = shifts.firstWhere((shift) => shift.open >= 1);
      final day = open.date;

      final subscription = container.listen(
        assignBoardProvider(day),
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(volunteersProvider.future);
      final viewModel = container.read(assignViewModelProvider(day).notifier)
        ..selectShift(open.id);

      final board = container.read(assignBoardProvider(day)).requireValue;
      final away = board.choices.firstWhere(
        (choice) => choice.volunteer.name == 'Tashi Dorje',
      );
      expect(viewModel.toggle(away, open), PickOutcome.away);

      final free = board.choices.firstWhere((choice) => choice.selectable);
      expect(viewModel.toggle(free, open), PickOutcome.changed);
      await viewModel.confirm(
        container.read(assignBoardProvider(day)).requireValue,
      );

      final done = container.read(assignViewModelProvider(day)).done;
      expect(done?.names, [free.volunteer.name]);
      final refreshed = await container.read(monthShiftsProvider(month).future);
      expect(
        refreshed.firstWhere((shift) => shift.id == open.id).volunteers,
        contains(free.volunteer.name),
      );
    });

    test('weeks run Sunday to Saturday within the month', () {
      final weeks = weeksOfMonth(DateTime(2026, 10));
      expect(weeks.first.map((d) => d.day), [1, 2, 3]);
      expect(weeks[1].first.weekday, DateTime.sunday);
      expect(weeks.last.last.day, 31);
      expect(weeks.expand((week) => week), hasLength(31));
    });
  });

  group('Tibetan calendar', () {
    test('converts Western dates and finds practice days', () {
      final calendar = PhugpaTibetanCalendar();
      final day = calendar.dayOf(DateTime(2026, 9, 30));
      expect(day.month, inInclusiveRange(1, 12));
      expect(day.day, inInclusiveRange(1, 30));

      final upcoming = calendar.upcomingPracticeDays(DateTime(2026, 9, 30));
      expect(upcoming, hasLength(3));
      for (final date in upcoming) {
        expect(calendar.practiceOn(date), isNotNull);
      }
    });
  });
}
