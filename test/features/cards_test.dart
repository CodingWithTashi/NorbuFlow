import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/app/router/app_router.dart';
import 'package:norbu_flow/app/router/app_routes.dart';
import 'package:norbu_flow/core/config/app_config.dart';
import 'package:norbu_flow/core/error/app_failure.dart';
import 'package:norbu_flow/core/error/validation_issue.dart';
import 'package:norbu_flow/core/feedback/app_messenger.dart';
import 'package:norbu_flow/core/models/phone_country.dart';
import 'package:norbu_flow/core/models/photo_source.dart';
import 'package:norbu_flow/core/services/contact_launcher.dart';
import 'package:norbu_flow/core/services/device_country.dart';
import 'package:norbu_flow/core/services/document_printer.dart';
import 'package:norbu_flow/core/services/file_cache.dart';
import 'package:norbu_flow/core/services/photo_picker.dart';
import 'package:norbu_flow/core/utils/ids.dart';
import 'package:norbu_flow/features/members/data/fake_card_repository.dart';
import 'package:norbu_flow/features/members/data/fake_member_repository.dart';
import 'package:norbu_flow/features/members/data/firebase_card_repository.dart';
import 'package:norbu_flow/features/members/data/firebase_member_repository.dart';
import 'package:norbu_flow/features/members/data/member_repositories.dart';
import 'package:norbu_flow/features/members/domain/card.dart';
import 'package:norbu_flow/features/members/domain/member.dart';
import 'package:norbu_flow/features/members/presentation/view_models/card_form_view_model.dart';
import 'package:norbu_flow/features/members/presentation/view_models/member_card_view_model.dart';
import 'package:norbu_flow/features/members/presentation/view_models/members_view_model.dart';
import 'package:norbu_flow/features/members/presentation/views/card_form_screen.dart';
import 'package:norbu_flow/features/members/presentation/views/member_detail_view.dart';
import 'package:norbu_flow/features/members/presentation/widgets/card_pages.dart';
import 'package:norbu_flow/features/members/presentation/widgets/photo_cropper.dart';
import 'package:norbu_flow/features/temple/data/fake_temple_repository.dart';

import '../support/cards.dart';
import '../support/fake_backend.dart';
import '../support/test_app.dart';

const _temple = FakeTemples.jangchubId;
final _photo = Uint8List.fromList([1, 2, 3, 4]);
final _picked = Uint8List.fromList([9, 9, 9]);

/// The members screens as they are with the backend on, but on the fakes.
const _liveMembers = AppConfig(demoMembers: false, fakeLatency: Duration.zero);

void main() {
  group('a new ID card', () {
    late RecordingPrinter printer;
    late _DrivenCards cards;
    late ProviderContainer container;
    final form = cardFormViewModelProvider(null);
    // Stands in for the screen: while it watches, the form is kept.
    late ProviderSubscription<CardFormState> watching;

    CardFormState state() => container.read(form);
    CardFormViewModel card() => container.read(form.notifier);
    AppFailure? shownFailure() => container.read(appMessengerProvider)?.failure;
    List<Member> list() => container.read(membersProvider).requireValue;

    /// Fills in everything a card can take.
    void fillIn() => card()
      ..setName('Tenzin Dolma')
      ..setPhone('416 555 0142')
      ..setEmail('tenzin.dolma@example.org')
      ..useCroppedPhoto(_photo);

    /// Fills in the form and draws the card for checking.
    Future<void> toPreview() async {
      fillIn();
      await card().previewCard();
    }

    /// Types [digits] into "Edit ID number" and uses them.
    Future<bool> useNumber(String digits) {
      card()
        ..editNumber()
        ..setNumberInput(digits);
      return card().applyNumber();
    }

    setUp(() async {
      printer = RecordingPrinter();
      var made = 0;
      container = await createSignedInContainer(
        overrides: [
          documentPrinterProvider.overrideWithValue(printer),
          cardRepositoryProvider.overrideWith(
            (ref) => cards = _DrivenCards.on(ref),
          ),
          photoPickerProvider.overrideWithValue(OnePhoto(_picked)),
          newIdProvider.overrideWithValue(() => 'card-${++made}'),
        ],
      );
      container.read(cardRepositoryProvider);
      await container.read(membersProvider.future);
      watching = container.listen(form, (_, _) {});
      addTearDown(watching.close);
      addTearDown(container.read(appMessengerProvider.notifier).dismiss);
    });

    group('the details', () {
      test('need a photo and a name, and nothing is drawn until they are '
          'there', () async {
        await card().previewCard();

        expect(state().issues, {
          CardField.photo: ValidationIssue.photoRequired,
          CardField.name: ValidationIssue.memberNameRequired,
        });
        expect(cards.previewed, isEmpty);

        // Fixing a field clears only that field's message.
        card().setName('Tenzin Dolma');
        expect(state().issues.keys, [CardField.photo]);
        card().useCroppedPhoto(_photo);
        expect(state().issues, isEmpty);
      });

      test('phone and email may be left out', () async {
        card()
          ..setName('Tenzin Dolma')
          ..useCroppedPhoto(_photo);

        await card().previewCard();

        expect(state().issues, isEmpty);
        expect(cards.previewed.single.phone, isEmpty);
        expect(cards.previewed.single.email, isEmpty);
      });

      test('but neither may be left half typed', () async {
        fillIn();
        card()
          ..setPhone('416 555')
          ..setEmail('tenzin@');

        await card().previewCard();

        expect(state().issues, {
          CardField.phone: ValidationIssue.phoneTooShort,
          CardField.email: ValidationIssue.emailIncomplete,
        });
        expect(cards.previewed, isEmpty);

        card().setPhone('416 555 0142 0142');
        await card().previewCard();
        expect(state().issues[CardField.phone], ValidationIssue.phoneTooLong);
      });

      test('are sent tidied, the phone with its country\'s code', () async {
        card()
          ..setName('  Tenzin Dolma ')
          ..setPhone(' 416 555 0142 ')
          ..setEmail(' Tenzin.Dolma@example.org')
          ..useCroppedPhoto(_photo);

        await card().previewCard();

        final sent = cards.previewed.single;
        expect(sent.id, 'card-1');
        expect(sent.memberId, isNull);
        expect(sent.name, 'Tenzin Dolma');
        expect(sent.phone, '+1 416 555 0142');
        expect(sent.email, 'Tenzin.Dolma@example.org');
        expect(sent.photo, _photo);
        expect(sent.number, isNull);
      });

      test('take the phone\'s code from the country chosen, and check the '
          'number against that country', () async {
        fillIn();
        card().setCountry(PhoneCountry.france);
        expect(state().country, PhoneCountry.france);

        // Ten digits is one too many in France, unless the first is its 0.
        await card().previewCard();
        expect(state().issues[CardField.phone], ValidationIssue.phoneTooLong);

        card().setPhone('06 12 34 56 78');
        await card().previewCard();
        expect(cards.previewed.single.phone, '+33 6 12 34 56 78');
      });

      test('start from the country the device is in', () async {
        final abroad = await createSignedInContainer(
          overrides: [
            homePhoneCountryProvider.overrideWithValue(PhoneCountry.india),
          ],
        );
        final subscription = abroad.listen(form, (_, _) {});
        addTearDown(subscription.close);

        expect(abroad.read(form).country, PhoneCountry.india);
      });

      test('a photo is picked, cropped, and can be cropped again', () async {
        card().reopenCrop();
        expect(state().photo.cropping, isFalse);

        await card().pickPhoto(PhotoOrigin.gallery);
        expect(state().photo.cropping, isTrue);
        expect(state().photo.original, _picked);

        card().cancelCrop();
        expect(state().photo.cropping, isFalse);
        expect(state().photo.cropped, isNull);

        card().reopenCrop();
        card().useCroppedPhoto(_photo);
        expect(state().photo.cropping, isFalse);
        expect(state().photo.cropped?.bytes, _photo);
        expect(state().photo.original, _picked);
      });

      test('only a cropped photo answers the request for one', () async {
        await card().previewCard();

        await card().pickPhoto(PhotoOrigin.gallery);
        card().cancelCrop();
        expect(state().issues, contains(CardField.photo));

        card().useCroppedPhoto(_photo);
        expect(state().issues, isNot(contains(CardField.photo)));
      });
    });

    group('the preview', () {
      test('shows the card with the number the member would get, and saves '
          'nothing', () async {
        await toPreview();

        expect(state().preview?.label, 'JC-0204');
        expect(state().preview?.number, '204');
        expect(state().busy, isFalse);
        expect(state().issued, isNull);
        expect(cards.issued, isEmpty);
        expect(list(), hasLength(8));
      });

      test('is the card\'s own pages', () async {
        expect(
          await container.read(cardFormPagesProvider(null).future),
          isEmpty,
        );
        await toPreview();

        final pages = await container.read(cardFormPagesProvider(null).future);

        expect([for (final page in pages) page.bytes], [frontPage, backPage]);
        expect(printer.drawn, [state().preview!.pdf]);
      });

      test('a second tap while the card is being drawn asks once', () async {
        cards.holding = Completer<void>();
        fillIn();

        final first = card().previewCard();
        await card().previewCard();
        cards.holding!.complete();
        await first;

        expect(cards.previewed, hasLength(1));
      });

      test(
        'can be left to change the details, which are still there',
        () async {
          await toPreview();

          card().backToDetails();

          expect(state().preview, isNull);
          expect(state().name, 'Tenzin Dolma');
          expect(state().photo.cropped?.bytes, _photo);
        },
      );

      test('what the backend refuses about a detail is flagged on its field, '
          'back on the form', () async {
        await toPreview();
        card().backToDetails();
        cards.failWith = const ValidationFailure({
          'name': ValidationIssue.memberNameUnsupported,
          'phone': ValidationIssue.phoneTooShort,
        });

        await card().previewCard();

        expect(state().issues, {
          CardField.name: ValidationIssue.memberNameUnsupported,
          CardField.phone: ValidationIssue.phoneTooShort,
        });
        expect(state().preview, isNull);
        expect(shownFailure(), isNull);
      });

      test(
        'any other failure is shown as a toast, and can be retried',
        () async {
          cards.failWith = const PermissionFailure(
            reason: PermissionReason.notOnTeam,
          );
          await toPreview();

          expect(shownFailure(), isA<PermissionFailure>());
          expect(state().issues, isEmpty);
          expect(state().busy, isFalse);
          expect(state().name, 'Tenzin Dolma');

          cards.failWith = null;
          await card().previewCard();
          expect(state().preview, isNotNull);
        },
      );

      test('cannot be left while a card is being drawn or made', () async {
        await toPreview();
        cards.holding = Completer<void>();
        final saving = card().save();

        card().backToDetails();
        expect(state().preview, isNotNull);

        cards.holding!.complete();
        await saving;
        expect(state().issued, isNotNull);
      });
    });

    group('the ID number', () {
      test('is edited from the one on the preview', () async {
        await toPreview();

        card().editNumber();

        expect(state().numberInput, '204');
      });

      test('typed by hand is put on the card, which is drawn again', () async {
        await toPreview();

        // Zeros typed in front do not count.
        expect(await useNumber('0300'), isTrue);

        expect(state().number, '300');
        expect(cards.previewed.last.number, '300');
        expect(state().preview?.label, 'JC-0300');
        expect(state().numberInput, '300');
      });

      test('left as the card already has it, is not taken as typed by '
          'hand', () async {
        await toPreview();

        expect(await useNumber(state().preview!.number), isTrue);

        // Still the temple's to give: the next free one when the card is made.
        expect(state().number, isNull);
        expect(cards.previewed, hasLength(1));
      });

      test('must be digits above zero', () async {
        await toPreview();

        for (final typed in ['', 'JC-0300', '0', '12.5', '1' * 16]) {
          expect(await useNumber(typed), isFalse, reason: typed);
          expect(
            state().issues[CardField.number],
            ValidationIssue.memberNumberInvalid,
          );
        }
        expect(cards.previewed, hasLength(1));
        expect(state().preview?.label, 'JC-0204');

        // Typing again clears the message.
        card().setNumberInput('300');
        expect(state().issues, isEmpty);
      });

      test('is not kept if the card could not be drawn with it', () async {
        await toPreview();
        cards.failWith = const NetworkFailure();

        expect(await useNumber('300'), isFalse);

        expect(state().number, isNull);
        expect(state().preview?.label, 'JC-0204');
        expect(shownFailure(), isA<NetworkFailure>());
      });

      test('refused by the backend is flagged where it was typed, and the '
          'preview stays', () async {
        await toPreview();
        cards.failWith = const ValidationFailure({
          'number': ValidationIssue.memberNumberInvalid,
        });

        expect(await useNumber('300'), isFalse);

        expect(
          state().issues[CardField.number],
          ValidationIssue.memberNumberInvalid,
        );
        expect(state().preview, isNotNull);
        expect(shownFailure(), isNull);
      });
    });

    group('creating it', () {
      test('makes the card that was previewed, and the member is on the '
          'list at once', () async {
        await toPreview();

        await card().save();

        final issued = state().issued!;
        expect(issued.member.nameEn, 'Tenzin Dolma');
        expect(issued.member.number, 'JC-0204');
        expect(issued.member.phone, '+1 416 555 0142');
        expect(state().busy, isFalse);
        expect(list(), hasLength(9));
        expect(list().first, same(issued.member));
      });

      test('sends what was previewed, whatever was typed while the card '
          'was being drawn', () async {
        fillIn();
        cards.holding = Completer<void>();
        final drawing = card().previewCard();
        card().setName('Tenzin Dolkar Sherpa');
        cards.holding!.complete();
        await drawing;

        await card().save();

        expect(cards.issued.single.request, same(cards.previewed.single));
        expect(state().issued?.member.nameEn, 'Tenzin Dolma');
      });

      test('reaches the list even if the form is left before the answer '
          'comes', () async {
        await toPreview();
        cards.holding = Completer<void>();
        final saving = card().save();

        // The screen is closed, and the form with it.
        watching.close();
        await container.pump();
        cards.holding!.complete();
        await saving;

        expect(list(), hasLength(9));
        expect(list().first.nameEn, 'Tenzin Dolma');
      });

      test('a number the backend refuses when the card is made is said in a '
          'toast, since its field is not on screen', () async {
        await toPreview();
        cards.failWith = const ValidationFailure({
          'number': ValidationIssue.memberNumberInvalid,
        });

        await card().save();

        expect(shownFailure(), isA<ValidationFailure>());
        expect(state().preview, isNotNull);
        expect(state().busy, isFalse);
      });

      test('does nothing before there is a preview', () async {
        fillIn();

        await card().save();

        expect(cards.issued, isEmpty);
        expect(state().issued, isNull);
      });

      test('carries the number that was typed', () async {
        await toPreview();
        await useNumber('300');

        await card().save();

        expect(cards.issued.single.number, '300');
        expect(state().issued?.member.number, 'JC-0300');
      });

      test('a second tap while the card is being made asks for one', () async {
        await toPreview();
        cards.holding = Completer<void>();

        final first = card().save();
        await card().save();
        cards.holding!.complete();
        await first;

        expect(cards.issued, hasLength(1));
      });

      test('trying again after a failure asks for the same card, so the '
          'member is not added twice; the next person is a new card', () async {
        await toPreview();
        cards.failWith = const NetworkFailure();
        await card().save();
        expect(shownFailure(), isA<NetworkFailure>());
        cards.failWith = null;
        await card().save();

        card().startAnother();
        await toPreview();
        await card().save();

        expect(cards.issued.map((request) => request.id), [
          'card-1',
          'card-1',
          'card-2',
        ]);
        expect(list(), hasLength(10));
      });

      test('shows the issued card\'s own pages, front then back', () async {
        await toPreview();
        await card().save();

        final pages = await container.read(cardFormPagesProvider(null).future);

        expect([for (final page in pages) page.bytes], [frontPage, backPage]);
        expect(printer.drawn.last, state().issued!.pdf);
      });

      test('a device that cannot draw the card still issues it', () async {
        printer.pagesFailure = const UnavailableFailure();
        await toPreview();

        await card().save();

        expect(state().issued, isNotNull);
        await expectLater(
          container.read(cardFormPagesProvider(null).future),
          throwsA(isA<UnavailableFailure>()),
        );
      });

      test('prints and shares the card that was issued', () async {
        await toPreview();
        await card().save();
        final pdf = state().issued!.pdf;

        await card().printCard('ID card JC-0204');
        await card().shareCard('ID card JC-0204');

        expect(printer.printed, {'ID card JC-0204': pdf});
        expect(printer.shared, {'ID card JC-0204.pdf': pdf});
      });

      test('there is nothing to print before a card exists', () async {
        await card().printCard('ID card');
        expect(printer.printed, isEmpty);
      });

      test('starting another card clears the form', () async {
        await toPreview();
        await useNumber('300');
        await card().save();

        card().startAnother();

        expect(state().issued, isNull);
        expect(state().preview, isNull);
        expect(state().number, isNull);
        expect(state().name, isEmpty);
        expect(state().phone, isEmpty);
        expect(state().email, isEmpty);
        expect(state().photo.cropped, isNull);
      });
    });

    group('a number someone already holds', () {
      setUp(() async {
        await toPreview();
        // Tenzin Dolkar is JC-0142.
        await useNumber('142');
      });

      test('saves nothing, and says whose it is', () async {
        await card().save();

        expect(state().taken?.name, 'Tenzin Dolkar');
        expect(state().taken?.number, 'JC-0142');
        expect(state().issued, isNull);
        expect(state().busy, isFalse);
        expect(cards.issued.single.replace, isFalse);
        expect(list(), hasLength(8));
        expect(shownFailure(), isNull);
      });

      test('can be let go, to choose another number', () async {
        await card().save();

        card().dismissTaken();
        expect(state().taken, isNull);
        expect(state().preview, isNotNull);

        await useNumber('300');
        await card().save();
        expect(state().issued?.member.number, 'JC-0300');
        expect(list(), hasLength(9));
      });

      test('is given to the new person when replacing: their record, with '
          'the new details', () async {
        await card().save();

        await card().save(replace: true);

        final member = state().issued!.member;
        expect(state().taken, isNull);
        expect(member.id, 'm1');
        expect(member.number, 'JC-0142');
        expect(member.nameEn, 'Tenzin Dolma');
        expect(cards.issued.last.replace, isTrue);
        // Replaced where they were, not added.
        expect(list(), hasLength(8));
        expect(list().first, same(member));
      });
    });
  });

  group('editing a member', () {
    late _DrivenCards cards;
    late ProviderContainer container;
    // Tenzin Dolkar, JC-0142, 416 555 0142, no email.
    final form = cardFormViewModelProvider('m1');

    CardFormState state() => container.read(form);
    CardFormViewModel card() => container.read(form.notifier);
    List<Member> list() => container.read(membersProvider).requireValue;

    setUp(() async {
      var made = 0;
      container = await createSignedInContainer(
        overrides: [
          documentPrinterProvider.overrideWithValue(RecordingPrinter()),
          cardRepositoryProvider.overrideWith(
            (ref) => cards = _DrivenCards.on(ref),
          ),
          newIdProvider.overrideWithValue(() => 'change-${++made}'),
        ],
      );
      container.read(cardRepositoryProvider);
      await container.read(membersProvider.future);
      final subscription = container.listen(form, (_, _) {});
      addTearDown(subscription.close);
      addTearDown(container.read(appMessengerProvider.notifier).dismiss);
    });

    test('shows the photo they have, and sends none unless a new one is '
        'chosen', () async {
      final photo = MemoryPhoto(_picked);
      container
          .read(membersProvider.notifier)
          .put(
            Member(
              id: 'with-photo',
              nameEn: 'Yeshi Lhamo',
              nameBo: '',
              number: 'JC-0901',
              photo: photo,
            ),
          );
      final yeshi = cardFormViewModelProvider('with-photo');
      final subscription = container.listen(yeshi, (_, _) {});
      addTearDown(subscription.close);

      expect(container.read(yeshi).photoOnFile, same(photo));
      expect(container.read(yeshi).photo.cropped, isNull);
      await container.read(yeshi.notifier).previewCard();
      expect(cards.previewed.single.photo, isNull);

      // A new photo, once cropped, is what is sent.
      container.read(yeshi.notifier)
        ..backToDetails()
        ..useCroppedPhoto(_photo);
      await container.read(yeshi.notifier).previewCard();
      expect(cards.previewed.last.photo, _photo);
      expect(container.read(yeshi).photoOnFile, same(photo));
    });

    test('starts from the member as they are', () {
      expect(state().editing, isTrue);
      expect(state().name, 'Tenzin Dolkar');
      expect(state().country, PhoneCountry.canada);
      expect(state().phone, '416 555 0142');
      expect(state().email, isEmpty);
      expect(state().photo.cropped, isNull);
    });

    test('takes a number saved with its code apart again', () async {
      container
          .read(membersProvider.notifier)
          .put(
            Member(
              id: 'abroad',
              nameEn: 'Sonam Gurung',
              nameBo: '',
              number: 'JC-0900',
              phone: '+977 98 4123 4567',
            ),
          );
      final abroad = cardFormViewModelProvider('abroad');
      final subscription = container.listen(abroad, (_, _) {});
      addTearDown(subscription.close);

      expect(container.read(abroad).country, PhoneCountry.nepal);
      expect(container.read(abroad).phone, '98 4123 4567');
    });

    test(
      'needs no new photo, and keeps their number unless one is typed',
      () async {
        card().setName('Tenzin D. Sherpa');

        await card().previewCard();

        final sent = cards.previewed.single;
        expect(sent.memberId, 'm1');
        expect(sent.photo, isNull);
        expect(sent.number, isNull);
        expect(state().preview?.label, 'JC-0142');
      },
    );

    test('saving changes them where they are on the list', () async {
      card()
        ..setName('Tenzin D. Sherpa')
        ..setEmail('tenzin@example.org');
      await card().previewCard();

      await card().save();

      final member = state().issued!.member;
      expect(member.id, 'm1');
      expect(member.nameEn, 'Tenzin D. Sherpa');
      expect(member.email, 'tenzin@example.org');
      expect(member.phone, '+1 416 555 0142');
      expect(list(), hasLength(8));
      expect(list().firstWhere((m) => m.id == 'm1'), same(member));
      // Saving did not reset the form to the member's new details.
      expect(state().issued, isNotNull);
    });

    test('a number that is someone else\'s is never taken from them', () async {
      await card().previewCard();
      card()
        ..editNumber()
        ..setNumberInput('87');
      await card().applyNumber();

      await card().save();
      expect(state().taken?.name, 'Sonam Wangchuk');

      // Even asked to replace, an edit changes only its own member.
      await card().save(replace: true);
      expect(cards.issued.last.replace, isFalse);
      expect(state().taken?.name, 'Sonam Wangchuk');
      expect(state().issued, isNull);
    });
  });

  group('a member\'s card on file', () {
    late RecordingPrinter printer;
    late RecordingLauncher launcher;
    late ProviderContainer container;

    MemberActions actions() => container.read(memberActionsProvider);
    Member member(String id) => container
        .read(membersProvider)
        .requireValue
        .firstWhere((member) => member.id == id);

    setUp(() async {
      printer = RecordingPrinter();
      launcher = RecordingLauncher();
      container = await createSignedInContainer(
        overrides: [
          documentPrinterProvider.overrideWithValue(printer),
          contactLauncherProvider.overrideWithValue(launcher),
        ],
      );
      await container.read(membersProvider.future);
      final pages = container.listen(memberCardProvider('m1'), (_, _) {});
      final commands = container.listen(memberActionsProvider, (_, _) {});
      addTearDown(pages.close);
      addTearDown(commands.close);
      addTearDown(container.read(appMessengerProvider.notifier).dismiss);
    });

    test(
      'is shown as its own pages, and printed and shared as it is',
      () async {
        final (:card, :pages) = await container.read(
          memberCardProvider('m1').future,
        );

        await actions().printCard('m1', 'ID card JC-0142');
        await actions().shareCard('m1', 'ID card JC-0142');

        expect([for (final page in pages) page.bytes], [frontPage, backPage]);
        expect(card.member.number, 'JC-0142');
        expect(printer.printed, {'ID card JC-0142': card.pdf});
        expect(printer.shared, {'ID card JC-0142.pdf': card.pdf});
      },
    );

    test('is fetched again when the member is changed', () async {
      final (card: before, pages: _) = await container.read(
        memberCardProvider('m1').future,
      );
      final form = cardFormViewModelProvider('m1');
      final subscription = container.listen(form, (_, _) {});
      addTearDown(subscription.close);
      container.read(form.notifier).setName('Tenzin D. Sherpa');
      await container.read(form.notifier).previewCard();
      await container.read(form.notifier).save();

      final (card: after, pages: _) = await container.read(
        memberCardProvider('m1').future,
      );

      expect(after.member.nameEn, 'Tenzin D. Sherpa');
      expect(after.pdf, isNot(before.pdf));
    });

    test('email opens a message to their address', () async {
      container
          .read(membersProvider.notifier)
          .put(
            Member(
              id: 'm1',
              nameEn: 'Tenzin Dolkar',
              nameBo: '',
              number: 'JC-0142',
              email: 'tenzin@example.org',
            ),
          );

      await actions().email(member('m1'));

      expect(launcher.emailed, ['tenzin@example.org']);
    });

    test(
      'WhatsApp opens a chat with their number, country code first',
      () async {
        container
            .read(membersProvider.notifier)
            .put(
              Member(
                id: 'abroad',
                nameEn: 'Sonam Gurung',
                nameBo: '',
                number: 'JC-0900',
                phone: '+977 98-4123 4567',
              ),
            );

        await actions().whatsApp(member('abroad'));
        // Saved before numbers carried a code: taken to be from here.
        await actions().whatsApp(member('m1'));

        expect(launcher.messaged, ['9779841234567', '14165550142']);
      },
    );

    test('says so when no app on the device can be opened', () async {
      launcher.failWith = const UnavailableFailure();

      await actions().whatsApp(member('m1'));

      expect(
        container.read(appMessengerProvider)?.failure,
        isA<UnavailableFailure>(),
      );
    });
  });

  group('a card kept on the device', () {
    const pema = Member(
      id: 'pema',
      nameEn: 'Pema Dolkar',
      nameBo: '',
      number: 'JC-0900',
      cardId: 'card-1',
    );
    late RecordingPrinter printer;
    late MemoryFileCache kept;
    late _CountingCards cards;
    late ProviderContainer container;

    /// Opens Pema's screen and waits for her card, as a visit to it does.
    Future<CardOnFile> open() async {
      final subscription = container.listen(
        memberCardProvider('pema'),
        (_, _) {},
      );
      final card = await container.read(memberCardProvider('pema').future);
      subscription.close();
      // Left, the screen lets go of what it had loaded.
      await container.pump();
      return card;
    }

    setUp(() async {
      printer = RecordingPrinter();
      kept = MemoryFileCache();
      cards = _CountingCards();
      container = await createSignedInContainer(
        overrides: [
          documentPrinterProvider.overrideWithValue(printer),
          fileCacheProvider.overrideWithValue(kept),
          cardRepositoryProvider.overrideWithValue(cards),
        ],
      );
      await container.read(membersProvider.future);
      container.read(membersProvider.notifier).put(pema);
    });

    test('is drawn once: the next visit shows the pictures that were '
        'kept', () async {
      final first = await open();
      expect(printer.drawn, hasLength(1));
      expect(kept.files.keys, ['cards/card-1-1.png', 'cards/card-1-2.png']);

      final again = await open();

      expect(printer.drawn, hasLength(1));
      expect(
        [for (final page in again.pages) page.bytes],
        [for (final page in first.pages) page.bytes],
      );
    });

    test('is drawn again if only one of its sides was kept', () async {
      await open();
      await kept.remove('cards/card-1-2.png');

      final again = await open();

      expect(printer.drawn, hasLength(2));
      expect(again.pages, hasLength(2));
      expect(kept.files.keys, contains('cards/card-1-2.png'));
    });

    test('is dropped when the member is given another card, which is then '
        'the one shown', () async {
      await open();
      await kept.write('cards/card-1.pdf', Uint8List.fromList([1]));

      container
          .read(membersProvider.notifier)
          .put(
            const Member(
              id: 'pema',
              nameEn: 'Pema D. Sherpa',
              nameBo: '',
              number: 'JC-0900',
              cardId: 'card-2',
            ),
          );
      final next = await open();

      expect(kept.files.keys, ['cards/card-2-1.png', 'cards/card-2-2.png']);
      expect(next.card.member.cardId, 'card-2');
      expect(cards.fetched, ['card-1', 'card-2']);
    });

    test('is kept when the member changes in ways the card does not '
        'show', () async {
      await open();

      container
          .read(membersProvider.notifier)
          .put(
            const Member(
              id: 'pema',
              nameEn: 'Pema Dolkar',
              nameBo: '',
              number: 'JC-0900',
              email: 'pema@example.org',
              cardId: 'card-1',
            ),
          );
      await open();

      expect(kept.files.keys, ['cards/card-1-1.png', 'cards/card-1-2.png']);
      expect(printer.drawn, hasLength(1));
    });

    test('a demo card, which has no id, is simply drawn each time', () async {
      container
          .read(membersProvider.notifier)
          .put(
            const Member(
              id: 'pema',
              nameEn: 'Pema Dolkar',
              nameBo: '',
              number: 'JC-0900',
            ),
          );

      await open();
      await open();

      expect(printer.drawn, hasLength(2));
      expect(kept.files, isEmpty);
    });

    test('a member who is not on the list has no card to show', () async {
      final subscription = container.listen(
        memberCardProvider('nobody'),
        (_, _) {},
      );
      addTearDown(subscription.close);

      await expectLater(
        container.read(memberCardProvider('nobody').future),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('FakeCardRepository', () {
    late FakeMemberRepository members;
    late FakeCardRepository repository;

    CardRequest request(
      String id, {
      String? memberId,
      String? number,
      String name = 'Tenzin Dolma',
    }) => CardRequest(
      id: id,
      memberId: memberId,
      name: name,
      phone: '+1 416 555 0142',
      email: '',
      photo: memberId == null ? _photo : null,
      number: number,
    );

    Future<IssuedCard> issue(
      CardRequest request, {
      bool replace = false,
    }) async {
      final outcome = await repository.issue(
        _temple,
        request,
        replace: replace,
      );
      return (outcome as CardIssued).card;
    }

    setUp(() {
      members = FakeMemberRepository(Duration.zero, () => testNow);
      repository = FakeCardRepository(Duration.zero, () => testNow, members);
    });

    test('numbers carry on from the demo members, and a membership runs a '
        'year', () async {
      final first = await issue(request('a'));
      final second = await issue(request('b'));

      expect(
        [first.member.number, second.member.number],
        ['JC-0204', 'JC-0205'],
      );
      // The test clock reads 30 September 2026.
      expect(first.member.expiresOn, DateTime(2027, 9, 30));
      expect(first.pdf, isNotEmpty);
      expect(await members.fetchMembers(_temple), hasLength(10));
    });

    test('asked again for the same card, hands back the same one', () async {
      final first = await issue(request('a'));

      expect(await issue(request('a')), same(first));
      expect(await members.fetchMembers(_temple), hasLength(9));
    });

    test('a preview takes no number', () async {
      final preview = await repository.preview(_temple, request('a'));
      final chosen = await repository.preview(
        _temple,
        request('a', number: '7'),
      );

      expect((preview.number, preview.label), ('204', 'JC-0204'));
      expect((chosen.number, chosen.label), ('7', 'JC-0007'));
      expect((await issue(request('b'))).member.number, 'JC-0204');
    });

    test('a number someone holds is not given out, unless replacing', () async {
      final refused = await repository.issue(
        _temple,
        request('a', number: '142'),
      );
      expect(
        refused,
        isA<NumberTaken>()
            .having((taken) => taken.name, 'name', 'Tenzin Dolkar')
            .having((taken) => taken.number, 'number', 'JC-0142'),
      );

      final replaced = await issue(request('a', number: '142'), replace: true);
      expect(replaced.member.id, 'm1');
      expect(replaced.member.nameEn, 'Tenzin Dolma');
      expect(await members.fetchMembers(_temple), hasLength(8));
    });

    test(
      'a member on file keeps their number and dates unless changed',
      () async {
        final before = (await members.fetchMembers(
          _temple,
        )).firstWhere((member) => member.id == 'm1');

        final changed = await issue(
          request('a', memberId: 'm1', name: 'Tenzin D. Sherpa'),
        );

        expect(changed.member.id, 'm1');
        expect(changed.member.nameEn, 'Tenzin D. Sherpa');
        expect(changed.member.number, 'JC-0142');
        expect(changed.member.expiresOn, before.expiresOn);
        expect(
          (await repository.fetch(_temple, changed.member)).pdf,
          changed.pdf,
        );
      },
    );

    test('a member on file cannot take a number from someone else', () async {
      final refused = await repository.issue(
        _temple,
        request('a', memberId: 'm1', number: '87'),
        replace: true,
      );

      expect(refused, isA<NumberTaken>());
    });

    test('has a card for every demo member, and none for a stranger', () async {
      final sonam = (await members.fetchMembers(
        _temple,
      )).firstWhere((member) => member.id == 'm2');
      final card = await repository.fetch(_temple, sonam);

      expect(card.member.nameEn, 'Sonam Wangchuk');
      expect(await repository.fetch(_temple, sonam), same(card));
      await expectLater(
        repository.fetch(
          _temple,
          const Member(id: 'nobody', nameEn: '', nameBo: '', number: ''),
        ),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('FirebaseCardRepository', () {
    const id = '0b6f1c2e-5d0a-4c3b-9a55-2f4f1f0c7a10';
    final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7'));
    final issuedJson = <String, Object?>{
      'member': <Object?, Object?>{
        'id': id,
        'number': '194915308',
        'name': 'Tenzin Dolma',
        'email': null,
        'phone': '+1 416 555 0142',
        'joinedOn': '2026-10-01',
        'renewedOn': '2026-10-01',
        'expiresOn': '2027-07-31',
        'cardId': 'card-1',
        'photoKey': 'temples/drolma-ling/members/$id/cards/card-1.jpg',
        'photoUrl': 'https://files.example/photo.jpg?signature=abc',
      },
      'card': <Object?, Object?>{'pdf': base64Encode(pdf)},
    };
    // Tenzin as the member list has her, holding the card above.
    const onFile = Member(
      id: 'member-1',
      nameEn: 'Tenzin Dolma',
      nameBo: '',
      number: '194915308',
      cardId: 'card-1',
    );
    final tenzin = CardRequest(
      id: id,
      name: 'Tenzin Dolma',
      phone: '+1 416 555 0142',
      email: 'tenzin.dolma@example.org',
      photo: _photo,
    );
    late FakeBackend backend;
    late MemoryFileCache kept;
    late FirebaseCardRepository repository;

    setUp(() {
      backend = FakeBackend(issuedJson);
      kept = MemoryFileCache();
      repository = FirebaseCardRepository(backend, kept);
    });

    test('previews with the details and photo, and reads back the card and '
        'its number', () async {
      backend.response = {
        'number': '142',
        'label': 'JC-0142',
        'card': <Object?, Object?>{'pdf': base64Encode(pdf)},
      };

      final preview = await repository.preview('drolma-ling', tenzin);

      expect(backend.calls, ['members-preview']);
      expect(backend.inputs.single, {
        'templeId': 'drolma-ling',
        'name': 'Tenzin Dolma',
        'photo': base64Encode(_photo),
      });
      expect((preview.number, preview.label), ('142', 'JC-0142'));
      expect(preview.pdf, pdf);
    });

    test('previews a member on file by id, with a number if one was '
        'typed', () async {
      backend.response = {
        'number': '7',
        'label': '7',
        'card': <Object?, Object?>{'pdf': base64Encode(pdf)},
      };

      await repository.preview(
        'drolma-ling',
        const CardRequest(
          id: id,
          memberId: 'member-1',
          name: 'Tenzin Dolma',
          phone: '',
          email: '',
          number: '7',
        ),
      );

      expect(backend.inputs.single, {
        'templeId': 'drolma-ling',
        'memberId': 'member-1',
        'name': 'Tenzin Dolma',
        'number': '7',
      });
    });

    test('creates a new member and reads back who they now are', () async {
      final outcome = await repository.issue('drolma-ling', tenzin);

      expect(backend.calls, ['members-create']);
      expect(backend.inputs.single, {
        'templeId': 'drolma-ling',
        'id': id,
        'name': 'Tenzin Dolma',
        'phone': '+1 416 555 0142',
        'email': 'tenzin.dolma@example.org',
        'photo': base64Encode(_photo),
      });
      final card = (outcome as CardIssued).card;
      expect(card.member.id, id);
      expect(card.member.number, '194915308');
      expect(card.member.nameEn, 'Tenzin Dolma');
      expect(card.member.phone, '+1 416 555 0142');
      // A member with no email has an empty one, not a null.
      expect(card.member.email, isEmpty);
      expect(card.member.expiresOn, DateTime(2027, 7, 31));
      expect(card.pdf, pdf);
    });

    test('says whose a number is when it is taken, and replaces only when '
        'told to', () async {
      backend.response = {
        'taken': <Object?, Object?>{'name': 'Robert Chen', 'number': '44'},
      };
      final numbered = CardRequest(
        id: id,
        name: 'Tenzin Dolma',
        phone: '',
        email: '',
        photo: _photo,
        number: '44',
      );

      final outcome = await repository.issue('drolma-ling', numbered);

      expect(
        outcome,
        isA<NumberTaken>()
            .having((taken) => taken.name, 'name', 'Robert Chen')
            .having((taken) => taken.number, 'number', '44'),
      );
      expect(backend.inputs.single, containsPair('number', '44'));
      expect(backend.inputs.single, isNot(contains('replace')));

      backend.response = issuedJson;
      await repository.issue('drolma-ling', numbered, replace: true);
      expect(backend.inputs.last, containsPair('replace', true));
    });

    test('changes a member on file through members-update', () async {
      await repository.issue(
        'drolma-ling',
        const CardRequest(
          id: id,
          memberId: 'member-1',
          name: 'Tenzin D. Sherpa',
          phone: '',
          email: 'tenzin@example.org',
        ),
      );

      expect(backend.calls, ['members-update']);
      expect(backend.inputs.single, {
        'templeId': 'drolma-ling',
        'id': id,
        'memberId': 'member-1',
        'name': 'Tenzin D. Sherpa',
        'phone': '',
        'email': 'tenzin@example.org',
      });
    });

    test('fetches the card a member holds', () async {
      final card = await repository.fetch('drolma-ling', onFile);

      expect(backend.calls, ['members-card']);
      expect(backend.inputs.single, {
        'templeId': 'drolma-ling',
        'memberId': 'member-1',
      });
      expect(card.member.nameEn, 'Tenzin Dolma');
      expect(card.pdf, pdf);
    });

    test('reads back which card they hold and where their photo is', () async {
      final card = await repository.fetch('drolma-ling', onFile);

      expect(card.member.cardId, 'card-1');
      final photo = card.member.photo! as NetworkPhoto;
      expect(photo.url, 'https://files.example/photo.jpg?signature=abc');
      // The link changes each time it is signed; the key does not.
      expect(
        photo.cacheKey,
        'temples/drolma-ling/members/$id/cards/card-1.jpg',
      );
    });

    test('keeps a card on the device, and does not ask for it twice', () async {
      final first = await repository.fetch('drolma-ling', onFile);
      expect(kept.files.keys, ['cards/card-1.pdf']);

      final again = await repository.fetch('drolma-ling', onFile);

      expect(backend.calls, ['members-card']);
      expect(again.pdf, first.pdf);
      // Who they are now is what the list says, not what was kept.
      expect(again.member, same(onFile));
    });

    test('a card just issued is already on the device', () async {
      final outcome = await repository.issue('drolma-ling', tenzin);
      final issued = (outcome as CardIssued).card;

      final fetched = await repository.fetch('drolma-ling', issued.member);

      expect(backend.calls, ['members-create']);
      expect(fetched.pdf, issued.pdf);
    });

    test('asks again once the member holds another card', () async {
      await repository.fetch('drolma-ling', onFile);
      const reissued = Member(
        id: 'member-1',
        nameEn: 'Tenzin D. Sherpa',
        nameBo: '',
        number: '194915308',
        cardId: 'card-2',
      );

      await repository.fetch('drolma-ling', reissued);

      expect(backend.calls, ['members-card', 'members-card']);
    });

    test('keeps nothing for a number that turned out to be taken', () async {
      backend.response = {
        'taken': <Object?, Object?>{'name': 'Robert Chen', 'number': '44'},
      };

      await repository.issue('drolma-ling', tenzin);

      expect(kept.files, isEmpty);
    });

    test('waits longer than the backend is given to draw a card', () async {
      await repository.issue('drolma-ling', tenzin);
      backend.response = {
        'number': '1',
        'label': '1',
        'card': <Object?, Object?>{'pdf': base64Encode(pdf)},
      };
      await repository.preview('drolma-ling', tenzin);

      // `timeoutSeconds` of the card functions in functions/.
      for (final timeout in backend.timeouts) {
        expect(timeout, greaterThan(const Duration(seconds: 60)));
      }
    });

    test('says which field the backend refused', () async {
      backend.error = FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'The request was not valid.',
        details: {
          'fields': {
            'name': 'memberNameTooLong',
            'phone': 'phoneTooLong',
            'email': 'emailIncomplete',
            'photo': 'photoUnreadable',
            'number': 'memberNumberInvalid',
          },
        },
      );

      await expectLater(
        repository.issue('drolma-ling', tenzin),
        throwsA(
          isA<ValidationFailure>().having((f) => f.issues, 'issues', {
            'name': ValidationIssue.memberNameTooLong,
            'phone': ValidationIssue.phoneTooLong,
            'email': ValidationIssue.emailIncomplete,
            'photo': ValidationIssue.photoUnreadable,
            'number': ValidationIssue.memberNumberInvalid,
          }),
        ),
      );
    });

    test('says so when the caller is on no temple team, or the member is '
        'gone', () async {
      backend.error = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Not on the team.',
        details: {'reason': 'notOnTeam'},
      );
      await expectLater(
        repository.preview('drolma-ling', tenzin),
        throwsA(
          isA<PermissionFailure>().having(
            (f) => f.reason,
            'reason',
            PermissionReason.notOnTeam,
          ),
        ),
      );

      backend.error = FirebaseFunctionsException(
        code: 'not-found',
        message: 'No such member.',
      );
      await expectLater(
        repository.fetch('drolma-ling', onFile),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('FirebaseMemberRepository', () {
    late FakeBackend backend;
    late FirebaseMemberRepository repository;

    setUp(() {
      backend = FakeBackend({
        'members': <Object?>[
          <Object?, Object?>{
            'id': 'member-2',
            'number': 'DL-0002',
            'name': 'Ngawang Choedon',
            'email': 'ngawang@example.org',
            'phone': null,
            'joinedOn': '2026-10-02',
            'renewedOn': '2026-10-02',
            'expiresOn': '2026-10-20',
          },
          <Object?, Object?>{
            'id': 'member-1',
            'number': 'DL-0001',
            'name': 'Yeshi Lhamo',
            'email': null,
            'phone': '+1 604 555 0158',
            'joinedOn': '2026-10-01',
            'renewedOn': '2026-10-01',
            'expiresOn': '2027-10-01',
          },
        ],
      });
      repository = FirebaseMemberRepository(backend, () => testNow);
    });

    test(
      'lists the temple\'s members in the order the backend gives',
      () async {
        final members = await repository.fetchMembers('drolma-ling');

        expect(backend.calls, ['members-list']);
        expect(backend.inputs.single, {'templeId': 'drolma-ling'});
        expect(members.map((member) => member.number), ['DL-0002', 'DL-0001']);
        final ngawang = members.first;
        expect(ngawang.nameEn, 'Ngawang Choedon');
        expect(ngawang.email, 'ngawang@example.org');
        expect(ngawang.phone, isEmpty);
        // The test clock reads 30 September 2026.
        expect(ngawang.statusOn(testNow), MembershipStatus.expiring);
        expect(members.last.statusOn(testNow), MembershipStatus.active);
        expect(members.last.matches('604 555'), isTrue);
      },
    );

    test('checks in a member who is on the roll, and nobody else', () async {
      final checkIn = await repository.checkIn('drolma-ling', 'member-1');

      expect(checkIn.member.nameEn, 'Yeshi Lhamo');
      expect(checkIn.at, testNow);
      await expectLater(
        repository.checkIn('drolma-ling', 'nobody'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('does not renew yet, and says so rather than pretending', () async {
      await expectLater(
        repository.renew('drolma-ling', 'member-1'),
        throwsA(isA<UnavailableFailure>()),
      );
    });

    test('passes on what the backend refuses', () async {
      backend.error = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'A volunteer may not do this.',
      );

      await expectLater(
        repository.fetchMembers('drolma-ling'),
        throwsA(isA<PermissionFailure>()),
      );
    });
  });

  group('cropping to the card', () {
    testWidgets('exports the framed part at the size the card prints', (
      tester,
    ) async {
      final controller = PhotoCropController(
        shape: const PhotoCropShape.idCard(),
      );
      addTearDown(controller.dispose);

      final cropped = await tester.runAsync(() async {
        await controller.load(await _png(1200, 900));
        return _sizeOf(await controller.export(size: CardPhoto.longSide));
      });

      // 600 dots per inch across the card's 1.10 by 1.26 inch photo.
      expect(cropped, const Size(662, 754));
    });
  });

  group('the ID card screens', () {
    setUpAll(loadAppFonts);

    /// The app, signed in, with the members screens as the backend has them.
    Future<ProviderContainer> liveApp(
      WidgetTester tester, {
      required RecordingPrinter printer,
      RecordingLauncher? launcher,
      Uint8List? picture,
    }) async {
      tester.setScreenSize(const Size(390, 844));
      final container = createContainer(
        config: _liveMembers,
        overrides: [
          documentPrinterProvider.overrideWithValue(printer),
          if (launcher != null)
            contactLauncherProvider.overrideWithValue(launcher),
          if (picture != null)
            photoPickerProvider.overrideWithValue(OnePhoto(picture)),
        ],
      );
      await tester.pumpApp(container);
      await tester.runAsync(() async {
        await signIn(container);
        // As it is once the Members tab has been opened.
        await container.read(membersProvider.future);
      });
      await tester.pumpAndSettle();
      return container;
    }

    /// Clears a toast that, on the test's frozen clock, would sit over the
    /// buttons at the foot of the screen.
    Future<void> clearToast(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      container.read(appMessengerProvider.notifier).dismiss();
      await tester.pumpAndSettle();
    }

    /// Takes a photo and types a name: enough to preview a card.
    Future<void> fillIn(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
      // The zoom slider comes alive once the picked photo has been decoded.
      final cropReady = find.byWidgetPredicate(
        (widget) => widget is Slider && widget.onChanged != null,
        description: 'the crop editor with its photo loaded',
      );
      await tester.tapAndWaitFor('Upload photo', cropReady);
      await tester.tapAndWaitFor(
        'Use this photo',
        find.text('Adjust the crop'),
      );
      await tester.enterText(find.byType(TextField).at(0), 'Tenzin Dolma');
      await tester.pumpAndSettle();
      await clearToast(tester, container);
    }

    /// Types [digits] into "Edit ID number" and waits for the new preview.
    Future<void> useNumber(WidgetTester tester, String digits) async {
      await tester.tap(find.text('Edit ID number').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), digits);
      await tester.tapAndWaitFor(
        'Use this number',
        find.textContaining('ID number: JC-${digits.padLeft(4, '0')}'),
      );
    }

    testWidgets('are what Add a Member opens once the backend is on', (
      tester,
    ) async {
      final container = await liveApp(tester, printer: RecordingPrinter());

      container.read(routerProvider).go(AppRoutes.members);
      await tester.pumpAndSettle();
      // One way in, not two.
      expect(find.text('New ID card'), findsNothing);

      container.read(routerProvider).go(AppRoutes.addMember);
      await tester.pumpAndSettle();
      expect(find.byType(CardFormScreen), findsOneWidget);
    });

    testWidgets('take a photo and a name, preview the card, and end with it '
        'on screen, ready to print', (tester) async {
      final printer = RecordingPrinter();
      final picture = (await tester.runAsync(() => _png(900, 1200)))!;
      final container = await liveApp(
        tester,
        printer: printer,
        picture: picture,
      );
      container.read(routerProvider).go(AppRoutes.newCard);
      await tester.pumpAndSettle();

      // Nothing is drawn until the photo and the name are there.
      await tester.tap(find.text('Preview ID'));
      await tester.pumpAndSettle();
      expect(find.text('Please add a photo for the ID card.'), findsOneWidget);
      expect(find.text("Please type the member's name."), findsOneWidget);

      // Phone and email are left empty: neither is needed.
      await fillIn(tester, container);
      await tester.tapAndWaitFor('Preview ID', find.text('ID number: JC-0204'));

      // The front of the card, and nothing saved yet.
      expect(find.bySemanticsLabel('Front'), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsNothing);
      expect(container.read(membersProvider).requireValue, hasLength(8));

      await tester.tapAndWaitFor('Create ID card', find.text('ID card ready'));

      expect(
        find.text(
          'Tenzin Dolma is member number JC-0204. '
          'Valid until Sep 30, 2027.',
        ),
        findsOneWidget,
      );
      // The card itself is on the screen: its front and its back.
      expect(find.byType(CardPages), findsOneWidget);
      expect(find.bySemanticsLabel('Front'), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);

      await tester.tap(find.text('Print the card'));
      await tester.pumpAndSettle();
      expect(printer.printed.keys, ['ID card JC-0204']);

      // The list has the new member, at the top.
      await clearToast(tester, container);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Tenzin Dolma'), findsOneWidget);
      expect(find.text('JC-0204'), findsOneWidget);
    });

    testWidgets('let the ID number be changed on the preview, in numbers '
        'only', (tester) async {
      final picture = (await tester.runAsync(() => _png(900, 1200)))!;
      final container = await liveApp(
        tester,
        printer: RecordingPrinter(),
        picture: picture,
      );
      container.read(routerProvider).go(AppRoutes.newCard);
      await tester.pumpAndSettle();
      // The number cannot be changed before the preview.
      expect(find.text('Edit ID number'), findsNothing);
      await fillIn(tester, container);
      await tester.tapAndWaitFor('Preview ID', find.text('ID number: JC-0204'));
      expect(find.text('Filled in for you.'), findsOneWidget);

      await tester.tap(find.text('Edit ID number').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'JC-300');
      await tester.tap(find.text('Use this number'));
      await tester.pumpAndSettle();
      expect(
        find.text('Please type the ID number in numbers only.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '300');
      await tester.tapAndWaitFor(
        'Use this number',
        find.text('ID number: JC-0300'),
      );
      // The screen no longer claims a number it did not choose.
      expect(find.text('Typed by you.'), findsOneWidget);
      expect(find.text('Filled in for you.'), findsNothing);
      await tester.tapAndWaitFor('Create ID card', find.text('ID card ready'));
      expect(find.textContaining('member number JC-0300'), findsOneWidget);
    });

    testWidgets('send the keyboard\'s Next from the name to the phone number, '
        'past the country', (tester) async {
      final container = await liveApp(tester, printer: RecordingPrinter());
      container.read(routerProvider).go(AppRoutes.newCard);
      await tester.pumpAndSettle();

      final name = find.byType(TextField).at(0);
      await tester.ensureVisible(name);
      await tester.tap(name);
      await tester.pump();
      tester.testTextInput.enterText('Tenzin Dolma');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      // Typed without tapping anything: it lands wherever Next went.
      tester.testTextInput.enterText('416 555 0142');
      await tester.pump();

      final state = container.read(cardFormViewModelProvider(null));
      expect(state.name, 'Tenzin Dolma');
      expect(state.phone, '416 555 0142');
    });

    testWidgets('say a member keeps the photo on file only while that is '
        'the photo shown', (tester) async {
      final picture = (await tester.runAsync(() => _png(900, 1200)))!;
      final container = await liveApp(
        tester,
        printer: RecordingPrinter(),
        picture: picture,
      );
      container
          .read(membersProvider.notifier)
          .put(
            Member(
              id: 'with-photo',
              nameEn: 'Yeshi Lhamo',
              nameBo: '',
              number: 'JC-0901',
              photo: MemoryPhoto(picture),
            ),
          );
      container.read(routerProvider).go(AppRoutes.editMember('with-photo'));
      await tester.pumpAndSettle();
      const kept =
          'This is the photo on file. It stays unless you add a new one.';
      expect(find.text(kept), findsOneWidget);

      // The zoom slider comes alive once the picked photo has been decoded.
      final cropReady = find.byWidgetPredicate(
        (widget) => widget is Slider && widget.onChanged != null,
      );
      await tester.tapAndWaitFor('Upload photo', cropReady);
      await tester.tapAndWaitFor(
        'Use this photo',
        find.text('Adjust the crop'),
      );

      expect(find.text(kept), findsNothing);
      expect(find.text('The photo is printed on the ID card.'), findsOneWidget);
    });

    testWidgets('let a screen reader open the list of countries', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final container = await liveApp(tester, printer: RecordingPrinter());
      container.read(routerProvider).go(AppRoutes.newCard);
      await tester.pumpAndSettle();

      final country = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^Country: ')),
      );
      expect(
        country.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets('warn when the ID number is someone else\'s, and replace '
        'only when told to', (tester) async {
      final picture = (await tester.runAsync(() => _png(900, 1200)))!;
      final container = await liveApp(
        tester,
        printer: RecordingPrinter(),
        picture: picture,
      );
      container.read(routerProvider).go(AppRoutes.newCard);
      await tester.pumpAndSettle();
      await fillIn(tester, container);
      await tester.tapAndWaitFor('Preview ID', find.text('ID number: JC-0204'));
      // Tenzin Dolkar is JC-0142.
      await useNumber(tester, '142');

      await tester.tapAndWaitFor(
        'Create ID card',
        find.text('ID JC-0142 already exists'),
      );
      expect(
        find.text(
          'ID JC-0142 belongs to Tenzin Dolkar. Replace them with this '
          'person? Tenzin Dolkar will no longer be on the member list.',
        ),
        findsOneWidget,
      );

      // Cancelling leaves everyone as they were, on the preview.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('ID number: JC-0142'), findsOneWidget);
      expect(container.read(membersProvider).requireValue, hasLength(8));

      await tester.tapAndWaitFor(
        'Create ID card',
        find.text('ID JC-0142 already exists'),
      );
      await tester.tapAndWaitFor('Replace', find.text('ID card ready'));

      expect(
        find.textContaining('Tenzin Dolma is member number JC-0142'),
        findsOneWidget,
      );
      final members = container.read(membersProvider).requireValue;
      expect(members, hasLength(8));
      expect(members.map((member) => member.nameEn), contains('Tenzin Dolma'));
      expect(
        members.map((member) => member.nameEn),
        isNot(contains('Tenzin Dolkar')),
      );
    });

    testWidgets('show a member\'s own card, with only the ways they can be '
        'reached', (tester) async {
      final printer = RecordingPrinter();
      final launcher = RecordingLauncher();
      final container = await liveApp(
        tester,
        printer: printer,
        launcher: launcher,
      );
      container.read(routerProvider).go(AppRoutes.member('m1'));
      await tester.pumpAndSettle();

      expect(find.byType(MemberDetailScreen), findsOneWidget);
      expect(find.text('Tenzin Dolkar'), findsOneWidget);
      expect(find.text('ID JC-0142'), findsOneWidget);
      expect(find.byType(CardPages), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      // She gave a phone number and no email.
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(
        find.text('Email'),
        findsNWidgets(1),
        reason: 'the row, no button',
      );
      expect(find.text('Not given'), findsOneWidget);

      await tester.ensureVisible(find.text('WhatsApp'));
      await tester.tap(find.text('WhatsApp'));
      await tester.pumpAndSettle();
      expect(launcher.messaged, ['14165550142']);

      await tester.tap(find.text('Print the card'));
      await tester.pumpAndSettle();
      expect(printer.printed.keys, ['ID card JC-0142']);
    });

    testWidgets('change a member through the same preview, and block a '
        'number that is someone else\'s', (tester) async {
      final container = await liveApp(tester, printer: RecordingPrinter());
      container.read(routerProvider).go(AppRoutes.member('m1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit member'), findsOneWidget);
      // The form starts from the member, and asks for no new photo.
      expect(find.text('Tenzin Dolkar'), findsOneWidget);
      expect(find.text('416 555 0142'), findsOneWidget);
      // A demo member has no photo, so nothing is said about keeping one.
      expect(find.textContaining('photo on file'), findsNothing);

      await tester.enterText(
        find.byType(TextField).at(2),
        'tenzin@example.org',
      );
      await tester.pumpAndSettle();
      await tester.tapAndWaitFor('Preview ID', find.text('ID number: JC-0142'));
      expect(find.text('The number they have now.'), findsOneWidget);

      // Sonam Wangchuk is JC-0087: an edit may not take his number.
      await useNumber(tester, '87');
      await tester.tapAndWaitFor(
        'Save changes',
        find.text('ID JC-0087 already exists'),
      );
      expect(
        find.text(
          'ID JC-0087 belongs to Sonam Wangchuk. Please choose another '
          'number.',
        ),
        findsOneWidget,
      );
      expect(find.text('Replace'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await useNumber(tester, '142');
      await tester.tapAndWaitFor('Save changes', find.text('Changes saved'));

      final member = container
          .read(membersProvider)
          .requireValue
          .firstWhere((member) => member.id == 'm1');
      expect(member.email, 'tenzin@example.org');
      expect(member.number, 'JC-0142');

      // Back on the member, who can now be emailed.
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(MemberDetailScreen), findsOneWidget);
      expect(find.text('tenzin@example.org'), findsOneWidget);
      expect(find.text('Email'), findsNWidgets(2));
    });
  });
}

/// A plain-coloured PNG, standing in for a photo of a person.
Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<Size> _sizeOf(Uint8List png) async {
  final frame = await (await ui.instantiateImageCodec(png)).getNextFrame();
  return Size(frame.image.width.toDouble(), frame.image.height.toDouble());
}

/// Hands back a card for whichever one the member holds, and counts.
class _CountingCards implements CardRepository {
  final fetched = <String?>[];

  @override
  Future<IssuedCard> fetch(String templeId, Member member) async {
    fetched.add(member.cardId);
    return IssuedCard(
      member: member,
      pdf: Uint8List.fromList(utf8.encode('%PDF ${member.cardId}')),
    );
  }

  @override
  Future<CardOutcome> issue(
    String templeId,
    CardRequest request, {
    bool replace = false,
  }) => throw UnimplementedError();

  @override
  Future<CardPreview> preview(String templeId, CardRequest request) =>
      throw UnimplementedError();
}

/// A request to issue a card, as the repository was asked.
class _Issue {
  _Issue(this.request, {required this.replace});

  final CardRequest request;
  final bool replace;

  String get id => request.id;
  String? get number => request.number;
}

/// The app's own card repository, driven by the test: it notes each card it
/// is asked for, can be held mid-call, and can be told to fail.
class _DrivenCards implements CardRepository {
  _DrivenCards(this._inner);

  /// Over the demo's own cards, issued to the demo members the list shows.
  factory _DrivenCards.on(Ref ref) => _DrivenCards(
    FakeCardRepository(
      Duration.zero,
      () => testNow,
      ref.watch(memberRepositoryProvider) as FakeMemberRepository,
    ),
  );

  final CardRepository _inner;
  final previewed = <CardRequest>[];
  final issued = <_Issue>[];
  AppFailure? failWith;
  Completer<void>? holding;

  @override
  Future<CardPreview> preview(String templeId, CardRequest request) async {
    previewed.add(request);
    await holding?.future;
    if (failWith case final failure?) throw failure;
    return _inner.preview(templeId, request);
  }

  @override
  Future<CardOutcome> issue(
    String templeId,
    CardRequest request, {
    bool replace = false,
  }) async {
    issued.add(_Issue(request, replace: replace));
    await holding?.future;
    if (failWith case final failure?) throw failure;
    return _inner.issue(templeId, request, replace: replace);
  }

  @override
  Future<IssuedCard> fetch(String templeId, Member member) =>
      _inner.fetch(templeId, member);
}
