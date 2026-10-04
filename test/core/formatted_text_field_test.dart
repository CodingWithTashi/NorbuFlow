import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/core/models/formatted_text.dart';
import 'package:norbu_flow/core/services/clipboard_reader.dart';
import 'package:norbu_flow/core/theme/accent_preset.dart';
import 'package:norbu_flow/core/theme/app_colors.dart';
import 'package:norbu_flow/core/theme/app_theme.dart';
import 'package:norbu_flow/core/widgets/app_page.dart';
import 'package:norbu_flow/core/widgets/app_text_field.dart';
import 'package:norbu_flow/core/widgets/buttons.dart';
import 'package:norbu_flow/core/widgets/formatted_text_field.dart';
import 'package:norbu_flow/l10n/generated/app_localizations.dart';

import '../support/clipboard.dart';

const _phone = Size(390, 844);
const _tablet = Size(900, 1180);
const _bold = TextMark.bold;

/// The fonts the box is set in, so that words are as wide as on a device.
/// Loaded here: `test_app.dart` would bring the whole app in with it.
Future<void> _loadFonts() async {
  const families = {
    'AtkinsonHyperlegibleNext': [
      'AtkinsonHyperlegibleNext.ttf',
      'AtkinsonHyperlegibleNext-Italic.ttf',
    ],
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  EditableText box(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText));
  TextEditingValue shown(WidgetTester tester) => box(tester).controller.value;

  /// What the keyboard does: the box's text becomes [text], the caret at
  /// [caret] or the selection from [from] to it.
  Future<void> keyboard(
    WidgetTester tester,
    String text,
    int caret, {
    int? from,
  }) async {
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: from ?? caret,
          extentOffset: caret,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> focus(WidgetTester tester) async {
    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();
  }

  /// The toolbar's button for [label].
  Finder button(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(InkWell));

  /// None of the words on the buttons is cut short.
  void expectWhole(WidgetTester tester, List<String> labels) {
    for (final label in labels) {
      final word = tester.renderObject<RenderParagraph>(find.text(label));
      expect(
        word.getMaxIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(word.size.width),
        reason: label,
      );
    }
  }

  /// Whether the toolbar has [label] on, as a screen reader hears it.
  void expectLit(WidgetTester tester, String label, bool on) => expect(
    tester.getSemantics(find.bySemanticsLabel(label)),
    isSemantics(
      label: label,
      isButton: true,
      hasToggledState: true,
      isToggled: on,
      hasTapAction: true,
    ),
    reason: label,
  );

  group('the box', () {
    testWidgets('keeps the caret where it was typed, with the screen handing '
        'back what it was told', (tester) async {
      final host = await _pump(tester, FormattedText.plain('Hello world'));
      await focus(tester);

      await keyboard(tester, 'HelXlo world', 4);
      expect(shown(tester).selection, const TextSelection.collapsed(offset: 4));
      await keyboard(tester, 'HelXYlo world', 5);

      expect(shown(tester).text, 'HelXYlo world');
      expect(shown(tester).selection, const TextSelection.collapsed(offset: 5));
      expect(host.value.text, 'HelXYlo world');
      expect(host.changes, hasLength(2));
    });

    testWidgets('leaves what the keyboard is still composing alone', (
      tester,
    ) async {
      await _pump(tester, FormattedText.plain('Hello '));
      await focus(tester);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Hello wor',
          selection: TextSelection.collapsed(offset: 9),
          composing: TextRange(start: 6, end: 9),
        ),
      );
      await tester.pump();

      expect(shown(tester).composing, const TextRange(start: 6, end: 9));
    });

    testWidgets('takes a new value from the screen, and does not report it '
        'back', (tester) async {
      final host = await _pump(tester, FormattedText.plain('Hello'));

      host.restore(FormattedText.fromPaste('Dear all,\nThank you.'));
      await tester.pump();

      expect(shown(tester).text, 'Dear all,\nThank you.');
      expect(shown(tester).selection.baseOffset, 20);
      expect(host.changes, isEmpty);
    });

    testWidgets('draws bold, italic and underlined stretches as such', (
      tester,
    ) async {
      await _pump(
        tester,
        FormattedText.fromLines(const [
          TextLine([
            TextRun('plain '),
            TextRun('bold', marks: {TextMark.bold}),
            TextRun(' '),
            TextRun('both', marks: {TextMark.italic, TextMark.underline}),
          ]),
        ]),
      );

      final drawn = box(tester).controller.buildTextSpan(
        context: tester.element(find.byType(EditableText)),
        withComposing: false,
      );

      final spans = drawn.children!.cast<TextSpan>();
      expect(
        [for (final span in spans) span.text],
        ['plain ', 'bold', ' ', 'both'],
      );
      expect(spans[0].style, isNull);
      expect(spans[1].style!.fontWeight, FontWeight.w700);
      expect(spans[1].style!.fontStyle, isNull);
      expect(spans[2].style, isNull);
      expect(spans[3].style!.fontStyle, FontStyle.italic);
      expect(spans[3].style!.decoration, TextDecoration.underline);
      expect(spans[3].style!.fontWeight, isNull);
    });

    testWidgets('underlines what the keyboard is composing, as any box does', (
      tester,
    ) async {
      await _pump(tester, FormattedText.plain('Hello'));
      await focus(tester);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Hello',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        ),
      );
      await tester.pump();

      final drawn = box(tester).controller.buildTextSpan(
        context: tester.element(find.byType(EditableText)),
        withComposing: true,
      );

      expect(
        drawn.children!.cast<TextSpan>().single.style!.decoration,
        TextDecoration.underline,
      );
    });

    testWidgets('is paper in dark mode too, with a caret and underlines that '
        'show on it', (tester) async {
      await _pump(tester, FormattedText.plain('Hello'), dark: true);
      await focus(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.fillColor, AppPalette.paper);
      expect(box(tester).style.color, AppPalette.paperInk);
      expect(box(tester).style.decorationColor, AppPalette.paperInk);
      expect(box(tester).cursorColor, AccentPreset.maroon.color);
      expect(
        box(tester).selectionColor,
        AccentPreset.maroon.color.withValues(alpha: 0.25),
      );
      expect(box(tester).textCapitalization, TextCapitalization.sentences);
      expect(box(tester).maxLines, isNull);
      expect(field.spellCheckConfiguration, isNull);
    });

    testWidgets('shows what is wrong under it', (tester) async {
      await _pump(
        tester,
        FormattedText.plain('Hello'),
        errorText: 'The letter is too long to fit the page.',
      );

      expect(
        find.descendant(
          of: find.byType(FieldError),
          matching: find.text('The letter is too long to fit the page.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Wording'), findsOneWidget);
    });
  });

  group('the rules of the box', () {
    testWidgets('carry a list on at Enter, and tell the screen once', (
      tester,
    ) async {
      final host = await _pump(tester, FormattedText.plain('• Hello'));
      await focus(tester);

      await keyboard(tester, '• Hello\n', 8);

      expect(shown(tester).text, '• Hello\n• ');
      expect(
        shown(tester).selection,
        const TextSelection.collapsed(offset: 10),
      );
      expect(host.changes.single.text, '• Hello\n• ');
    });

    testWidgets('tidy what is pasted from the keyboard', (tester) async {
      final host = await _pump(tester, const FormattedText.empty());
      await focus(tester);

      const copied = '  Dear all,\r\n\r\n\r\n\r\nThank\u00A0you.  \n';
      await keyboard(tester, copied, copied.length);

      expect(shown(tester).text, 'Dear all,\n\nThank you.');
      expect(shown(tester).selection.baseOffset, 21);
      expect(host.value, FormattedText.plain('Dear all,\n\nThank you.'));
    });
  });

  group('the toolbar', () {
    testWidgets('is lit for what the selection has, and says so to a screen '
        'reader', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        FormattedText.plain('plain bold').toggled(_bold, 6, 10),
        size: _tablet,
      );
      await focus(tester);

      await keyboard(tester, 'plain bold', 10, from: 6);
      expectLit(tester, 'Bold', true);
      expectLit(tester, 'Italic', false);
      expectLit(tester, 'Underline', false);
      expectLit(tester, 'List', false);

      // Plain words in the selection as well: not bold all over.
      await keyboard(tester, 'plain bold', 10, from: 3);
      expectLit(tester, 'Bold', false);
      semantics.dispose();
    });

    testWidgets('makes the selection bold, and leaves the box its focus and '
        'its selection', (tester) async {
      final host = await _pump(tester, FormattedText.plain('Hello world'));
      await focus(tester);
      await keyboard(tester, 'Hello world', 5, from: 0);

      // A mouse, which takes the focus from a box it clicks outside of.
      await tester.tap(find.text('Bold'), kind: PointerDeviceKind.mouse);
      await tester.pump();

      expect(host.value.ranges, [const MarkRange(_bold, 0, 5)]);
      expect(host.changes, hasLength(1));
      expect(box(tester).focusNode.hasFocus, isTrue);
      expect(
        shown(tester).selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );

      // And plain again.
      await tester.tap(find.text('Bold'));
      await tester.pump();
      expect(host.value.ranges, isEmpty);
    });

    testWidgets('makes the word bold when the caret is inside one', (
      tester,
    ) async {
      final host = await _pump(tester, FormattedText.plain('Hello world'));
      await focus(tester);
      await keyboard(tester, 'Hello world', 8);

      await tester.tap(find.text('Bold'));
      await tester.pump();

      expect(host.value.ranges, [const MarkRange(_bold, 6, 11)]);
      expect(shown(tester).selection, const TextSelection.collapsed(offset: 8));
    });

    testWidgets('sets what is typed next when the caret is in no word', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final host = await _pump(tester, FormattedText.plain('Hello '));
      await focus(tester);
      await keyboard(tester, 'Hello ', 6);

      await tester.tap(find.text('Bold'));
      await tester.pump();
      expectLit(tester, 'Bold', true);
      // Nothing has changed yet.
      expect(host.changes, isEmpty);

      await keyboard(tester, 'Hello w', 7);
      await keyboard(tester, 'Hello wo', 8);
      expect(host.value.ranges, [const MarkRange(_bold, 6, 8)]);
      expectLit(tester, 'Bold', true);

      // Switched off again at the end of the bold word.
      await tester.tap(find.text('Bold'));
      await tester.pump();
      expectLit(tester, 'Bold', false);
      await keyboard(tester, 'Hello wo.', 9);
      expect(host.value.ranges, [const MarkRange(_bold, 6, 8)]);
      semantics.dispose();
    });

    testWidgets('forgets what was set for the next letters when the caret '
        'moves', (tester) async {
      final semantics = tester.ensureSemantics();
      final host = await _pump(tester, FormattedText.plain('Hello '));
      await focus(tester);
      await keyboard(tester, 'Hello ', 6);
      await tester.tap(find.text('Italic'));
      await tester.pump();
      expectLit(tester, 'Italic', true);

      await keyboard(tester, 'Hello ', 0);
      expectLit(tester, 'Italic', false);
      await keyboard(tester, 'xHello ', 1);

      expect(host.value.ranges, isEmpty);
      semantics.dispose();
    });

    testWidgets('tapped before the box was ever used gives the box the '
        'focus, and what is typed at its end the mark', (tester) async {
      final semantics = tester.ensureSemantics();
      final host = await _pump(
        tester,
        FormattedText.plain('Hello '),
        size: _tablet,
      );

      await tester.tap(find.text('Bold'));
      await tester.pump();
      expect(box(tester).focusNode.hasFocus, isTrue);
      expectLit(tester, 'Bold', true);

      await keyboard(tester, 'Hello w', 7);
      expect(host.value.ranges, [const MarkRange(_bold, 6, 7)]);
      semantics.dispose();
    });

    testWidgets('makes the line a list item and back with List', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final host = await _pump(tester, FormattedText.plain('Hello\nworld'));
      await focus(tester);
      await keyboard(tester, 'Hello\nworld', 8);

      await tester.tap(find.text('List'));
      await tester.pump();

      expect(host.value.text, 'Hello\n• world');
      expect(
        shown(tester).selection,
        const TextSelection.collapsed(offset: 10),
      );
      expectLit(tester, 'List', true);
      expect(box(tester).focusNode.hasFocus, isTrue);

      await tester.tap(find.text('List'));
      await tester.pump();
      expect(host.value.text, 'Hello\nworld');
      expect(shown(tester).selection, const TextSelection.collapsed(offset: 8));
      expectLit(tester, 'List', false);
      semantics.dispose();
    });

    testWidgets('on a phone takes the place of the screen\'s button while '
        'the box is in use, with Done to put it back', (tester) async {
      final host = await _pump(tester, FormattedText.plain('Hello'));
      expect(host.accessory, isNull);
      expect(find.text('Bold'), findsNothing);
      expect(find.text('Preview'), findsOneWidget);

      await focus(tester);

      expect(host.accessory, isNotNull);
      for (final label in ['Bold', 'Italic', 'Underline', 'List', 'Done']) {
        expect(
          find.descendant(
            of: find.byType(BottomActionBar),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.text('Preview'), findsNothing);
      // Each is a full-size target.
      for (final label in ['Bold', 'Italic', 'Underline', 'List', 'Done']) {
        final size = tester.getSize(button(label));
        expect(size.height, greaterThanOrEqualTo(56), reason: label);
        expect(size.width, greaterThanOrEqualTo(48), reason: label);
      }

      await tester.tap(find.text('Done'));
      await tester.pump();

      expect(box(tester).focusNode.hasFocus, isFalse);
      expect(host.accessory, isNull);
      expect(find.text('Preview'), findsOneWidget);
    });

    testWidgets('on a tablet sits above the box, and the screen keeps its '
        'button', (tester) async {
      final host = await _pump(
        tester,
        FormattedText.plain('Hello'),
        size: _tablet,
      );
      await focus(tester);

      expect(host.accessory, isNull);
      expect(find.text('Done'), findsNothing);
      expect(find.text('Preview'), findsOneWidget);
      expect(
        tester.getBottomLeft(button('Bold')).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(TextField)).dy),
      );
      expect(
        tester.getTopLeft(button('Bold')).dy,
        greaterThan(tester.getBottomLeft(find.text('Wording')).dy),
      );
    });

    testWidgets('has room for its words on a phone, in Simple Mode as well', (
      tester,
    ) async {
      // Every button on, which is when its word is widest.
      var value = FormattedText.plain('• Hello');
      for (final mark in TextMark.values) {
        value = value.toggled(mark, 2, 7);
      }
      await _pump(tester, value, scale: AppTheme.simpleModeTextScale);
      await focus(tester);
      await keyboard(tester, '• Hello', 7, from: 2);

      expectWhole(tester, ['Bold', 'Italic', 'Underline', 'List', 'Done']);
    });
  });

  group('an empty box', () {
    testWidgets('offers Paste and the screen\'s other ways to fill it, until '
        'there is something in it', (tester) async {
      final host = await _pump(
        tester,
        const FormattedText.empty(),
        clipboard: FixedClipboard('Dear all,\r\nThank you.'),
        emptyActions: const ['Use an earlier letter'],
      );
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Use an earlier letter'), findsOneWidget);

      await tester.tap(find.text('Paste'));
      await tester.pump();

      expect(host.pasted, 1);
      expect(shown(tester).text, 'Dear all,\nThank you.');
      expect(find.text('Paste'), findsNothing);
      expect(find.text('Use an earlier letter'), findsNothing);
      // The screen filled it: the box had nothing to report.
      expect(host.changes, isEmpty);
    });

    testWidgets('offers them again once it is emptied, bullets or not', (
      tester,
    ) async {
      await _pump(
        tester,
        FormattedText.plain('Hello'),
        clipboard: FixedClipboard(),
        emptyActions: const ['Use an earlier letter'],
      );
      expect(find.text('Paste'), findsNothing);
      await focus(tester);

      await keyboard(tester, '• ', 2);

      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Use an earlier letter'), findsOneWidget);
    });

    testWidgets('has no Paste on a screen that does not offer it', (
      tester,
    ) async {
      await _pump(tester, const FormattedText.empty());

      expect(find.text('Paste'), findsNothing);
    });
  });

  group('an undo', () {
    Future<void> undo(WidgetTester tester, LogicalKeyboardKey with_) async {
      await tester.sendKeyDownEvent(with_);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(with_);
      await tester.pump();
    }

    /// Wording typed by hand, selected and deleted by mistake.
    Future<_HostState> deleted(WidgetTester tester) async {
      final host = await _pump(
        tester,
        FormattedText.plain('One.\nTwo.').toggled(_bold, 0, 3),
      );
      await focus(tester);
      await keyboard(tester, 'One.\nTwo.', 9);
      // The field's history keeps a state half a second after it changed.
      await tester.pump(const Duration(milliseconds: 600));
      await keyboard(tester, '', 0);
      await tester.pump(const Duration(milliseconds: 600));
      expect(host.value.text, isEmpty);
      return host;
    }

    testWidgets(
      'brings the text back just as it was, less its marks',
      (tester) async {
        final host = await deleted(tester);

        await undo(tester, LogicalKeyboardKey.metaLeft);

        expect(shown(tester).text, 'One.\nTwo.');
        expect(host.value, FormattedText.plain('One.\nTwo.'));
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('that cannot be told from typing is tidied as a paste is, '
        'after it has landed', (tester) async {
      final host = await deleted(tester);

      await undo(tester, LogicalKeyboardKey.controlLeft);

      expect(shown(tester).text, 'One.\n\nTwo.');
      expect(host.value, FormattedText.plain('One.\n\nTwo.'));
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('the box in Tibetan with Simple Mode', () {
    testWidgets('lays out on a phone, empty and in use', (tester) async {
      await _pump(
        tester,
        const FormattedText.empty(),
        tibetan: true,
        scale: AppTheme.tibetanTextScale * AppTheme.simpleModeTextScale,
        clipboard: FixedClipboard(),
        emptyActions: const ['སྔོན་གྱི་ཡི་གེ་ཞིག་བེད་སྤྱོད།'],
        errorText: 'ཡི་གེ་འདི་ཤོག་ངོས་གཅིག་ལ་མི་ཤོང་།',
      );
      expect(find.text('སྦྱར་བ།'), findsOneWidget);

      await focus(tester);
      const typed = '• བཀྲ་ཤིས་བདེ་ལེགས། Thank you';
      await keyboard(tester, typed, typed.length, from: 2);
      for (final label in ['སྦོམ་པོ།', 'གསེག་མ།', 'འོག་ཐིག']) {
        await tester.tap(find.text(label));
        await tester.pump();
      }

      // Every button on, and no word cut short.
      expectWhole(tester, [
        'སྦོམ་པོ།',
        'གསེག་མ།',
        'འོག་ཐིག',
        'ཐོ།',
        'ཚར་སོང་།',
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lays out on a tablet', (tester) async {
      await _pump(
        tester,
        const FormattedText.empty(),
        size: _tablet,
        tibetan: true,
        scale: AppTheme.tibetanTextScale * AppTheme.simpleModeTextScale,
        clipboard: FixedClipboard(),
        emptyActions: const ['སྔོན་གྱི་ཡི་གེ་ཞིག་བེད་སྤྱོད།'],
      );
      await focus(tester);

      expect(find.text('སྦོམ་པོ།'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the device\'s clipboard', () {
    const reader = DeviceClipboardReader();
    final device =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    void copied(Object? Function() answer) {
      device.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData' ? answer() : null,
      );
      addTearDown(
        () => device.setMockMethodCallHandler(SystemChannels.platform, null),
      );
    }

    test('gives the text that was copied', () async {
      copied(() => {'text': 'Dear all,'});

      expect(await reader.text(), 'Dear all,');
    });

    test(
      'gives nothing when nothing was, or the device will not say',
      () async {
        copied(() => null);
        expect(await reader.text(), isNull);

        copied(() => {'text': ''});
        expect(await reader.text(), isNull);

        copied(() => throw PlatformException(code: 'denied'));
        expect(await reader.text(), isNull);
      },
    );
  });
}

/// A screen with only the box on it, which keeps what the box reports and
/// hands it back, as a view model does.
class _Host extends StatefulWidget {
  const _Host({
    required this.initial,
    this.clipboard,
    this.emptyActions = const [],
    this.errorText,
  });

  final FormattedText initial;
  final ClipboardReader? clipboard;
  final List<String> emptyActions;
  final String? errorText;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late FormattedText value = widget.initial;
  final changes = <FormattedText>[];
  Widget? accessory;
  var pasted = 0;

  /// A new value from the screen's side: a draft restored, a paste.
  void restore(FormattedText next) => setState(() => value = next);

  Future<void> _paste() async {
    pasted++;
    final copied = await widget.clipboard!.text();
    restore(FormattedText.fromPaste(copied ?? ''));
  }

  @override
  Widget build(BuildContext context) {
    return FormattedTextField(
      value: value,
      onChanged: (next) => setState(() {
        value = next;
        changes.add(next);
      }),
      label: 'Wording',
      hint: 'Type or paste the letter here',
      errorText: widget.errorText,
      onPaste: widget.clipboard == null ? null : _paste,
      emptyActions: [
        for (final label in widget.emptyActions)
          SecondaryButton(label: label, onPressed: () {}),
      ],
      builder: (context, field, accessory) {
        this.accessory = accessory;
        return AppPage(
          bottom:
              accessory ?? PrimaryButton(label: 'Preview', onPressed: () {}),
          child: field,
        );
      },
    );
  }
}

/// The box on a screen of its own, in the app's theme.
Future<_HostState> _pump(
  WidgetTester tester,
  FormattedText value, {
  Size size = _phone,
  bool dark = false,
  bool tibetan = false,
  double scale = 1,
  ClipboardReader? clipboard,
  List<String> emptyActions = const [],
  String? errorText,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(tibetan ? 'bo' : 'en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        _EnglishFor<MaterialLocalizations>(
          DefaultMaterialLocalizations.delegate,
        ),
        _EnglishFor<WidgetsLocalizations>(DefaultWidgetsLocalizations.delegate),
        _EnglishFor<CupertinoLocalizations>(
          DefaultCupertinoLocalizations.delegate,
        ),
      ],
      theme: AppTheme.build(
        brightness: dark ? Brightness.dark : Brightness.light,
        accent: AccentPreset.maroon,
        tibetan: tibetan,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: _Host(
            initial: value,
            clipboard: clipboard,
            emptyActions: emptyActions,
            errorText: errorText,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.state<_HostState>(find.byType(_Host));
}

/// Flutter's own widgets have no Tibetan: they speak English, as in the app.
class _EnglishFor<T> extends LocalizationsDelegate<T> {
  const _EnglishFor(this.english);

  final LocalizationsDelegate<T> english;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'bo';

  @override
  Future<T> load(Locale locale) => english.load(const Locale('en'));

  @override
  bool shouldReload(_EnglishFor<T> old) => false;
}
