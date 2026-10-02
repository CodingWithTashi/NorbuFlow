import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/app/router/app_router.dart';
import 'package:norbu_flow/app/router/app_routes.dart';
import 'package:norbu_flow/core/error/app_failure.dart';
import 'package:norbu_flow/core/error/validation_issue.dart';
import 'package:norbu_flow/core/feedback/app_messenger.dart';
import 'package:norbu_flow/core/models/photo_source.dart';
import 'package:norbu_flow/core/services/file_cache.dart';
import 'package:norbu_flow/features/members/data/fake_member_repository.dart';
import 'package:norbu_flow/features/members/data/member_repositories.dart';
import 'package:norbu_flow/features/members/domain/card.dart';
import 'package:norbu_flow/features/members/domain/member.dart';
import 'package:norbu_flow/features/members/presentation/view_models/add_member_view_model.dart';
import 'package:norbu_flow/features/members/presentation/view_models/members_view_model.dart';

import '../support/cards.dart';
import '../support/test_app.dart';

Member _member({DateTime? expiresOn}) => Member(
  id: 'm',
  nameEn: 'Tenzin Dolkar',
  nameBo: 'བསྟན་འཛིན་སྒྲོལ་དཀར།',
  number: 'JC-0142',
  phone: '416 555 0142',
  type: MembershipType.family,
  expiresOn: expiresOn,
);

void main() {
  group('Member', () {
    final today = DateTime(2026, 9, 30);

    test('status follows the expiry date', () {
      expect(_member().statusOn(today), MembershipStatus.active);
      expect(
        _member(expiresOn: DateTime(2027, 3, 14)).statusOn(today),
        MembershipStatus.active,
      );
      expect(
        _member(expiresOn: DateTime(2026, 11, 14)).statusOn(today),
        MembershipStatus.expiring,
      );
      expect(
        _member(expiresOn: today).statusOn(today),
        MembershipStatus.expiring,
      );
      expect(
        _member(expiresOn: DateTime(2026, 9, 29)).statusOn(today),
        MembershipStatus.expired,
      );
    });

    test('search matches English name, Tibetan name and phone digits', () {
      final member = _member();
      expect(member.matches(''), isTrue);
      expect(member.matches('dolk'), isTrue);
      expect(member.matches('སྒྲོལ'), isTrue);
      expect(member.matches('555-0142'), isTrue);
      expect(member.matches('sonam'), isFalse);
    });
  });

  group('MembersViewModel', () {
    test('loads the current temple and reloads on a temple switch', () async {
      final container = await createSignedInContainer();
      final jangchub = await container.read(membersProvider.future);
      expect(jangchub, hasLength(8));

      await signIn(container, templeId: 'dl');
      final drolma = await container.read(membersProvider.future);
      expect(drolma, hasLength(5));
    });

    test('takes in a member saved elsewhere: the newest first, or in place '
        'of who they were', () async {
      final container = await createSignedInContainer();
      await container.read(membersProvider.future);
      final members = container.read(membersProvider.notifier);
      const yangchen = Member(
        id: 'new',
        nameEn: 'Yangchen Dolma',
        nameBo: '',
        number: 'JC-0204',
      );

      members.put(yangchen);
      expect(container.read(membersProvider).requireValue, hasLength(9));
      expect(container.read(membersProvider).requireValue.first, yangchen);

      const renamed = Member(
        id: 'm2',
        nameEn: 'Sonam W. Dorjee',
        nameBo: '',
        number: 'JC-0087',
      );
      members.put(renamed);
      final list = container.read(membersProvider).requireValue;
      expect(list, hasLength(9));
      expect(list[2], renamed);
    });

    test('a member saved before the list has loaded is in it when it '
        'does', () async {
      final container = await createSignedInContainer();
      final members = container.read(membersProvider.notifier);

      members.put(
        const Member(
          id: 'm2',
          nameEn: 'Sonam W.',
          nameBo: '',
          number: 'JC-0087',
        ),
      );

      // Nothing to put them in yet: the list is simply fetched.
      expect(await container.read(membersProvider.future), hasLength(8));
    });

    test('fetched again, shows what another desk changed and forgets the '
        'cards nobody holds now', () async {
      final kept = MemoryFileCache();
      final container = await createSignedInContainer(
        overrides: [fileCacheProvider.overrideWithValue(kept)],
      );
      final first = await container.read(membersProvider.future);
      final members = container.read(membersProvider.notifier);
      // Sonam holds a card this device has kept.
      members.put(
        Member(
          id: first[1].id,
          nameEn: first[1].nameEn,
          nameBo: first[1].nameBo,
          number: first[1].number,
          cardId: 'card-old',
        ),
      );
      for (final file in CardFiles.all('card-old')) {
        await kept.write(file, Uint8List(1));
      }

      await members.refresh();
      await container.pump();

      // The repository knows nothing of that card: it was replaced elsewhere.
      expect(container.read(membersProvider).requireValue, first);
      expect(kept.files, isEmpty);
    });

    test('fetched again without success, keeps what is shown and says '
        'why', () async {
      final repository = _FailingOnDemand();
      final container = await createSignedInContainer(
        overrides: [memberRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.read(appMessengerProvider.notifier).dismiss);
      final shown = await container.read(membersProvider.future);
      repository.failure = const NetworkFailure();

      await container.read(membersProvider.notifier).refresh();

      expect(container.read(membersProvider).requireValue, same(shown));
      expect(
        container.read(appMessengerProvider)?.failure,
        isA<NetworkFailure>(),
      );
    });

    test('numbers carry on from the highest, written the same way', () {
      expect(
        Member.numberAfter(['JC-0142', 'JC-0203', 'JC-0087'], whenNone: '1'),
        'JC-0204',
      );
      expect(Member.numberAfter(['9', '10'], whenNone: '1'), '11');
      expect(Member.numberAfter(const [], whenNone: 'DL-0001'), 'DL-0001');
      expect(Member.rewritten('JC-0204', '7'), 'JC-0007');
      expect(Member.rewritten('JC-0204', '12345'), 'JC-12345');
      expect(Member.digitsOf('JC-0142'), '142');
    });

    test('renewing extends an expired membership a year from today', () async {
      final container = await createSignedInContainer();
      final members = await container.read(membersProvider.future);
      final expired = members.firstWhere(
        (m) => m.statusOn(testNow) == MembershipStatus.expired,
      );

      final result = await container
          .read(membersProvider.notifier)
          .renew(expired.id);

      expect(result.valueOrNull?.expiresOn, DateTime(2027, 9, 30));
      // The shared list is the source of truth for every screen.
      final updated = container
          .read(membersProvider)
          .requireValue
          .firstWhere((m) => m.id == expired.id);
      expect(updated.statusOn(testNow), MembershipStatus.active);
      expect(container.read(membershipDueProvider).expired, 0);
    });
  });

  group('the member list', () {
    setUpAll(loadAppFonts);

    testWidgets('shows a member\'s photo, asked for under a name that does '
        'not change, and their initials until it arrives', (tester) async {
      tester.setScreenSize(const Size(390, 844));
      final container = createContainer();
      await tester.pumpApp(container);
      await tester.runAsync(() => signIn(container));
      await tester.runAsync(() => container.read(membersProvider.future));
      container
          .read(membersProvider.notifier)
          .put(
            const Member(
              id: 'with-photo',
              nameEn: 'Aaron Zangpo',
              nameBo: '',
              number: 'JC-0001',
              photo: NetworkPhoto(
                'https://files.example/photo.jpg?signature=today',
                cacheKey: 'temples/t/members/with-photo/cards/c.jpg',
              ),
            ),
          );
      container.read(routerProvider).go(AppRoutes.members);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final row = find.ancestor(
        of: find.text('Aaron Zangpo'),
        matching: find.byType(Row),
      );
      final photo = tester.widget<CachedNetworkImage>(
        find.descendant(of: row, matching: find.byType(CachedNetworkImage)),
      );
      // The signed link is new each day; the photo it leads to is not.
      expect(photo.cacheKey, 'temples/t/members/with-photo/cards/c.jpg');
      expect(photo.imageUrl, 'https://files.example/photo.jpg?signature=today');
      // Decoded at the size of the circle, not of the photo.
      expect(photo.memCacheWidth, 168);
      expect(
        find.descendant(of: row, matching: find.text('AZ')),
        findsOneWidget,
      );
    });
  });

  group('AddMemberViewModel', () {
    test('will not leave the details step with invalid input', () async {
      final container = await createSignedInContainer();
      final subscription = container.listen(
        addMemberViewModelProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final viewModel = container.read(addMemberViewModelProvider.notifier);

      await viewModel.next(); // photo → details
      viewModel
        ..setPhone('416 555')
        ..setEmail('yangchen@');
      await viewModel.next();

      final state = container.read(addMemberViewModelProvider);
      expect(state.step, AddMemberStep.details);
      expect(state.issues, {
        AddMemberField.nameEn: ValidationIssue.memberNameRequired,
        AddMemberField.phone: ValidationIssue.phoneTooShort,
        AddMemberField.email: ValidationIssue.emailIncomplete,
      });

      // Editing a field clears only that field's message.
      viewModel.setNameEn('Yangchen Dolma');
      expect(
        container.read(addMemberViewModelProvider).issues.keys,
        isNot(contains(AddMemberField.nameEn)),
      );
    });

    test('saving creates the member with the next number', () async {
      final container = await createSignedInContainer();
      await container.read(membersProvider.future);
      final subscription = container.listen(
        addMemberViewModelProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final viewModel = container.read(addMemberViewModelProvider.notifier);

      await viewModel.next();
      viewModel
        ..setNameEn('Yangchen Dolma')
        ..setPhone('416 555 0216')
        ..setType(MembershipType.life);
      await viewModel.next(); // details → type
      await viewModel.next(); // type → payment
      await viewModel.next(); // save

      final created = container.read(addMemberViewModelProvider).created;
      expect(created, isNotNull);
      expect(created!.number, 'JC-0204');
      expect(created.expiresOn, isNull, reason: 'life members never expire');
      expect(container.read(membersProvider).requireValue.first.id, created.id);
    });
  });
}

/// The demo's member list, which can be told to fail the next fetch.
class _FailingOnDemand implements MemberRepository {
  final _demo = FakeMemberRepository(Duration.zero, () => testNow);

  AppFailure? failure;

  @override
  Future<List<Member>> fetchMembers(String templeId) async {
    if (failure case final failure?) throw failure;
    return _demo.fetchMembers(templeId);
  }

  @override
  Future<Member> addMember(String templeId, NewMember newMember) =>
      _demo.addMember(templeId, newMember);

  @override
  Future<Member> renew(String templeId, String memberId) =>
      _demo.renew(templeId, memberId);

  @override
  Future<CheckIn> checkIn(String templeId, String memberId) =>
      _demo.checkIn(templeId, memberId);
}
