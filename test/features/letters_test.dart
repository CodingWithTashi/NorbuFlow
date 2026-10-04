import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/app/router/app_router.dart';
import 'package:norbu_flow/app/router/app_routes.dart';
import 'package:norbu_flow/core/error/app_failure.dart';
import 'package:norbu_flow/core/error/validation_issue.dart';
import 'package:norbu_flow/core/feedback/app_messenger.dart';
import 'package:norbu_flow/core/models/formatted_text.dart';
import 'package:norbu_flow/core/services/clipboard_reader.dart';
import 'package:norbu_flow/core/services/document_printer.dart';
import 'package:norbu_flow/core/services/file_cache.dart';
import 'package:norbu_flow/core/utils/ids.dart';
import 'package:norbu_flow/features/letters/data/fake_letter_repository.dart';
import 'package:norbu_flow/features/letters/data/firebase_letter_repository.dart';
import 'package:norbu_flow/features/letters/data/letter_draft_store.dart';
import 'package:norbu_flow/features/letters/data/letter_json.dart';
import 'package:norbu_flow/features/letters/data/letter_repositories.dart';
import 'package:norbu_flow/features/letters/domain/letter.dart';
import 'package:norbu_flow/features/letters/presentation/view_models/letter_form_view_model.dart';
import 'package:norbu_flow/features/letters/presentation/view_models/letter_on_file_view_model.dart';
import 'package:norbu_flow/features/letters/presentation/view_models/letters_view_model.dart';
import 'package:norbu_flow/features/letters/presentation/widgets/letter_page.dart';
import 'package:norbu_flow/features/members/presentation/view_models/members_view_model.dart';
import 'package:norbu_flow/features/settings/domain/app_preferences.dart';
import 'package:norbu_flow/features/settings/presentation/view_models/preferences_view_model.dart';
import 'package:norbu_flow/features/temple/data/fake_temple_repository.dart';
import 'package:norbu_flow/features/temple/domain/role.dart';
import 'package:norbu_flow/features/temple/presentation/view_models/temple_session.dart';
import 'package:norbu_flow/l10n/generated/app_localizations.dart';

import '../support/cards.dart';
import '../support/clipboard.dart';
import '../support/fake_backend.dart';
import '../support/test_app.dart';

const _temple = FakeTemples.jangchubId;
const LetterStart _fresh = (name: null, like: null);

const _wording =
    'This letter is to confirm that Pema Lhamo has volunteered since 2024.';

/// What the fakes hold for every temple before a test issues anything.
const _seeded = ['1003', '1002', '1001'];

void main() {
  group('a new support letter', () {
    late RecordingPrinter printer;
    late _DrivenLetters letters;
    late MemoryLetterDraftStore drafts;
    late FixedClipboard clipboard;
    late ProviderContainer container;
    // Stands in for the screen: closed, the form is left.
    late ProviderSubscription<LetterFormState> onScreen;
    final form = letterFormViewModelProvider(_fresh);

    LetterFormState state() => container.read(form);
    LetterFormViewModel letter() => container.read(form.notifier);
    AppFailure? shownFailure() => container.read(appMessengerProvider)?.failure;
    List<Letter> list() => container.read(lettersProvider).requireValue;

    /// Stands in for the screen: while it watches, the form is kept.
    Future<ProviderSubscription<LetterFormState>> open(
      LetterStart start,
    ) async {
      final watching = container.listen(
        letterFormViewModelProvider(start),
        (_, _) {},
      );
      addTearDown(() {
        if (!watching.closed) watching.close();
      });
      // What the form starts from arrives a moment after it opens.
      await pumpEventQueue();
      return watching;
    }

    void fillIn() => letter()
      ..setName('Pema Lhamo')
      ..setBody(FormattedText.plain(_wording));

    /// Fills in the form and draws the letter for checking.
    Future<void> toPreview() async {
      fillIn();
      await letter().previewLetter();
    }

    /// Types [digits] into "Change number" and uses them.
    Future<bool> useNumber(String digits) {
      letter()
        ..editNumber()
        ..setNumberInput(digits);
      return letter().applyNumber();
    }

    setUp(() async {
      printer = RecordingPrinter();
      drafts = MemoryLetterDraftStore();
      clipboard = FixedClipboard();
      var made = 0;
      container = await createSignedInContainer(
        overrides: [
          documentPrinterProvider.overrideWithValue(printer),
          letterRepositoryProvider.overrideWith(
            (ref) => letters = _DrivenLetters(),
          ),
          letterDraftStoreProvider.overrideWithValue(drafts),
          clipboardReaderProvider.overrideWithValue(clipboard),
          newIdProvider.overrideWithValue(() => 'request-${++made}'),
        ],
      );
      container.read(letterRepositoryProvider);
      await container.read(lettersProvider.future);
      onScreen = await open(_fresh);
      addTearDown(container.read(appMessengerProvider.notifier).dismiss);
    });

    group('what it says', () {
      test('starts empty, valid for a year from today', () {
        expect(state().name, '');
        expect(state().body.isBlank, isTrue);
        expect(state().validUntil, DateTime(2027, 9, 30));
        expect(state().datePicked, isFalse);
      });

      test('needs a name and something to say before it is drawn', () async {
        await letter().previewLetter();

        expect(state().issues, {
          LetterField.name: ValidationIssue.letterNameRequired,
          LetterField.body: ValidationIssue.letterBodyRequired,
        });
        expect(state().preview, isNull);
        expect(letters.previewed, isEmpty);

        // Each is forgiven as it is put right.
        letter().setName('Pema Lhamo');
        expect(state().issues.keys, [LetterField.body]);
        letter().setBody(FormattedText.plain(_wording));
        expect(state().issues, isEmpty);
      });

      test('is made out to a member picked from the matches', () async {
        final members = await container.read(membersProvider.future);
        final tenzin = members.first;
        final matching = container.listen(
          letterMemberMatchesProvider(_fresh),
          (_, _) {},
        );
        addTearDown(matching.close);

        // Two letters match half a temple; three are a name.
        letter().setName(tenzin.nameEn.substring(0, 2));
        expect(matching.read(), isEmpty);
        letter().setName(tenzin.nameEn.substring(0, 4));
        expect(matching.read(), contains(tenzin));

        letter().pickMember(tenzin);
        expect(state().name, tenzin.nameEn);
        expect(state().memberId, tenzin.id);
        expect(matching.read(), isEmpty);

        // A name typed over theirs is no longer that member.
        letter().setName('${tenzin.nameEn} Jr');
        expect(state().memberId, isNull);
      });

      test('takes its wording from what was copied, tidied', () async {
        clipboard.copied = 'First paragraph.\r\nSecond paragraph.  \r\n';

        expect(await letter().pasteBody(), isTrue);

        expect(state().body.toLines().map((line) => line.text), [
          'First paragraph.',
          '',
          'Second paragraph.',
        ]);
      });

      test('says when there is nothing to paste', () async {
        clipboard.copied = null;
        expect(await letter().pasteBody(), isFalse);
        clipboard.copied = '  \n ';
        expect(await letter().pasteBody(), isFalse);

        expect(state().body.isBlank, isTrue);
      });

      test('takes its wording from an earlier letter', () async {
        await letter().useWordingOf(list().first);

        final lines = state().body.toLines();
        expect(lines.first.text, contains('Tenzin Dolma'));
        expect(lines.first.runs[1].marks, {TextMark.bold});
        expect(lines[1].isEmpty, isTrue);
      });

      test(
        'keeps what was written while an earlier letter was fetched',
        () async {
          letters.holding = Completer();

          final fetching = letter().useWordingOf(list().first);
          // The button shows it is on its way.
          expect(state().busy, isTrue);
          letter().setBody(FormattedText.plain('Written meanwhile.'));
          letters.holding!.complete();
          await fetching;

          expect(state().body.text, 'Written meanwhile.');
          expect(state().busy, isFalse);
        },
      );

      test('holds until the day that is picked', () {
        letter().setValidUntil(DateTime(2027, 7, 16, 9));

        expect(state().validUntil, DateTime(2027, 7, 16));
        expect(state().datePicked, isTrue);
      });
    });

    group('the preview', () {
      test('is drawn from the form and saves nothing', () async {
        letter()
          ..setName('  Pema Lhamo ')
          ..setBody(FormattedText.plain('$_wording\n\nThank you.'))
          ..setValidUntil(DateTime(2027, 7, 16));
        await letter().previewLetter();

        final request = letters.previewed.single;
        expect(request.id, 'request-1');
        expect(request.name, 'Pema Lhamo');
        expect(request.validUntil, DateTime(2027, 7, 16));
        expect(request.body.map((line) => line.text), [
          _wording,
          '',
          'Thank you.',
        ]);
        expect(request.number, isNull);
        expect(state().preview!.number, '1004');
        expect(state().previewed, same(request));
        expect(state().busy, isFalse);
        expect(letters.issued, isEmpty);
        expect(list().map((l) => l.number), _seeded);
      });

      test('is drawn as a picture of its page', () async {
        final page = container.listen(
          letterFormPageProvider(_fresh),
          (_, _) {},
        );
        addTearDown(page.close);
        expect(
          await container.read(letterFormPageProvider(_fresh).future),
          isNull,
        );

        await toPreview();

        final drawn = await container.read(
          letterFormPageProvider(_fresh).future,
        );
        expect(drawn!.bytes, frontPage);
        expect(printer.drawn.single, state().preview!.pdf);
      });

      test('goes back to the form with everything as it was', () async {
        await toPreview();

        letter().backToDetails();

        expect(state().preview, isNull);
        expect(state().previewed, isNull);
        expect(state().name, 'Pema Lhamo');
        expect(state().body.text, _wording);
      });

      test('says how many lines too long the body is, on the form', () async {
        letter()
          ..setName('Pema Lhamo')
          ..setBody(FormattedText.plain(List.filled(28, 'A line.').join('\n')));
        await letter().previewLetter();

        expect(state().tooLong, 3);
        expect(state().preview, isNull);
        expect(shownFailure(), isNull);

        // Shortening it takes the message away.
        letter().setBody(FormattedText.plain('A line.'));
        expect(state().tooLong, isNull);
      });

      test('shows what the backend says about a field beside it', () async {
        letter()
          ..setName('Pema Lhamo')
          ..setBody(FormattedText.plain('བཀྲ་ཤིས་བདེ་ལེགས།'));
        await letter().previewLetter();

        expect(state().issues, {
          LetterField.body: ValidationIssue.letterBodyUnsupported,
        });
        expect(state().preview, isNull);
        expect(shownFailure(), isNull);
      });

      test('says so in a toast when it cannot be drawn at all', () async {
        fillIn();
        letters.failWith = const NetworkFailure();

        await letter().previewLetter();

        expect(shownFailure(), isA<NetworkFailure>());
        expect(state().preview, isNull);
        expect(state().busy, isFalse);
      });
    });

    group('where it sits on the page', () {
      /// How many empty lines the last letter drawn starts with.
      int drawnDown() =>
          letters.previewed.last.body.takeWhile((line) => line.isEmpty).length;

      test('starts at the top, with the room under it known', () async {
        await toPreview();

        expect(state().linesDown, 0);
        // One line of the 25 is used.
        expect(state().lowest, 24);
      });

      test(
        'moves down and up a line at a time, drawn again each time',
        () async {
          await toPreview();

          await letter().moveDown();
          await letter().moveDown();
          expect(state().linesDown, 2);
          expect(drawnDown(), 2);
          expect(letters.previewed.last.body.last.text, _wording);
          expect(state().previewed, same(letters.previewed.last));
          // The room is the same wherever in it the letter sits.
          expect(state().lowest, 24);

          await letter().moveUp();
          expect(state().linesDown, 1);
          expect(drawnDown(), 1);
          expect(letters.previewed, hasLength(4));
        },
      );

      test('goes to the middle of its room in one step', () async {
        await toPreview();

        await letter().moveToMiddle();

        expect(state().linesDown, 12);
        expect(drawnDown(), 12);
        expect(letters.previewed, hasLength(2));
      });

      test('stops at the top and at the last line it fits on', () async {
        await toPreview();

        await letter().moveUp();
        expect(state().linesDown, 0);
        expect(letters.previewed, hasLength(1));

        for (var tap = 0; tap < 30; tap++) {
          await letter().moveDown();
        }
        expect(state().linesDown, 24);
        expect(state().preview!.spare, 0);
        expect(state().tooLong, isNull);
      });

      test('draws twice for taps made while it is being drawn', () async {
        await toPreview();
        letters.holding = Completer();

        final first = letter().moveDown();
        unawaited(letter().moveDown());
        unawaited(letter().moveDown());
        expect(state().linesDown, 3);
        expect(state().busy, isTrue);
        letters.holding!.complete();
        await first;

        // The first tap, then where the taps ended up.
        expect(letters.previewed, hasLength(3));
        expect(drawnDown(), 3);
        expect(state().busy, isFalse);
      });

      test('stays put while the letter is being issued', () async {
        await toPreview();
        letters.holding = Completer();

        final saving = letter().save();
        expect(state().issuing, isTrue);
        await letter().moveDown();
        await letter().moveToMiddle();
        expect(state().linesDown, 0);
        letters.holding!.complete();
        await saving;

        expect(state().issuing, isFalse);
        expect(letters.previewed, hasLength(1));
        expect(letters.issued.single.body.first.text, _wording);
      });

      test('is where the letter is issued', () async {
        await toPreview();
        await letter().moveToMiddle();

        await letter().save();

        final sent = letters.issued.single;
        expect(sent.body.takeWhile((line) => line.isEmpty), hasLength(12));
        expect(sent, same(state().previewed));
      });

      test('is kept while the words are changed', () async {
        await toPreview();
        await letter().moveDown();
        letter().backToDetails();

        letter().setBody(FormattedText.plain('$_wording\n\nThank you.'));
        await letter().previewLetter();

        expect(state().linesDown, 1);
        expect(drawnDown(), 1);
      });

      test('moves up as far as it must when the words grow', () async {
        await toPreview();
        for (var tap = 0; tap < 20; tap++) {
          await letter().moveDown();
        }
        letter().backToDetails();

        // Ten lines, where there was room for five under the old place.
        letter().setBody(
          FormattedText.plain(List.filled(10, 'A line.').join('\n')),
        );
        await letter().previewLetter();

        expect(state().tooLong, isNull);
        expect(state().preview, isNotNull);
        expect(state().linesDown, 15);
        expect(state().preview!.spare, 0);
      });

      test('goes back to what is shown if it cannot be drawn again', () async {
        await toPreview();
        await letter().moveDown();
        letters.failWith = const NetworkFailure();

        await letter().moveDown();

        expect(shownFailure(), isA<NetworkFailure>());
        expect(state().linesDown, 1);
        expect(state().preview, isNotNull);
      });

      test('is copied with the wording of a letter that sat lower', () async {
        await toPreview();
        await letter().moveToMiddle();
        await letter().save();
        final issued = state().issued!.letter;
        letter().startAnother();
        await pumpEventQueue();
        expect(state().linesDown, 0);

        await letter().useWordingOf(issued);

        expect(state().linesDown, 12);
        expect(state().body.text, _wording);
      });
    });

    group('its number', () {
      test('can be typed by hand, and the letter is drawn again', () async {
        await toPreview();

        expect(await useNumber('001950'), isTrue);

        expect(state().number, '1950');
        expect(state().preview!.number, '1950');
        expect(letters.previewed.last.number, '1950');
        expect(state().previewed, same(letters.previewed.last));
      });

      test('is left to the temple when the one shown is kept', () async {
        await toPreview();

        expect(await useNumber('1004'), isTrue);

        expect(state().number, isNull);
        expect(letters.previewed, hasLength(1));
      });

      test('must be digits above zero', () async {
        await toPreview();

        for (final typed in ['', '0', 'A7', '-4']) {
          expect(await useNumber(typed), isFalse, reason: typed);
          expect(state().issues, {
            LetterField.number: ValidationIssue.letterNumberInvalid,
          });
        }
        expect(letters.previewed, hasLength(1));
        expect(state().preview!.number, '1004');
      });

      test(
        'that another letter carries issues nothing and says whose',
        () async {
          await toPreview();
          await useNumber('1002');

          await letter().save();

          expect(state().taken?.name, 'Karma Dhondup');
          expect(state().taken?.number, '1002');
          expect(state().issued, isNull);
          expect(list().map((l) => l.number), _seeded);

          letter().dismissTaken();
          expect(state().taken, isNull);
          expect(state().preview, isNotNull);
        },
      );
    });

    group('a number typed by hand', () {
      test('can be given back to the temple', () async {
        await toPreview();
        await useNumber('1002');
        await letter().save();
        letter().dismissTaken();

        expect(await letter().useNextNumber(), isTrue);

        expect(state().number, isNull);
        expect(state().preview!.number, '1004');
        await letter().save();
        expect(state().issued!.letter.number, '1004');
      });

      test('stays if the letter cannot be drawn without it', () async {
        await toPreview();
        await useNumber('1950');
        letters.failWith = const NetworkFailure();

        expect(await letter().useNextNumber(), isFalse);

        expect(state().number, '1950');
      });
    });

    group('issuing it', () {
      test(
        'sends exactly what was previewed and adds it to the list',
        () async {
          await toPreview();
          final previewed = state().previewed;

          await letter().save();

          expect(letters.issued.single, same(previewed));
          final issued = state().issued!.letter;
          expect(issued.id, 'request-1');
          expect(issued.number, '1004');
          expect(issued.name, 'Pema Lhamo');
          expect(issued.validUntil, DateTime(2027, 9, 30));
          expect(list().first, issued);
          expect(list(), hasLength(4));
        },
      );

      test('does nothing before a preview', () async {
        fillIn();

        await letter().save();

        expect(letters.issued, isEmpty);
        expect(state().issued, isNull);
      });

      test(
        'keeps its id when tried again, and takes a new one after',
        () async {
          await toPreview();
          letters.failWith = const NetworkFailure();
          await letter().save();
          expect(shownFailure(), isA<NetworkFailure>());
          expect(state().issued, isNull);
          // The preview is still there to try again from.
          expect(state().preview, isNotNull);

          letters.failWith = null;
          await letter().save();
          expect(state().issued, isNotNull);

          letter().startAnother();
          await pumpEventQueue();
          await toPreview();
          await letter().save();

          expect(letters.issued.map((request) => request.id), [
            'request-1',
            'request-1',
            'request-2',
          ]);
          expect(list(), hasLength(5));
        },
      );

      test(
        'tells the list even if the form is left before the answer',
        () async {
          await toPreview();
          letters.holding = Completer();

          final saving = letter().save();
          onScreen.close();
          await pumpEventQueue();
          letters.holding!.complete();
          await saving;

          expect(list().first.name, 'Pema Lhamo');
          expect(drafts.drafts, isEmpty);
        },
      );

      test('prints and shares the page that was issued', () async {
        await toPreview();
        await letter().save();
        final pdf = state().issued!.pdf;

        await letter().printLetter('Support letter 1004');
        await letter().shareLetter('Support letter 1004');

        // As a full page, not at the size of a card.
        expect(printer.printedPages, {'Support letter 1004': pdf});
        expect(printer.printed, isEmpty);
        expect(printer.shared, {'Support letter 1004.pdf': pdf});
      });
    });

    group('a half-written one', () {
      test('is kept on the device as it is written', () {
        letter()
          ..setName('Pema Lhamo')
          ..setBody(FormattedText.plain(_wording))
          ..setValidUntil(DateTime(2027, 7, 16));

        final draft = drafts.drafts.values.single;
        expect(draft.name, 'Pema Lhamo');
        expect(draft.body.single.text, _wording);
        expect(draft.validUntil, DateTime(2027, 7, 16));
      });

      test('keeps no date until one is picked', () {
        letter().setName('Pema Lhamo');

        expect(drafts.drafts.values.single.validUntil, isNull);
      });

      test('is there when the form is opened again', () async {
        fillIn();
        container.invalidate(form);
        await pumpEventQueue();

        expect(state().name, 'Pema Lhamo');
        expect(state().body.text, _wording);
        // A new form, so a new letter.
        expect(state().requestId, 'request-2');
      });

      test('is forgotten once nothing is left of it', () {
        fillIn();

        letter()
          ..setName('')
          ..setBody(const FormattedText.empty());

        expect(drafts.drafts, isEmpty);
      });

      test('is forgotten once it is issued', () async {
        await toPreview();
        expect(drafts.drafts, hasLength(1));

        await letter().save();

        expect(drafts.drafts, isEmpty);
      });

      test(
        'does not get in the way of a letter that starts from a name',
        () async {
          fillIn();
          const LetterStart forSonam = (name: 'Sonam Wangmo', like: null);
          final started = letterFormViewModelProvider(forSonam);

          await open(forSonam);

          expect(container.read(started).name, 'Sonam Wangmo');
          expect(container.read(started).body.isBlank, isTrue);

          // Nor does that letter get in its way: written and issued, the
          // half-written one is still waiting as it was.
          final other = container.read(started.notifier);
          other.setBody(FormattedText.plain('Other words.'));
          await other.previewLetter();
          await other.save();
          expect(container.read(started).issued, isNotNull);
          final draft = drafts.drafts.values.single;
          expect(draft.name, 'Pema Lhamo');
          expect(draft.body.single.text, _wording);
        },
      );

      test('does not get in the way of one worded like another', () async {
        fillIn();
        const LetterStart likeAnother = (name: null, like: 'letter-2026-08-21');
        final started = letterFormViewModelProvider(likeAnother);

        await open(likeAnother);

        expect(container.read(started).name, '');
        expect(
          container.read(started).body.toLines().first.text,
          contains('Karma Dhondup'),
        );
        // Copying that wording did not overwrite the half-written letter.
        expect(drafts.drafts.values.single.body.single.text, _wording);
      });
    });
  });

  group('letters on file', () {
    late RecordingPrinter printer;
    late MemoryFileCache cache;
    late ProviderContainer container;

    setUp(() async {
      printer = RecordingPrinter();
      cache = MemoryFileCache();
      container = await createSignedInContainer(
        overrides: [
          documentPrinterProvider.overrideWithValue(printer),
          fileCacheProvider.overrideWithValue(cache),
        ],
      );
      await container.read(lettersProvider.future);
    });

    test('are listed newest first, and say when they have run out', () {
      final letters = container.read(lettersProvider).requireValue;

      expect(letters.map((l) => (l.name, l.number)), [
        ('Tenzin Dolma', '1003'),
        ('Karma Dhondup', '1002'),
        ('Pema Lhamo', '1001'),
      ]);
      expect(letters.map((l) => l.expiredOn(testNow)), [false, false, true]);
      // The last day itself still holds.
      expect(letters.first.expiredOn(letters.first.validUntil), isFalse);
    });

    test('are found by name or by number', () {
      final listed = container.listen(letterListProvider, (_, _) {});
      addTearDown(listed.close);
      List<String> shown() =>
          listed.read().requireValue.visible.map((l) => l.name).toList();
      final search = container.read(letterSearchProvider.notifier);

      search.setQuery('karma');
      expect(shown(), ['Karma Dhondup']);
      search.setQuery('1001');
      expect(shown(), ['Pema Lhamo']);
      search.setQuery('nobody');
      expect(shown(), isEmpty);
      expect(listed.read().requireValue.total, 3);
      search.setQuery(' ');
      expect(shown(), hasLength(3));
    });

    test('are a temple’s own', () async {
      container
          .read(currentTempleIdProvider.notifier)
          .select(FakeTemples.drolmaId);

      final letters = await container.read(lettersProvider.future);

      expect(letters, hasLength(3));
    });

    test('are drawn once, and the picture kept on the device', () async {
      final onFile = letterOnFileProvider('letter-2026-09-25');
      final watching = container.listen(onFile, (_, _) {});
      addTearDown(watching.close);

      final first = await container.read(onFile.future);
      expect(first.onFile.letter.name, 'Tenzin Dolma');
      expect(first.page.bytes, frontPage);
      expect(cache.files.keys, ['letters/letter-2026-09-25-1.png']);

      container.invalidate(onFile);
      await container.read(onFile.future);

      expect(printer.drawn, hasLength(1));
    });

    test('are not found by an id no letter has', () async {
      final onFile = letterOnFileProvider('nowhere');
      final watching = container.listen(onFile, (_, _) {});
      addTearDown(watching.close);

      await expectLater(
        container.read(onFile.future),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('are printed as a page and shared as a file', () async {
      final onFile = letterOnFileProvider('letter-2026-09-25');
      final watching = container.listen(onFile, (_, _) {});
      addTearDown(watching.close);
      final pdf = (await container.read(onFile.future)).onFile.pdf;
      final actions = container.read(letterActionsProvider);

      await actions.printLetter('letter-2026-09-25', 'Support letter 1003');
      await actions.shareLetter('letter-2026-09-25', 'Support letter 1003');

      expect(printer.printedPages, {'Support letter 1003': pdf});
      expect(printer.shared, {'Support letter 1003.pdf': pdf});
    });

    test('take in a letter issued elsewhere, once', () {
      final issued = Letter(
        id: 'new',
        number: '1004',
        name: 'Sonam Wangmo',
        validUntil: DateTime(2027, 9, 30),
        issuedOn: DateTime(2026, 9, 30),
      );
      final letters = container.read(lettersProvider.notifier);

      letters
        ..put(issued)
        ..put(issued);

      expect(
        container.read(lettersProvider).requireValue.map((l) => l.number),
        ['1004', ..._seeded],
      );
    });
  });

  group('who may write one', () {
    test('is whoever has the Support letter card: admins', () {
      expect(Role.values.where((role) => role.canIssueLetters), [Role.admin]);
    });

    test('opens a new letter from a name or from another letter', () {
      expect(AppRoutes.newLetter(), '/home/letters/new');
      expect(
        AppRoutes.newLetter(name: 'Sonam Wangmo'),
        '/home/letters/new?name=Sonam+Wangmo',
      );
      expect(AppRoutes.newLetter(like: 'a-1'), '/home/letters/new?like=a-1');
    });
  });

  group('FakeLetterRepository', () {
    late FakeLetterRepository letters;

    LetterRequest request({
      String id = 'one',
      String? number,
      List<TextLine>? body,
      DateTime? validUntil,
    }) => LetterRequest(
      id: id,
      name: 'Pema Lhamo',
      validUntil: validUntil ?? DateTime(2027, 9, 30),
      body:
          body ??
          const [
            TextLine([TextRun(_wording)]),
          ],
      number: number,
    );

    setUp(() => letters = FakeLetterRepository(Duration.zero, () => testNow));

    test('issues one letter, however often it is asked', () async {
      final first = await letters.issue(_temple, request()) as LetterIssued;
      final again = await letters.issue(_temple, request()) as LetterIssued;

      expect(again.issued, same(first.issued));
      expect(await letters.fetchLetters(_temple), hasLength(4));
    });

    test('skips a number typed by hand when the count reaches it', () async {
      await letters.issue(_temple, request(id: 'typed', number: '1004'));
      final next =
          await letters.issue(_temple, request(id: 'next')) as LetterIssued;

      expect(next.issued.letter.number, '1005');
    });

    test('refuses a number another letter carries', () async {
      final outcome = await letters.issue(_temple, request(number: '1001'));

      expect((outcome as LetterNumberTaken).name, 'Pema Lhamo');
      expect(await letters.fetchLetters(_temple), hasLength(3));
    });

    test('says how many lines of room a preview leaves', () async {
      const line = TextLine([TextRun('A line.')]);
      final body = [const TextLine([]), const TextLine([]), line, line];

      final outcome = await letters.preview(_temple, request(body: body));

      expect((outcome as LetterPreviewed).preview.spare, 21);
    });

    test('counts the lines a body runs over, empty ones too', () async {
      const line = TextLine([TextRun('A line.')]);
      final body = [
        ...List.filled(20, line),
        ...List.filled(7, const TextLine([])),
      ];

      final outcome = await letters.preview(_temple, request(body: body));

      expect((outcome as LetterTooLong).lines, 2);
      await expectLater(
        letters.issue(_temple, request(body: body)),
        throwsA(
          isA<ValidationFailure>().having(
            (failure) => failure.issues,
            'issues',
            {'body': ValidationIssue.letterBodyTooLong},
          ),
        ),
      );
    });

    test('refuses a last day that has passed', () async {
      await expectLater(
        letters.preview(_temple, request(validUntil: DateTime(2026, 9, 29))),
        throwsA(
          isA<ValidationFailure>().having(
            (failure) => failure.issues,
            'issues',
            {'validUntil': ValidationIssue.letterDatePast},
          ),
        ),
      );
      // Today is not the past.
      final today = await letters.preview(
        _temple,
        request(validUntil: DateTime(2026, 9, 30)),
      );
      expect(today, isA<LetterPreviewed>());
    });

    test('gives a letter back with what it says and a page to print', () async {
      final [newest, ...] = await letters.fetchLetters(_temple);

      final onFile = await letters.fetch(_temple, newest);

      expect(onFile.letter, newest);
      expect(onFile.body.first.text, contains(newest.name));
      // A PDF, by its first bytes.
      expect(utf8.decode(onFile.pdf.take(5).toList()), '%PDF-');
    });
  });

  group('FirebaseLetterRepository', () {
    final pdf = Uint8List.fromList(utf8.encode('%PDF-letter'));
    final letterJson = {
      'id': 'request-1',
      'number': '195960',
      'name': 'Pema Lhamo',
      'memberId': null,
      'validUntil': '2027-07-16',
      'issuedOn': '2026-09-30',
    };
    final file = {'pdf': base64Encode(pdf)};
    final bodyJson = [
      {
        'runs': [
          {'text': 'She is a '},
          {'text': 'dedicated', 'bold': true, 'underline': true},
          {'text': ' member.'},
        ],
      },
      {'runs': <Object?>[]},
      {
        'bullet': true,
        'runs': [
          {'text': 'Cooking', 'italic': true},
        ],
      },
    ];
    const body = [
      TextLine([
        TextRun('She is a '),
        TextRun('dedicated', marks: {TextMark.bold, TextMark.underline}),
        TextRun(' member.'),
      ]),
      TextLine([]),
      TextLine([
        TextRun('Cooking', marks: {TextMark.italic}),
      ], bullet: true),
    ];
    final request = LetterRequest(
      id: 'request-1',
      name: 'Pema Lhamo',
      validUntil: DateTime(2027, 7, 16),
      body: body,
    );
    late MemoryFileCache cache;

    setUp(() => cache = MemoryFileCache());

    test('lists the temple’s letters', () async {
      final backend = FakeBackend({
        'letters': [
          letterJson,
          {...letterJson, 'id': 'b', 'number': '195959', 'memberId': 'm-7'},
        ],
      });

      final letters = await FirebaseLetterRepository(
        backend,
        cache,
      ).fetchLetters('dl');

      expect(backend.calls, ['letters-list']);
      expect(backend.inputs.single, {'templeId': 'dl'});
      expect(
        letters.first,
        Letter(
          id: 'request-1',
          number: '195960',
          name: 'Pema Lhamo',
          validUntil: DateTime(2027, 7, 16),
          issuedOn: DateTime(2026, 9, 30),
        ),
      );
      expect(letters.last.memberId, 'm-7');
    });

    test('asks for a preview with the body as the backend takes it', () async {
      final backend = FakeBackend({
        'number': '195960',
        'spare': 22,
        'file': file,
      });

      final outcome = await FirebaseLetterRepository(
        backend,
        cache,
      ).preview('dl', request);

      expect(backend.calls, ['letters-preview']);
      // No id: a preview makes nothing. No number: the temple's next.
      expect(backend.inputs.single, {
        'templeId': 'dl',
        'name': 'Pema Lhamo',
        'validUntil': '2027-07-16',
        'body': bodyJson,
      });
      final preview = (outcome as LetterPreviewed).preview;
      expect(preview.number, '195960');
      expect(preview.spare, 22);
      expect(preview.pdf, pdf);
      expect(cache.files, isEmpty);
    });

    test('sends a typed number and the member it is for', () async {
      final backend = FakeBackend({'number': '777', 'file': file});
      final forMember = LetterRequest(
        id: 'request-1',
        name: 'Pema Lhamo',
        memberId: 'm-7',
        validUntil: DateTime(2027, 7, 16),
        body: body,
        number: '777',
      );

      await FirebaseLetterRepository(backend, cache).preview('dl', forMember);

      expect(backend.inputs.single, containsPair('number', '777'));
      expect(backend.inputs.single, containsPair('memberId', 'm-7'));
    });

    test('reads a body too long for the page as an answer', () async {
      final backend = FakeBackend({
        'tooLong': {'lines': 3},
      });

      final outcome = await FirebaseLetterRepository(
        backend,
        cache,
      ).preview('dl', request);

      expect((outcome as LetterTooLong).lines, 3);
    });

    test(
      'issues a letter and keeps its page and wording on the device',
      () async {
        final backend = FakeBackend({'letter': letterJson, 'file': file});
        final letters = FirebaseLetterRepository(backend, cache);

        final outcome = await letters.issue('dl', request);

        expect(backend.calls, ['letters-create']);
        expect(backend.inputs.single, containsPair('id', 'request-1'));
        final issued = (outcome as LetterIssued).issued;
        expect(issued.letter.number, '195960');
        expect(issued.pdf, pdf);
        expect(cache.files.keys, [
          'letters/request-1.pdf',
          'letters/request-1.json',
        ]);

        // Looked at again, nothing is asked of the backend.
        final onFile = await letters.fetch('dl', issued.letter);
        expect(backend.calls, ['letters-create']);
        expect(onFile.pdf, pdf);
        expect(onFile.body, body);
      },
    );

    test(
      'reads a number that is taken as an answer, and keeps nothing',
      () async {
        final backend = FakeBackend({
          'taken': {'name': 'Karma Dhondup', 'number': '195959'},
        });

        final outcome = await FirebaseLetterRepository(
          backend,
          cache,
        ).issue('dl', request);

        expect((outcome as LetterNumberTaken).name, 'Karma Dhondup');
        expect(outcome.number, '195959');
        expect(cache.files, isEmpty);
      },
    );

    test('fetches a letter it does not have, once', () async {
      final backend = FakeBackend({
        'letter': letterJson,
        'body': bodyJson,
        'file': file,
      });
      final letters = FirebaseLetterRepository(backend, cache);
      final letter = letterFromJson(letterJson);

      final first = await letters.fetch('dl', letter);
      final again = await letters.fetch('dl', letter);

      expect(backend.calls, ['letters-get']);
      expect(backend.inputs.single, {
        'templeId': 'dl',
        'letterId': 'request-1',
      });
      expect(first.body, body);
      expect(again.body, body);
      expect(again.pdf, pdf);
    });

    test('waits longer than the backend takes to draw a letter', () async {
      final backend = FakeBackend({'number': '1', 'file': file});

      await FirebaseLetterRepository(backend, cache).preview('dl', request);

      expect(backend.timeouts.single, greaterThan(const Duration(seconds: 60)));
    });

    test('reads what the backend says about a field', () async {
      final backend = FakeBackend(const {})
        ..error = FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'The request was not valid.',
          details: {
            'fields': {
              'body': 'letterBodyUnsupported',
              'validUntil': 'letterDatePast',
            },
          },
        );

      await expectLater(
        FirebaseLetterRepository(backend, cache).preview('dl', request),
        throwsA(
          isA<ValidationFailure>()
              .having((failure) => failure.issues, 'issues', {
                'body': ValidationIssue.letterBodyUnsupported,
                'validUntil': ValidationIssue.letterDatePast,
              }),
        ),
      );
    });
  });

  group('a draft on the device', () {
    test('comes back as it was kept', () {
      final draft = LetterDraft(
        name: 'Pema Lhamo',
        memberId: 'm-7',
        validUntil: DateTime(2027, 7, 16),
        body: const [
          TextLine([
            TextRun('She is '),
            TextRun('kind', marks: {TextMark.italic}),
          ]),
          TextLine([]),
          TextLine([TextRun('Cooking')], bullet: true),
        ],
      );

      final read = draftFromJson(draftToJson(draft))!;

      expect(read.name, 'Pema Lhamo');
      expect(read.memberId, 'm-7');
      expect(read.validUntil, DateTime(2027, 7, 16));
      expect(read.body, draft.body);
    });

    test('leaves out what was never chosen', () {
      final read = draftFromJson(draftToJson(const LetterDraft(name: 'Pema')))!;

      expect(read.memberId, isNull);
      expect(read.validUntil, isNull);
      expect(read.body, isEmpty);
    });

    test('is no draft if it cannot be read', () {
      expect(draftFromJson('not json'), isNull);
      expect(draftFromJson('{"v": 2, "name": "Pema"}'), isNull);
      expect(draftFromJson('{"v": 1}'), isNull);
    });

    test('is nothing worth keeping without a name or a word', () {
      expect(const LetterDraft().isEmpty, isTrue);
      expect(const LetterDraft(name: ' ').isEmpty, isTrue);
      expect(const LetterDraft(name: 'Pema').isEmpty, isFalse);
      expect(
        const LetterDraft(
          body: [
            TextLine([TextRun('Hello')]),
          ],
        ).isEmpty,
        isFalse,
      );
    });
  });

  group('the letter screens', () {
    setUpAll(loadAppFonts);

    Future<ProviderContainer> app(
      WidgetTester tester, {
      required RecordingPrinter printer,
      FixedClipboard? clipboard,
      Size size = const Size(390, 844),
      String templeId = FakeTemples.jangchubId,
    }) async {
      tester.setScreenSize(size);
      final container = createContainer(
        overrides: [
          documentPrinterProvider.overrideWithValue(printer),
          // A letter on file keeps its page here; a test has no device folder.
          fileCacheProvider.overrideWithValue(MemoryFileCache()),
          clipboardReaderProvider.overrideWithValue(
            clipboard ?? FixedClipboard(),
          ),
        ],
      );
      await tester.pumpApp(container);
      await tester.runAsync(() => signIn(container, templeId: templeId));
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> go(
      WidgetTester tester,
      ProviderContainer container,
      String location,
    ) async {
      container.read(routerProvider).go(location);
      await tester.pumpAndSettle();
    }

    String path(ProviderContainer container) => container
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .toString();

    testWidgets('Home’s Support letter card opens the letters, newest first', (
      tester,
    ) async {
      final container = await app(tester, printer: RecordingPrinter());

      await tester.ensureVisible(find.text('Support letter'));
      await tester.tap(find.text('Support letter'));
      await tester.pumpAndSettle();

      expect(path(container), AppRoutes.letters);
      expect(find.text('Support letters'), findsOneWidget);
      expect(find.text('3 letters'), findsOneWidget);
      final names = ['Tenzin Dolma', 'Karma Dhondup', 'Pema Lhamo'];
      final tops = [
        for (final name in names) tester.getTopLeft(find.text(name)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      // Said in words, not by colour alone.
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('searching narrows the list and says when nothing matches', (
      tester,
    ) async {
      final container = await app(tester, printer: RecordingPrinter());
      await go(tester, container, AppRoutes.letters);

      await tester.enterText(find.byType(TextField), 'karma');
      await tester.pumpAndSettle();
      expect(find.text('Karma Dhondup'), findsOneWidget);
      expect(find.text('Tenzin Dolma'), findsNothing);
      expect(find.text('1 found'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pumpAndSettle();
      expect(find.textContaining('No letter matches'), findsOneWidget);
    });

    testWidgets('a letter is pasted, previewed, issued and printed', (
      tester,
    ) async {
      final printer = RecordingPrinter();
      final clipboard = FixedClipboard()..copied = '$_wording\n\nThank you.';
      final container = await app(
        tester,
        printer: printer,
        clipboard: clipboard,
      );
      await go(tester, container, AppRoutes.letters);

      await tester.tap(find.text('New letter'));
      await tester.pumpAndSettle();
      expect(path(container), '/home/letters/new');
      expect(find.text('Valid until Sep 30, 2027'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Sonam Wangmo');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Paste'));
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Thank you.'), findsOneWidget);
      // With something written there is nothing to paste over.
      expect(find.text('Paste'), findsNothing);

      await tester.tapAndWaitFor(
        'Preview letter',
        find.text('Check the letter'),
      );
      expect(find.text('No. 1004'), findsOneWidget);
      expect(find.byType(LetterPageView), findsOneWidget);

      await tester.tapAndWaitFor('Issue letter', find.text('Letter issued'));
      expect(find.textContaining('Sonam Wangmo · No. 1004'), findsOneWidget);

      await tester.tap(find.text('Print letter'));
      await tester.pumpAndSettle();
      expect(printer.printedPages.keys, ['Support letter 1004']);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(path(container), AppRoutes.letters);
      expect(find.text('Sonam Wangmo'), findsOneWidget);
      expect(find.text('4 letters'), findsOneWidget);
    });

    testWidgets('what is missing is said beside the field it belongs to', (
      tester,
    ) async {
      final container = await app(tester, printer: RecordingPrinter());
      await go(tester, container, AppRoutes.newLetter());

      await tester.tap(find.text('Preview letter'));
      await tester.pumpAndSettle();

      expect(find.text('Please say who the letter is for.'), findsOneWidget);
      expect(
        find.text('Please paste or type what the letter says.'),
        findsOneWidget,
      );
      expect(find.text('Check the letter'), findsNothing);
    });

    testWidgets('a body too long for the page says by how many lines', (
      tester,
    ) async {
      final clipboard = FixedClipboard()
        ..copied = List.filled(14, 'A line.').join('\n\n');
      final container = await app(
        tester,
        printer: RecordingPrinter(),
        clipboard: clipboard,
      );
      await go(tester, container, AppRoutes.newLetter(name: 'Sonam Wangmo'));

      await tester.ensureVisible(find.text('Paste'));
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      // The letter fills the screen: what follows it is out of sight.
      final button = tester.getRect(find.text('Preview letter'));
      expect(
        tester.getRect(find.textContaining('Valid until')).top,
        greaterThan(button.top),
      );
      await tester.tap(find.text('Preview letter'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 lines too long'), findsOneWidget);
      expect(find.text('Check the letter'), findsNothing);
      // So what is wrong with it is brought into view, above the button.
      final said = tester.getRect(find.textContaining('2 lines too long'));
      expect(said.top, greaterThanOrEqualTo(0));
      expect(said.bottom, lessThanOrEqualTo(button.top));
    });

    testWidgets(
      'a number another letter carries is said, and another asked for',
      (tester) async {
        final clipboard = FixedClipboard()..copied = _wording;
        final container = await app(
          tester,
          printer: RecordingPrinter(),
          clipboard: clipboard,
        );
        await go(tester, container, AppRoutes.newLetter(name: 'Sonam Wangmo'));
        await tester.ensureVisible(find.text('Paste'));
        await tester.tap(find.text('Paste'));
        await tester.pumpAndSettle();
        await tester.tapAndWaitFor(
          'Preview letter',
          find.text('Check the letter'),
        );

        await tester.ensureVisible(find.text('Change number'));
        await tester.tap(find.text('Change number'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '1002');
        await tester.tapAndWaitFor('Use this number', find.text('No. 1002'));

        await tester.tap(find.text('Issue letter'));
        await tester.pumpAndSettle();
        expect(find.text('No. 1002 is already used'), findsOneWidget);
        expect(find.textContaining('Karma Dhondup'), findsOneWidget);

        await tester.tap(find.text('Choose another'));
        await tester.pumpAndSettle();
        expect(find.text('Letter number'), findsOneWidget);
        expect(find.text('Letter issued'), findsNothing);
      },
    );

    testWidgets('a short letter is moved down the page from its preview', (
      tester,
    ) async {
      final clipboard = FixedClipboard()..copied = _wording;
      final container = await app(
        tester,
        printer: RecordingPrinter(),
        clipboard: clipboard,
      );
      const LetterStart forSonam = (name: 'Sonam Wangmo', like: null);
      LetterFormState state() =>
          container.read(letterFormViewModelProvider(forSonam));
      bool enabled(String label) =>
          tester
              .widget<InkWell>(
                find.ancestor(
                  of: find.text(label),
                  matching: find.byType(InkWell),
                ),
              )
              .onTap !=
          null;
      await go(tester, container, AppRoutes.newLetter(name: 'Sonam Wangmo'));
      await tester.ensureVisible(find.text('Paste'));
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      await tester.tapAndWaitFor(
        'Preview letter',
        find.text('Check the letter'),
      );

      // At the top there is nowhere higher to go.
      expect(find.text('Where the text sits on the page'), findsOneWidget);
      expect(enabled('Move up'), isFalse);
      expect(enabled('Move down'), isTrue);

      await tester.tapAndWaitFor('Move down', find.byType(LetterPageView));
      expect(state().linesDown, 1);
      expect(enabled('Move up'), isTrue);

      await tester.tapAndWaitFor(
        'Put it in the middle',
        find.byType(LetterPageView),
      );
      expect(state().linesDown, 12);
      expect(enabled('Put it in the middle'), isFalse);

      // It is issued where it was left.
      await tester.tapAndWaitFor('Issue letter', find.text('Letter issued'));
      expect(
        state().previewed!.body.takeWhile((line) => line.isEmpty),
        hasLength(12),
      );
    });

    testWidgets('the last day is picked from a calendar', (tester) async {
      final container = await app(tester, printer: RecordingPrinter());
      await go(tester, container, AppRoutes.newLetter());

      await tester.ensureVisible(find.text('Change'));
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use Sep 15, 2027'));
      await tester.pumpAndSettle();

      expect(find.text('Valid until Sep 15, 2027'), findsOneWidget);
      expect(find.text('One year from today'), findsNothing);
    });

    testWidgets('a letter on file opens with its page, to print or share', (
      tester,
    ) async {
      final printer = RecordingPrinter();
      final container = await app(tester, printer: printer);
      await go(tester, container, AppRoutes.letters);

      await tester.tap(find.text('Karma Dhondup'));
      await tester.pumpAndSettle();
      expect(find.byType(LetterPageView), findsOneWidget);
      expect(path(container), '/home/letters/letter-2026-08-21');
      expect(find.text('No. 1002'), findsOneWidget);

      await tester.tap(find.text('Print letter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(printer.printedPages.keys, ['Support letter 1002']);
      expect(printer.shared.keys, ['Support letter 1002.pdf']);

      await tester.tap(find.text('Write another like this'));
      await tester.pumpAndSettle();
      expect(path(container), '/home/letters/new?like=letter-2026-08-21');
      expect(find.textContaining('Karma Dhondup has been'), findsOneWidget);
    });

    testWidgets('on a tablet the letter opens beside the list', (tester) async {
      final container = await app(
        tester,
        printer: RecordingPrinter(),
        size: const Size(1180, 820),
      );
      await go(tester, container, AppRoutes.letters);
      expect(find.text('Choose a letter to see it here.'), findsOneWidget);

      await tester.tapAndWaitFor('Tenzin Dolma', find.byType(LetterPageView));

      expect(path(container), AppRoutes.letters);
      expect(find.text('Karma Dhondup'), findsOneWidget);
    });

    testWidgets('Volunteer Hours starts a letter for whoever may write one', (
      tester,
    ) async {
      final container = await app(tester, printer: RecordingPrinter());
      await go(tester, container, AppRoutes.hours);

      await tester.tap(find.text('Write a thank-you letter'));
      await tester.pumpAndSettle();

      expect(path(container), startsWith('/home/letters/new?name='));
      expect(find.text('New support letter'), findsOneWidget);
      final name = Uri.parse(path(container)).queryParameters['name']!;
      expect(find.widgetWithText(TextField, name), findsOneWidget);
    });

    testWidgets('Write another, after a letter begun from a name, is empty', (
      tester,
    ) async {
      final clipboard = FixedClipboard()..copied = _wording;
      final container = await app(
        tester,
        printer: RecordingPrinter(),
        clipboard: clipboard,
      );
      await go(tester, container, AppRoutes.newLetter(name: 'Sonam Wangmo'));
      await tester.ensureVisible(find.text('Paste'));
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      await tester.tapAndWaitFor(
        'Preview letter',
        find.text('Check the letter'),
      );
      await tester.tapAndWaitFor('Issue letter', find.text('Letter issued'));

      await tester.ensureVisible(find.text('Write another'));
      await tester.tap(find.text('Write another'));
      await tester.pumpAndSettle();

      expect(path(container), '/home/letters/new');
      expect(find.text('New support letter'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Sonam Wangmo'), findsNothing);
      expect(find.text('Paste'), findsOneWidget);
    });

    for (final (device, size) in const [
      ('a phone', Size(390, 844)),
      ('a tablet', Size(1180, 820)),
    ]) {
      testWidgets('the preview, the page opened large and the issued letter '
          'fit on $device in Tibetan with Simple Mode', (tester) async {
        final bo = lookupAppLocalizations(const Locale('bo'));
        final clipboard = FixedClipboard()..copied = _wording;
        final container = await app(
          tester,
          printer: RecordingPrinter(),
          clipboard: clipboard,
          size: size,
        );
        container.read(preferencesProvider.notifier)
          ..setLanguage(AppLanguage.tibetan)
          ..setSimpleMode(true);
        await tester.pumpAndSettle();
        await go(tester, container, AppRoutes.newLetter(name: 'Sonam Wangmo'));

        await tester.ensureVisible(find.text(bo.formatPaste));
        await tester.tap(find.text(bo.formatPaste));
        await tester.pumpAndSettle();
        await tester.tapAndWaitFor(
          bo.letterPreviewCta,
          find.text(bo.letterPreviewTitle),
        );
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.byType(LetterPageView));
        await tester.tap(find.byType(LetterPageView));
        await tester.pumpAndSettle();
        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(bo.commonDone));
        await tester.pumpAndSettle();

        await tester.tapAndWaitFor(
          bo.letterIssueCta,
          find.text(bo.letterReadyTitle),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Volunteer Hours offers no letter to anyone else', (
      tester,
    ) async {
      // Dolma is the accountant at Drolma Ling, with no Support letter card.
      final container = await app(
        tester,
        printer: RecordingPrinter(),
        templeId: FakeTemples.drolmaId,
      );
      await go(tester, container, AppRoutes.hours);

      expect(path(container), AppRoutes.hours);
      expect(find.text('Write a thank-you letter'), findsNothing);
    });
  });
}

/// The demo's own letters, driven by the test: it notes each letter it is
/// asked for, can be held mid-call, and can be told to fail.
class _DrivenLetters implements LetterRepository {
  final LetterRepository _inner = FakeLetterRepository(
    Duration.zero,
    () => testNow,
  );
  final previewed = <LetterRequest>[];
  final issued = <LetterRequest>[];
  AppFailure? failWith;
  Completer<void>? holding;

  @override
  Future<List<Letter>> fetchLetters(String templeId) =>
      _inner.fetchLetters(templeId);

  @override
  Future<LetterPreviewOutcome> preview(
    String templeId,
    LetterRequest request,
  ) async {
    previewed.add(request);
    await holding?.future;
    if (failWith case final failure?) throw failure;
    return _inner.preview(templeId, request);
  }

  @override
  Future<LetterOutcome> issue(String templeId, LetterRequest request) async {
    issued.add(request);
    await holding?.future;
    if (failWith case final failure?) throw failure;
    return _inner.issue(templeId, request);
  }

  @override
  Future<LetterOnFile> fetch(String templeId, Letter letter) async {
    await holding?.future;
    return _inner.fetch(templeId, letter);
  }
}
