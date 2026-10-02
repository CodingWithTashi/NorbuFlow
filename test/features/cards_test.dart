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
import 'package:norbu_flow/core/services/document_printer.dart';
import 'package:norbu_flow/core/services/photo_picker.dart';
import 'package:norbu_flow/core/utils/ids.dart';
import 'package:norbu_flow/features/auth/data/auth_repositories.dart';
import 'package:norbu_flow/features/auth/data/fake_auth_repository.dart';
import 'package:norbu_flow/features/members/data/fake_card_repository.dart';
import 'package:norbu_flow/features/members/data/firebase_card_repository.dart';
import 'package:norbu_flow/features/members/data/member_repositories.dart';
import 'package:norbu_flow/features/members/domain/card.dart';
import 'package:norbu_flow/features/members/presentation/view_models/new_card_view_model.dart';
import 'package:norbu_flow/features/members/presentation/views/new_card_screen.dart';
import 'package:norbu_flow/features/members/presentation/widgets/card_pages.dart';
import 'package:norbu_flow/features/members/presentation/widgets/photo_cropper.dart';

import '../support/fake_backend.dart';
import '../support/test_app.dart';

final _photo = Uint8List.fromList([1, 2, 3, 4]);
final _picked = Uint8List.fromList([9, 9, 9]);

/// A one-pixel PNG for each side of a card: enough for the screen to show.
final _frontPage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==',
);
final _backPage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGOoktf+DwADnwHE9CgVtQAAAABJRU5ErkJggg==',
);

void main() {
  group('new ID card', () {
    late _RecordingPrinter printer;
    late _DrivenCards cards;
    late ProviderContainer container;

    NewCardState state() => container.read(newCardViewModelProvider);
    NewCardViewModel card() =>
        container.read(newCardViewModelProvider.notifier);
    AppFailure? shownFailure() => container.read(appMessengerProvider)?.failure;

    /// Fills in everything a card needs.
    void fillIn() => card()
      ..setName('Tenzin Dolma')
      ..setPhone('416 555 0142')
      ..setEmail('tenzin.dolma@example.org')
      ..useCroppedPhoto(_photo);

    setUp(() {
      printer = _RecordingPrinter();
      cards = _DrivenCards();
      var made = 0;
      container = createContainer(
        overrides: [
          documentPrinterProvider.overrideWithValue(printer),
          cardRepositoryProvider.overrideWithValue(cards),
          photoPickerProvider.overrideWithValue(_OnePhoto(_picked)),
          newIdProvider.overrideWithValue(() => 'card-${++made}'),
        ],
      );
      final subscription = container.listen(
        newCardViewModelProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      addTearDown(container.read(appMessengerProvider.notifier).dismiss);
    });

    test('asks for a photo, a name and a phone number, and sends nothing '
        'until they are there', () async {
      await card().submit();

      expect(state().issues, {
        NewCardField.photo: ValidationIssue.photoRequired,
        NewCardField.name: ValidationIssue.memberNameRequired,
        NewCardField.phone: ValidationIssue.phoneTooShort,
      });
      expect(cards.asked, isEmpty);

      // Fixing a field clears only that field's message.
      card().setName('Tenzin Dolma');
      expect(state().issues.keys, [NewCardField.photo, NewCardField.phone]);
      card().setPhone('416 555 0142');
      card().useCroppedPhoto(_photo);
      expect(state().issues, isEmpty);
    });

    test('email may be left out, but not left half typed', () async {
      fillIn();
      card().setEmail('tenzin@');

      await card().submit();

      expect(state().issues, {
        NewCardField.email: ValidationIssue.emailIncomplete,
      });
      expect(cards.asked, isEmpty);

      card().setEmail('');
      await card().submit();
      expect(state().issued, isNotNull);
    });

    test('sends the details tidied, with the cropped photo, and keeps the '
        'card that comes back', () async {
      card()
        ..setName('  Tenzin Dolma ')
        ..setPhone(' 416 555 0142 ')
        ..setEmail(' Tenzin.Dolma@example.org')
        ..useCroppedPhoto(_photo);

      await card().submit();

      final sent = cards.asked.single;
      expect(sent.name, 'Tenzin Dolma');
      expect(sent.phone, '416 555 0142');
      expect(sent.email, 'Tenzin.Dolma@example.org');
      expect(sent.photo, _photo);
      expect(state().issued?.name, 'Tenzin Dolma');
      expect(state().submitting, isFalse);
    });

    test(
      'a second tap while the card is being made asks for one card',
      () async {
        cards.holding = Completer<void>();
        fillIn();

        final first = card().submit();
        await card().submit();
        cards.holding!.complete();
        await first;

        expect(cards.asked, hasLength(1));
      },
    );

    test('trying again after a failure asks for the same card, so the member '
        'is not added twice; the next person is a new card', () async {
      cards.failWith = const NetworkFailure();
      fillIn();
      await card().submit();
      cards.failWith = null;
      await card().submit();

      card().startAnother();
      fillIn();
      await card().submit();

      expect(cards.asked.map((card) => card.id), [
        'card-1',
        'card-1',
        'card-2',
      ]);
    });

    test('shows the issued card\'s own pages, front then back', () async {
      expect(await container.read(cardPagesProvider.future), isEmpty);
      fillIn();
      await card().submit();

      final pages = await container.read(cardPagesProvider.future);

      expect([for (final page in pages) page.bytes], [_frontPage, _backPage]);
      expect(printer.drawn, [state().issued!.pdf]);
    });

    test('a device that cannot draw the card still issues it', () async {
      printer.pagesFailure = const UnavailableFailure();
      fillIn();

      await card().submit();

      expect(state().issued, isNotNull);
      await expectLater(
        container.read(cardPagesProvider.future),
        throwsA(isA<UnavailableFailure>()),
      );
    });

    test('prints and shares the card that was issued', () async {
      fillIn();
      await card().submit();
      final pdf = state().issued!.pdf;

      await card().printCard('ID card 194915308');
      await card().shareCard('ID card 194915308');

      expect(printer.printed, {'ID card 194915308': pdf});
      expect(printer.shared, {'ID card 194915308.pdf': pdf});
    });

    test('there is nothing to print before a card exists', () async {
      await card().printCard('ID card');
      expect(printer.printed, isEmpty);
    });

    test('starting another card clears the form', () async {
      fillIn();
      await card().submit();

      card().startAnother();

      expect(state().issued, isNull);
      expect(state().name, isEmpty);
      expect(state().phone, isEmpty);
      expect(state().email, isEmpty);
      expect(state().photo.cropped, isNull);
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
      await card().submit();

      await card().pickPhoto(PhotoOrigin.gallery);
      card().cancelCrop();
      expect(state().issues, contains(NewCardField.photo));

      card().useCroppedPhoto(_photo);
      expect(state().issues, isNot(contains(NewCardField.photo)));
    });

    test('what the backend refuses is flagged on the field it is '
        'about', () async {
      cards.failWith = const ValidationFailure({
        'name': ValidationIssue.memberNameUnsupported,
        'phone': ValidationIssue.phoneTooShort,
      });
      fillIn();

      await card().submit();

      expect(state().issues, {
        NewCardField.name: ValidationIssue.memberNameUnsupported,
        NewCardField.phone: ValidationIssue.phoneTooShort,
      });
      expect(state().issued, isNull);
      expect(shownFailure(), isNull);
    });

    test('any other failure is shown as a toast, and can be retried', () async {
      cards.failWith = const PermissionFailure(
        reason: PermissionReason.notOnTeam,
      );
      fillIn();

      await card().submit();

      expect(shownFailure(), isA<PermissionFailure>());
      expect(state().issues, isEmpty);
      expect(state().submitting, isFalse);
      expect(state().name, 'Tenzin Dolma');
    });
  });

  group('FakeCardRepository', () {
    late FakeCardRepository repository;

    NewCard card(String id) => NewCard(
      id: id,
      name: 'Tenzin Dolma',
      phone: '416 555 0142',
      email: '',
      photo: _photo,
    );

    setUp(() => repository = FakeCardRepository(Duration.zero, () => testNow));

    test(
      'numbers count up, and a membership runs to the next 31 July',
      () async {
        final first = await repository.issue(card('a'));
        final second = await repository.issue(card('b'));

        expect([first.number, second.number], ['194915308', '194915309']);
        // The test clock reads 30 September 2026.
        expect(first.expiresOn, DateTime(2027, 7, 31));
        expect(first.pdf, isNotEmpty);
      },
    );

    test('asked again for the same card, hands back the same one', () async {
      final first = await repository.issue(card('a'));

      expect(await repository.issue(card('a')), same(first));
    });
  });

  group('FirebaseCardRepository', () {
    final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7'));
    final tenzin = NewCard(
      id: '0b6f1c2e-5d0a-4c3b-9a55-2f4f1f0c7a10',
      name: 'Tenzin Dolma',
      phone: '416 555 0142',
      email: 'tenzin.dolma@example.org',
      photo: _photo,
    );
    late FakeBackend backend;
    late FirebaseCardRepository repository;

    setUp(() {
      backend = FakeBackend({
        'member': <Object?, Object?>{
          'id': '0b6f1c2e-5d0a-4c3b-9a55-2f4f1f0c7a10',
          'number': '194915308',
          'name': 'Tenzin Dolma',
          'email': null,
          'phone': '416 555 0142',
          'joinedOn': '2026-10-01',
          'renewedOn': '2026-10-01',
          'expiresOn': '2027-07-31',
        },
        'card': <Object?, Object?>{'pdf': base64Encode(pdf)},
      });
      repository = FirebaseCardRepository(backend);
    });

    test('sends the details and photo and reads back the card', () async {
      final card = await repository.issue(tenzin);

      expect(backend.calls, ['members-create']);
      expect(backend.inputs.single, {
        'id': '0b6f1c2e-5d0a-4c3b-9a55-2f4f1f0c7a10',
        'name': 'Tenzin Dolma',
        'phone': '416 555 0142',
        'email': 'tenzin.dolma@example.org',
        'photo': base64Encode(_photo),
      });
      expect(card.number, '194915308');
      expect(card.name, 'Tenzin Dolma');
      expect(card.expiresOn, DateTime(2027, 7, 31));
      expect(card.pdf, pdf);
    });

    test('waits longer than the backend is given to make a card', () async {
      await repository.issue(tenzin);

      // `timeoutSeconds` of members-create in functions/.
      expect(backend.timeouts.single, greaterThan(const Duration(seconds: 60)));
    });

    test('says which field the backend refused', () async {
      backend.error = FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'The request was not valid.',
        details: {
          'fields': {
            'name': 'memberNameTooLong',
            'phone': 'phoneTooShort',
            'email': 'emailIncomplete',
            'photo': 'photoUnreadable',
          },
        },
      );

      await expectLater(
        repository.issue(tenzin),
        throwsA(
          isA<ValidationFailure>().having((f) => f.issues, 'issues', {
            'name': ValidationIssue.memberNameTooLong,
            'phone': ValidationIssue.phoneTooShort,
            'email': ValidationIssue.emailIncomplete,
            'photo': ValidationIssue.photoUnreadable,
          }),
        ),
      );
    });

    test('says so when the caller is on no temple team', () async {
      backend.error = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Not on the team.',
        details: {'reason': 'notOnTeam'},
      );

      await expectLater(
        repository.issue(tenzin),
        throwsA(
          isA<PermissionFailure>().having(
            (f) => f.reason,
            'reason',
            PermissionReason.notOnTeam,
          ),
        ),
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

  group('the New ID card screen', () {
    setUpAll(loadAppFonts);

    testWidgets('is what Add a Member opens once the backend is on', (
      tester,
    ) async {
      tester.setScreenSize(const Size(390, 844));
      final container = createContainer(
        config: const AppConfig(useFirebase: true, fakeLatency: Duration.zero),
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(Duration.zero),
          ),
        ],
      );
      await tester.pumpApp(container);
      await tester.runAsync(() => signIn(container));

      container.read(routerProvider).go(AppRoutes.members);
      await tester.pumpAndSettle();
      // One way in, not two.
      expect(find.text('New ID card'), findsNothing);

      container.read(routerProvider).go(AppRoutes.addMember);
      await tester.pumpAndSettle();
      expect(find.byType(NewCardScreen), findsOneWidget);
    });

    testWidgets('takes a photo and the details and ends with the card on '
        'screen, ready to print', (tester) async {
      tester.setScreenSize(const Size(390, 844));
      final printer = _RecordingPrinter();
      final picture = (await tester.runAsync(() => _png(900, 1200)))!;
      final container = createContainer(
        overrides: [
          documentPrinterProvider.overrideWithValue(printer),
          photoPickerProvider.overrideWithValue(_OnePhoto(picture)),
        ],
      );
      await tester.pumpApp(container);
      await tester.runAsync(() => signIn(container));
      container.read(routerProvider).go(AppRoutes.newCard);
      await tester.pumpAndSettle();

      // Nothing is sent until the photo, the name and the phone are there.
      await tester.tap(find.text('Create ID card'));
      await tester.pumpAndSettle();
      expect(find.text('Please add a photo for the ID card.'), findsOneWidget);
      expect(find.text("Please type the member's name."), findsOneWidget);

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

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Tenzin Dolma');
      await tester.enterText(fields.at(1), '416 555 0142');
      await tester.enterText(fields.at(2), 'tenzin.dolma@example.org');
      await tester.pumpAndSettle();
      // The "photo cropped" toast is still up on the test's frozen clock, and
      // sits over the button.
      container.read(appMessengerProvider.notifier).dismiss();
      await tester.pumpAndSettle();
      await tester.tapAndWaitFor('Create ID card', find.text('ID card ready'));

      expect(
        find.text(
          'Tenzin Dolma is member number 194915308. '
          'Valid until Jul 31, 2027.',
        ),
        findsOneWidget,
      );
      // The card itself is on the screen: its front and its back.
      expect(find.byType(CardPages), findsOneWidget);
      expect(find.bySemanticsLabel('Front'), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);

      await tester.tap(find.text('Print the card'));
      await tester.pumpAndSettle();
      expect(printer.printed.keys, ['ID card 194915308']);

      container.read(appMessengerProvider.notifier).dismiss();
      await tester.pump();
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

class _RecordingPrinter implements DocumentPrinter {
  final printed = <String, Uint8List>{};
  final shared = <String, Uint8List>{};
  final drawn = <Uint8List>[];
  AppFailure? pagesFailure;

  @override
  Future<List<Uint8List>> pages(Uint8List pdf) async {
    if (pagesFailure case final failure?) throw failure;
    drawn.add(pdf);
    return [_frontPage, _backPage];
  }

  @override
  Future<void> print(Uint8List pdf, {required String name}) async =>
      printed[name] = pdf;

  @override
  Future<void> share(Uint8List pdf, {required String fileName}) async =>
      shared[fileName] = pdf;
}

/// The demo repository, driven by the test: it notes each card it is asked
/// for, can be held mid-call, and can be told to fail.
class _DrivenCards implements CardRepository {
  final _fake = FakeCardRepository(Duration.zero, () => testNow);
  final asked = <NewCard>[];
  AppFailure? failWith;
  Completer<void>? holding;

  @override
  Future<IssuedCard> issue(NewCard card) async {
    asked.add(card);
    await holding?.future;
    if (failWith case final failure?) throw failure;
    return _fake.issue(card);
  }
}

class _OnePhoto implements PhotoPicker {
  _OnePhoto(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List?> pick(PhotoOrigin origin) async => bytes;
}
