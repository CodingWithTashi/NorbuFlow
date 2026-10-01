import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/core/error/validation_issue.dart';
import 'package:norbu_flow/features/members/domain/member.dart';
import 'package:norbu_flow/features/members/presentation/view_models/add_member_view_model.dart';
import 'package:norbu_flow/features/members/presentation/view_models/members_view_model.dart';

import '../support/test_app.dart';

Member _member({DateTime? expiresOn}) => Member(
  id: 'm',
  nameEn: 'Tenzin Dolkar',
  nameBo: 'བསྟན་འཛིན་སྒྲོལ་དཀར།',
  number: 142,
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
      expect(created!.number, 204);
      expect(created.expiresOn, isNull, reason: 'life members never expire');
      expect(container.read(membersProvider).requireValue.first.id, created.id);
    });
  });
}
