import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/core/models/formatted_text.dart';

const _bold = TextMark.bold;
const _italic = TextMark.italic;
const _underline = TextMark.underline;
const _signs = {'*': _bold, '/': _italic, '_': _underline};

const _grin = '\u{1F600}';
const _beam = '\u{1F601}';

/// Wording written with its marks: `*bold*`, `/italic/`, `_underlined_`.
FormattedText _marked(String source) {
  final text = StringBuffer();
  final open = <TextMark, int>{};
  final ranges = <(TextMark, int, int)>[];
  for (final unit in source.split('')) {
    final mark = _signs[unit];
    if (mark == null) {
      text.write(unit);
    } else if (open.remove(mark) case final start?) {
      ranges.add((mark, start, text.length));
    } else {
      open[mark] = text.length;
    }
  }
  var value = FormattedText.plain(text.toString());
  for (final (mark, start, end) in ranges) {
    value = value.toggled(mark, start, end);
  }
  return value;
}

/// [value] written the same way: where a mark starts or stops, its sign.
String _drawn(FormattedText value) {
  final drawn = StringBuffer();
  for (var at = 0; at <= value.text.length; at++) {
    for (final MapEntry(key: sign, value: mark) in _signs.entries) {
      final edge = value.ranges.any(
        (range) => range.mark == mark && (range.start == at || range.end == at),
      );
      if (edge) drawn.write(sign);
    }
    if (at < value.text.length) drawn.write(value.text[at]);
  }
  return drawn.toString();
}

/// [typed] put in place of [start] to [end], as a keyboard does it: the
/// caret ends up after it.
TextChange _replace(
  FormattedText value,
  int start,
  int end,
  String typed, {
  Set<TextMark>? typing,
  bool rules = true,
}) => value.edited(
  text: value.text.replaceRange(start, end, typed),
  caret: start + typed.length,
  typing: typing,
  rules: rules,
);

TextChange _type(
  FormattedText value,
  int at,
  String typed, {
  Set<TextMark>? typing,
  bool rules = true,
}) => _replace(value, at, at, typed, typing: typing, rules: rules);

TextChange _delete(FormattedText value, int start, int end) =>
    _replace(value, start, end, '');

TextLine _line(String text, {bool bullet = false}) =>
    TextLine([TextRun(text)], bullet: bullet);

/// Whether [at] is between the two halves of an emoji.
bool _splits(String text, int at) =>
    at > 0 &&
    at < text.length &&
    text.codeUnitAt(at - 1) & 0xFC00 == 0xD800 &&
    text.codeUnitAt(at) & 0xFC00 == 0xDC00;

/// The ranges are in their normal form, whatever was done to get here.
void _expectSound(FormattedText value, String reason) {
  final text = value.text;
  // Mark by mark.
  final marks = [for (final range in value.ranges) range.mark.index];
  expect(marks, [...marks]..sort(), reason: reason);
  for (final mark in TextMark.values) {
    var before = -1;
    for (final range in value.ranges.where((range) => range.mark == mark)) {
      // In order, and not touching the one before: that would be one range.
      expect(range.start, greaterThan(before), reason: reason);
      expect(range.end, greaterThan(range.start), reason: reason);
      expect(range.end, lessThanOrEqualTo(text.length), reason: reason);
      expect(
        text.substring(range.start, range.end),
        isNot(contains('\n')),
        reason: reason,
      );
      expect(_splits(text, range.start), isFalse, reason: reason);
      expect(_splits(text, range.end), isFalse, reason: reason);
      before = range.end;
    }
  }
}

void main() {
  group('typing', () {
    test('inside a bold word is bold, and is left as the keyboard had it', () {
      final change = _type(_marked('a*bcd*e'), 3, 'X');

      expect(_drawn(change.value), 'a*bcXd*e');
      expect((change.start, change.end), (4, 4));
      expect(change.rewritten, isFalse);
    });

    test('at the end of a bold word carries on bold', () {
      expect(_drawn(_type(_marked('a*bcd*e'), 4, 'X').value), 'a*bcdX*e');
    });

    test('just before a bold word is plain, as what it follows is', () {
      expect(_drawn(_type(_marked('a*bcd*e'), 1, 'X').value), 'aX*bcd*e');
    });

    test('at the start of a line is plain, whatever the line begins with', () {
      final value = _marked('*ab*\n*cd*');

      expect(_drawn(_type(value, 0, 'X').value), 'X*ab*\n*cd*');
      expect(_drawn(_type(value, 3, 'X').value), '*ab*\nX*cd*');
    });

    test('does not carry marks over to the next line after Enter', () {
      final entered = _type(_marked('*ab*'), 2, '\n').value;
      expect(_drawn(entered), '*ab*\n');

      expect(_drawn(_type(entered, 3, 'c').value), '*ab*\nc');
      // A word broken in two stays as it was on both lines.
      expect(_drawn(_type(_marked('*ab*'), 1, '\n').value), '*a*\n*b*');
    });

    test('takes the marks set on the toolbar instead, when there are any', () {
      expect(
        _drawn(_type(_marked('ab'), 2, 'X', typing: {_bold}).value),
        'ab*X*',
      );
      // Bold switched off in the middle of a bold word.
      expect(
        _drawn(_type(_marked('*ab*'), 1, 'X', typing: {}).value),
        '*a*X*b*',
      );
      expect(
        _drawn(_type(_marked('*ab*'), 2, 'X', typing: {_italic}).value),
        '*ab*/X/',
      );
    });

    test('a bold word the keyboard corrects stays bold', () {
      final change = _marked(
        'the *teh* cat',
      ).edited(text: 'the the cat', caret: 7);

      expect(_drawn(change.value), 'the *the* cat');
      expect(change.rewritten, isFalse);
    });

    test('over a selection is set as the first character it replaces', () {
      final value = _marked('ab*cd*ef');

      expect(_drawn(_replace(value, 3, 5, 'X').value), 'ab*cX*f');
      expect(_drawn(_replace(value, 1, 3, 'X').value), 'aX*d*ef');
    });

    test('a word several keys at once, and unchanged by tidying, is typing '
        'too', () {
      final change = _type(_marked('*ab*'), 2, 'cd ');

      expect(_drawn(change.value), '*abcd *');
      expect(change.rewritten, isFalse);
    });

    test('with no change to the text changes nothing', () {
      final value = _marked('a*b*');
      final change = value.edited(text: 'ab', caret: 1);

      expect(change.value, value);
      expect((change.start, change.end, change.rewritten), (1, 1, false));
    });
  });

  group('deleting', () {
    test('across two bold words leaves what is left of them as one', () {
      final change = _delete(_marked('*ab*cd*ef*'), 1, 5);

      expect(_drawn(change.value), '*af*');
      expect(change.value.ranges, [const MarkRange(_bold, 0, 2)]);
      expect((change.start, change.rewritten), (1, false));
    });

    test('trims each mark to what is left of it', () {
      expect(_drawn(_delete(_marked('*ab*c/de/'), 1, 4).value), '*a*/e/');
      expect(_drawn(_delete(_marked('a*bc*d'), 1, 3).value), 'ad');
    });
  });

  group('a repeated letter', () {
    final value = _marked('a*a*a');

    test('typed goes where the caret says it went', () {
      FormattedText typedTo(int caret) =>
          value.edited(text: 'aaaa', caret: caret).value;

      expect(_drawn(typedTo(1)), 'aa*a*a');
      expect(_drawn(typedTo(2)), 'aa*a*a');
      expect(_drawn(typedTo(3)), 'a*aa*a');
      expect(_drawn(typedTo(4)), 'a*a*aa');
    });

    test('deleted is the one at the caret', () {
      FormattedText deletedAt(int caret) =>
          value.edited(text: 'aa', caret: caret).value;

      expect(_drawn(deletedAt(0)), '*a*a');
      expect(_drawn(deletedAt(1)), 'aa');
      expect(_drawn(deletedAt(2)), 'a*a*');
    });

    test('with no caret to go by is still an edit', () {
      final change = value.edited(text: 'aaaa', caret: -1);

      expect(change.value.text, 'aaaa');
      _expectSound(change.value, 'no caret');
    });
  });

  group('an emoji', () {
    test('replaced by another keeps its marks, with no half left over', () {
      final change = _marked('a*$_grin*b').edited(text: 'a${_beam}b', caret: 3);

      expect(change.value.text, 'a${_beam}b');
      expect(change.value.ranges, [const MarkRange(_bold, 1, 3)]);
    });

    test('is marked whole or not at all', () {
      final value = FormattedText.plain('a$_grin');

      expect(value.toggled(_bold, 0, 2).ranges, [const MarkRange(_bold, 0, 3)]);
      expect(value.toggled(_bold, 2, 3).ranges, isEmpty);
    });

    test('typed after bold text is bold in both its halves', () {
      final change = _type(_marked('*a*'), 1, _grin);

      expect(change.value.ranges, [const MarkRange(_bold, 0, 3)]);
      expect(change.rewritten, isFalse);
    });
  });

  group('a list', () {
    test('goes on with a new item when Enter is pressed in one', () {
      final change = _type(FormattedText.plain('• abcd'), 4, '\n');

      expect(change.value.text, '• ab\n• cd');
      expect((change.start, change.end), (7, 7));
      expect(change.rewritten, isTrue);

      final atEnd = _type(FormattedText.plain('• ab'), 4, '\n');
      expect(atEnd.value.text, '• ab\n• ');
      expect(atEnd.start, 7);
    });

    test('goes on as well when Enter comes with the keyboard\'s correction '
        'of the last word, which stays as it was set', () {
      final change = _marked('• *teh*').edited(text: '• the\n', caret: 6);

      expect(_drawn(change.value), '• *the*\n• ');
      expect((change.start, change.rewritten), (8, true));
      // On a plain line the two together are still only typing.
      final plain = _marked('*teh*').edited(text: 'the\n', caret: 4);
      expect(_drawn(plain.value), '*the*\n');
      expect(plain.rewritten, isFalse);
    });

    test('ends when Enter is pressed on an item with nothing in it', () {
      final change = _type(FormattedText.plain('• ab\n• '), 7, '\n');

      expect(change.value.text, '• ab\n');
      expect((change.start, change.end), (5, 5));
      expect(change.rewritten, isTrue);
    });

    test('gets an empty item above when Enter is pressed before a bullet', () {
      final change = _type(FormattedText.plain('• ab'), 0, '\n');

      expect(change.value.text, '• \n• ab');
      expect(change.start, 5);
    });

    test('takes what is typed before or inside a bullet after it', () {
      final value = FormattedText.plain('• ab');

      for (final at in [0, 1]) {
        final change = _type(value, at, 'x');
        expect(change.value.text, '• xab', reason: 'typed at $at');
        expect((change.start, change.rewritten), (3, true));
      }
    });

    test('loses the whole bullet to Backspace right after it', () {
      final change = _delete(FormattedText.plain('ab\n• cd'), 4, 5);

      expect(change.value.text, 'ab\ncd');
      expect((change.start, change.rewritten), (3, true));
      // And to a delete of the dot alone.
      expect(_delete(FormattedText.plain('• cd'), 0, 1).value.text, 'cd');
    });

    test('loses the bullet of an item joined onto the line before', () {
      final value = FormattedText.plain('ab\n• cd');

      final joined = _delete(value, 2, 3);
      expect(joined.value.text, 'abcd');
      expect(joined.start, 2);
      expect(_replace(value, 1, 3, 'x').value.text, 'axcd');
      // The line before deleted whole leaves the item an item.
      expect(_delete(value, 0, 3).value.text, '• cd');
      expect(_replace(value, 1, 3, '\n').value.text, 'a\n• cd');
    });

    test('has no marks on its bullets or on the breaks between lines', () {
      final value = _marked('*• ab\n• cd*');

      expect(_drawn(value), '• *ab*\n• *cd*');
      expect(value.marksAt(0, 9), {_bold});
      // So what is typed right after a bullet is plain.
      expect(_drawn(_type(_marked('• *ab*'), 2, 'X').value), '• X*ab*');
    });

    test('is not looked after when the rules are off', () {
      final change = _type(FormattedText.plain('• ab'), 4, '\n', rules: false);

      expect(change.value.text, '• ab\n');
      expect(change.rewritten, isFalse);
      expect(
        _type(FormattedText.plain('• ab'), 0, 'x', rules: false).value.text,
        'x• ab',
      );
    });
  });

  group('the List button', () {
    test('makes the line of the caret an item, and moves the caret along', () {
      final change = FormattedText.plain('ab\ncd').bulletsToggled(4, 4);

      expect(change.value.text, 'ab\n• cd');
      expect((change.start, change.end), (6, 6));
      expect(change.rewritten, isTrue);
    });

    test('makes every line the selection touches an item', () {
      final value = FormattedText.plain('ab\ncd');
      expect(value.bulletedAt(1, 4), isFalse);

      final change = value.bulletsToggled(1, 4);

      expect(change.value.text, '• ab\n• cd');
      expect((change.start, change.end), (3, 8));
      expect(change.value.bulletedAt(3, 8), isTrue);
    });

    test('makes them plain lines again when all of them are items', () {
      final change = FormattedText.plain('• ab\n• cd').bulletsToggled(3, 8);

      expect(change.value.text, 'ab\ncd');
      expect((change.start, change.end), (1, 4));
      // A caret inside a bullet ends up at the start of the line.
      final inside = FormattedText.plain('• ab').bulletsToggled(1, 1);
      expect((inside.value.text, inside.start), ('ab', 0));
    });

    test('adds to the lines that are not items yet when only some are', () {
      final value = FormattedText.plain('• ab\ncd');
      expect(value.bulletedAt(0, 7), isFalse);

      final change = value.bulletsToggled(0, 7);

      expect(change.value.text, '• ab\n• cd');
      expect((change.start, change.end), (0, 9));
    });

    test('leaves the empty lines between paragraphs alone', () {
      final value = FormattedText.plain('ab\n\ncd');

      expect(value.bulletsToggled(0, 6).value.text, '• ab\n\n• cd');
      expect(FormattedText.plain('• ab\n\n• cd').bulletedAt(0, 10), isTrue);
    });

    test('starts a list on an empty line', () {
      final change = const FormattedText.empty().bulletsToggled(0, 0);

      expect(change.value.text, '• ');
      expect((change.start, change.end), (2, 2));
      expect(change.value.bulletedAt(2, 2), isTrue);
    });

    test('does not touch a line the selection only reaches the start of', () {
      final change = FormattedText.plain('ab\ncd').bulletsToggled(0, 3);

      expect(change.value.text, '• ab\ncd');
      expect((change.start, change.end), (2, 5));
    });

    test('keeps the marks on the words', () {
      final change = _marked('a*b*\n/cd/').bulletsToggled(0, 5);

      expect(_drawn(change.value), '• a*b*\n• /cd/');
      expect(_drawn(change.value.bulletsToggled(0, 9).value), 'a*b*\n/cd/');
    });
  });

  group('a paste into the box', () {
    test('of several lines arrives tidied and plain', () {
      final change = _type(_marked('*ab*'), 2, ' one\r\n two\t three');

      expect(_drawn(change.value), '*ab* one\ntwo three');
      expect(change.start, change.value.text.length);
      expect(change.rewritten, isTrue);
    });

    test('of lines that need no tidying is plain as well', () {
      final change = _type(_marked('*ab*'), 2, 'c\nd');

      expect(_drawn(change.value), '*ab*c\nd');
      expect(change.rewritten, isFalse);
    });

    test('of one line with something to tidy is tidied', () {
      final change = _type(_marked('*ab*'), 2, 'c\u00A0\u200Bd');

      expect(_drawn(change.value), '*ab*c d');
      expect((change.start, change.rewritten), (5, true));
    });

    test('into an empty box is tidied at its ends too', () {
      final change = _type(
        const FormattedText.empty(),
        0,
        '\n\n  Dear all,  \n\n\n\nThanks \n',
      );

      expect(change.value.text, 'Dear all,\n\nThanks');
      expect(change.start, 17);
    });

    test('in the middle of a line keeps the spaces at its ends', () {
      final change = _type(FormattedText.plain('ab'), 1, ' x\n\n\n\ny ');

      expect(change.value.text, 'a x\n\ny b');
    });

    test('of one line copied with its line break ends in one line break', () {
      final change = _type(_marked('• *ab*'), 4, ' cd\r\n');

      // Plain, and not Enter: the list does not go on.
      expect(_drawn(change.value), '• *ab* cd\n');
    });

    test('at the start of a line makes a list of a copied list', () {
      final change = _type(
        FormattedText.plain('ab\n'),
        3,
        '\uF0B7\tone\r\n\uF0B7\ttwo',
      );

      expect(change.value.text, 'ab\n• one\n• two');
      // In the middle of a line a dash is a dash.
      expect(
        _type(FormattedText.plain('ab'), 2, '- one\n- two\n- three').value.text,
        'ab- one\n• two\n• three',
      );
    });

    test('of several lines at the start of a line loses its indent, which a '
        'word from the keyboard keeps', () {
      final value = FormattedText.plain('ab\n');

      expect(_type(value, 3, '  One,\n  two').value.text, 'ab\nOne,\ntwo');
      final word = _type(value, 3, ' One');
      expect((word.value.text, word.rewritten), ('ab\n One', false));
    });

    test('of a list into a list item does not double the bullet', () {
      final change = _type(
        FormattedText.plain('• '),
        2,
        '\u25CF one\n\u25CF two',
      );

      expect(change.value.text, '• one\n• two');
    });

    test('gets a line between paragraphs only at the start of a line', () {
      expect(
        _type(FormattedText.plain('Hi.\n'), 4, 'One.\nTwo.').value.text,
        'Hi.\nOne.\n\nTwo.',
      );
      expect(
        _type(FormattedText.plain('Hi'), 2, '.\nOne.\nTwo').value.text,
        'Hi.\nOne.\nTwo',
      );
    });

    test('is taken as it comes when the rules are off', () {
      final change = _type(_marked('*ab*'), 2, ' c \r\n\td', rules: false);

      expect(_drawn(change.value), '*ab c \r*\n*\td*');
      expect(change.rewritten, isFalse);
    });
  });

  group('copied text is tidied:', () {
    String tidied(String raw) => FormattedText.fromPaste(raw).text;

    test('every kind of line break is one kind', () {
      expect(
        tidied('a\r\nb\rc\u2028d\u2029e\u000Bf\u000Cg'),
        'a\nb\nc\nd\ne\nf\ng',
      );
    });

    test('tabs, odd spaces and runs of spaces are one space', () {
      expect(
        tidied('a\tb\u00A0c\u2003d\u202Fe\u3000f   g \t h'),
        'a b c d e f g h',
      );
    });

    test('lines lose their indent and the spaces at their end', () {
      expect(tidied('   a  \n\t b \t\n\u00A0c'), 'a\nb\nc');
    });

    test('what cannot be seen is removed', () {
      expect(
        tidied(
          '\uFEFFa\u200Bb\u200Cc\u200Dd\u00ADe\u200Ef\u202Ag\u2066h\u0007i'
          '\u2060j\u009Fk',
        ),
        'abcdefghijk',
      );
    });

    test('three line breaks or more in a row leave one empty line', () {
      expect(tidied('a\n\n\n\nb'), 'a\n\nb');
      expect(tidied('a\n\nb'), 'a\n\nb');
      // A line of nothing but spaces is an empty line.
      expect(tidied('a\n \n\t\n\nb'), 'a\n\nb');
    });

    test('empty lines at the start and the end go', () {
      expect(tidied('\n\n a\nb \n\n\n'), 'a\nb');
      expect(tidied(' \n\t\n'), '');
    });

    test('the bullets of other apps become list items', () {
      for (final glyph in [
        '•',
        '\u25CF',
        '\u25E6',
        '\u25AA',
        '\u2023',
        '\u00B7',
        '\uF0B7',
        '\uF0A7',
      ]) {
        expect(
          tidied('$glyph one\n $glyph\ttwo'),
          '• one\n• two',
          reason: 'U+${glyph.codeUnitAt(0).toRadixString(16)}',
        );
      }
      // Not without the space after it.
      expect(tidied('\u00B7one'), '\u00B7one');
    });

    test('dashes and stars are a list on two lines or more in a row', () {
      expect(tidied('- one\n- two'), '• one\n• two');
      expect(tidied('* one\n* two\n* three'), '• one\n• two\n• three');
      expect(tidied('\u2013 one\n- two\nthree'), '• one\n• two\nthree');
    });

    test('one line with a dash, or two that are apart, are kept as typed', () {
      expect(tidied('a\n- one\nb'), 'a\n- one\nb');
      expect(tidied('- one\n\n- two'), '- one\n\n- two');
      expect(tidied('-one\n-two'), '-one\n-two');
    });

    test('numbered lists are kept as typed', () {
      expect(tidied('1. one\n2. two'), '1. one\n2. two');
    });

    test('quotes, dashes and the ellipsis are kept', () {
      const text = '\u201CQuoted\u201D \u2014 it\u2019s 1\u20132\u2026 fine';
      expect(tidied(text), text);
    });

    test('joined letters are taken apart', () {
      expect(
        tidied('\uFB01nd the \uFB02ag o\uFB00 \uFB03 \uFB04'),
        'find the flag off ffi ffl',
      );
    });

    test('emoji and Tibetan are kept', () {
      const text = 'བཀྲ་ཤིས་བདེ་ལེགས། $_grin';
      expect(tidied(text), text);
    });

    test('paragraphs with one line break each get an empty line between', () {
      expect(
        tidied('One.\nTwo!\nThree?\nFour'),
        'One.\n\nTwo!\n\nThree?\n\nFour',
      );
      expect(tidied('Dear all:\r\nThank you.'), 'Dear all:\n\nThank you.');
      // A closing quote or bracket after the full stop is still an end.
      expect(
        tidied('He said \u201Cgo.\u201D\n(See below.)\n"Yes!"\nEnd'),
        'He said \u201Cgo.\u201D\n\n(See below.)\n\n"Yes!"\n\nEnd',
      );
    });

    test('but not text that has empty lines of its own', () {
      expect(tidied('One.\n\nTwo.\nThree.'), 'One.\n\nTwo.\nThree.');
    });

    test('nor a list', () {
      expect(tidied('We need:\n• one.\n• two.'), 'We need:\n• one.\n• two.');
      expect(tidied('We need:\n- one.\n- two.'), 'We need:\n• one.\n• two.');
    });

    test('nor lines that were wrapped by hand, nor a single line', () {
      expect(
        tidied('This line is wrapped\nmid sentence.\nNext.'),
        'This line is wrapped\nmid sentence.\nNext.',
      );
      expect(tidied('Dear all,\nThank you.'), 'Dear all,\nThank you.');
      expect(tidied('One.'), 'One.');
    });

    test('one paste is 20,000 characters at most, and ends on a whole one', () {
      expect(tidied('a' * 30000), hasLength(20000));
      expect(tidied('${'a' * 19999}$_grin'), hasLength(19999));
      expect(tidied('${'a' * 19998}$_grin'), hasLength(20000));
    });

    test('and it has no marks', () {
      expect(FormattedText.fromPaste('One.\nTwo.').ranges, isEmpty);
      expect(FormattedText.plain(' a\r\n').text, ' a\r\n');
    });
  });

  group('a mark', () {
    test('goes on a plain selection', () {
      expect(_drawn(_marked('abcd').toggled(_bold, 1, 3)), 'a*bc*d');
    });

    test('comes off a selection that has it all over', () {
      expect(_drawn(_marked('a*bc*d').toggled(_bold, 1, 3)), 'abcd');
      expect(_drawn(_marked('*abcd*').toggled(_bold, 1, 3)), '*a*bc*d*');
    });

    test('goes on all of a selection that has it only in part', () {
      expect(_drawn(_marked('a*b*cd').toggled(_bold, 0, 4)), '*abcd*');
    });

    test('leaves the other marks as they are', () {
      final value = _marked('/ab/').toggled(_bold, 0, 1);

      expect(_drawn(value), '*/a*b/');
      expect(_drawn(value.toggled(_underline, 1, 2)), '*/a*_b/_');
    });

    test('is not toggled by a caret alone', () {
      final value = _marked('a*b*');

      expect(value.toggled(_bold, 1, 1), value);
    });

    test('is on a selection when all of its words have it', () {
      final value = _marked('*a/b/*c');

      expect(value.marksAt(0, 2), {_bold});
      expect(value.marksAt(1, 2), {_bold, _italic});
      expect(value.marksAt(0, 3), isEmpty);
      // Line breaks and bullets have none, and do not count against it.
      expect(_marked('*ab*\n• *cd*').marksAt(0, 7), {_bold});
      expect(FormattedText.plain('\n').marksAt(0, 1), isEmpty);
    });

    test('at a caret is what the next typed character would get', () {
      final value = _marked('a*bc*d\n*e*');

      expect(value.marksAt(0, 0), isEmpty);
      expect(value.marksAt(1, 1), isEmpty);
      expect(value.marksAt(2, 2), {_bold});
      expect(value.marksAt(3, 3), {_bold});
      expect(value.marksAt(4, 4), isEmpty);
      // The start of a line, though the line begins bold.
      expect(value.marksAt(5, 5), isEmpty);
    });
  });

  group('the word at a caret', () {
    final value = FormattedText.plain("the quick fox, don't");

    test('is the one it is inside', () {
      expect(value.wordAt(5), (4, 9));
      expect(value.wordAt(8), (4, 9));
      expect(value.wordAt(17), (15, 20));
    });

    test('is none at either end of a word, or between words', () {
      expect(value.wordAt(4), isNull);
      expect(value.wordAt(9), isNull);
      expect(value.wordAt(14), isNull);
      expect(value.wordAt(0), isNull);
      expect(value.wordAt(20), isNull);
      expect(const FormattedText.empty().wordAt(0), isNull);
    });
  });

  group('the lines sent and stored', () {
    test('have a run for each stretch set one way', () {
      expect(_marked('ab*cd/ef/*g').toLines(), [
        const TextLine([
          TextRun('ab'),
          TextRun('cd', marks: {_bold}),
          TextRun('ef', marks: {_bold, _italic}),
          TextRun('g'),
        ]),
      ]);
    });

    test('say which are list items, without the bullet', () {
      expect(FormattedText.plain('• one\ntwo').toLines(), [
        _line('one', bullet: true),
        _line('two'),
      ]);
    });

    test('are trimmed at both ends, marks and all', () {
      expect(_marked('  ab  \n•   cd  \n*  ef  *').toLines(), [
        _line('ab'),
        _line('cd', bullet: true),
        const TextLine([
          TextRun('ef', marks: {_bold}),
        ]),
      ]);
    });

    test('keep the empty lines in the middle and drop those at the ends', () {
      expect(FormattedText.plain('\n \na\n\n\nb\n\n').toLines(), [
        _line('a'),
        const TextLine([]),
        const TextLine([]),
        _line('b'),
      ]);
      expect(FormattedText.plain(' \n\n').toLines(), isEmpty);
      expect(const FormattedText.empty().toLines(), isEmpty);
    });

    test('have an empty line for a list item with nothing in it', () {
      expect(FormattedText.plain('a\n• \nb\n• ').toLines(), [
        _line('a'),
        const TextLine([]),
        _line('b'),
      ]);
    });

    test('join neighbouring stretches that are set alike', () {
      final value = FormattedText.plain(
        'abcd',
      ).toggled(_bold, 1, 2).toggled(_bold, 2, 3);

      expect(value.toLines(), [
        const TextLine([
          TextRun('a'),
          TextRun('bc', marks: {_bold}),
          TextRun('d'),
        ]),
      ]);
    });

    test('come back as the same lines', () {
      for (final value in [
        _marked('Dear *all*,\n\n\n• /one/\n•   two  \n\n_Thanks_'),
        _marked('\n  • indented\n• • twice\n•\n• '),
        _marked('*a\nb*'),
        FormattedText.plain('a${_grin}b'),
        const FormattedText.empty(),
      ]) {
        final lines = value.toLines();
        expect(
          FormattedText.fromLines(lines).toLines(),
          lines,
          reason: _drawn(value),
        );
      }
    });

    test('are put back together with their bullets and line breaks', () {
      final value = FormattedText.fromLines([
        _line('one', bullet: true),
        const TextLine([]),
        const TextLine([
          TextRun('t'),
          TextRun('wo', marks: {_underline}),
        ]),
      ]);

      expect(_drawn(value), '• one\n\nt_wo_');
    });

    test('know their own text', () {
      const line = TextLine([
        TextRun('a'),
        TextRun('b', marks: {_bold}),
      ]);

      expect(line.text, 'ab');
      expect(line.isEmpty, isFalse);
      expect(const TextLine([]).isEmpty, isTrue);
    });
  });

  group('two values', () {
    test(
      'with the same wording and marks are equal, however they were made',
      () {
        final typed = _type(
          _type(_marked('ad'), 1, 'b', typing: {_bold}).value,
          2,
          'c',
        ).value;
        final toggled = FormattedText.plain(
          'abcd',
        ).toggled(_bold, 2, 3).toggled(_bold, 1, 2);
        final stored = FormattedText.fromLines(const [
          TextLine([
            TextRun('a'),
            TextRun('b', marks: {_bold}),
            TextRun('c', marks: {_bold}),
            TextRun('d'),
          ]),
        ]);

        expect(typed, _marked('a*bc*d'));
        expect(toggled, typed);
        expect(stored, typed);
        expect(stored.hashCode, typed.hashCode);
        expect(stored.ranges, [const MarkRange(_bold, 1, 3)]);
      },
    );

    test('with other marks, or other wording, are not', () {
      expect(_marked('a*bc*d'), isNot(_marked('a*b*cd')));
      expect(_marked('a*bc*d'), isNot(_marked('a/bc/d')));
      expect(_marked('*ab*'), isNot(_marked('*ac*')));
      expect(const FormattedText.empty(), FormattedText.plain(''));
    });

    test('are blank with nothing but spaces, line breaks and bullets', () {
      for (final text in ['', '  ', '\n\n', '• ', ' \n• \n•']) {
        expect(FormattedText.plain(text).isBlank, isTrue, reason: '"$text"');
      }
      expect(FormattedText.plain('• a').isBlank, isFalse);
      expect(FormattedText.plain('\n.').isBlank, isFalse);
    });
  });

  test('whatever is typed, deleted, pasted and toggled, in any order, the '
      'ranges stay in order, merged, not empty and inside the text', () {
    final random = Random(20261003);
    const pieces = [
      'a',
      'B',
      ' ',
      '.',
      '\n',
      '\n\n',
      '• ',
      '- ',
      _grin,
      'word ',
      'One.\nTwo.',
      ' x \r\n\ty',
    ];
    var value = const FormattedText.empty();

    for (var step = 0; step < 3000; step++) {
      final text = value.text;
      int spot() {
        final at = random.nextInt(text.length + 1);
        return _splits(text, at) ? at - 1 : at;
      }

      final one = spot();
      final other = spot();
      final (start, end) = (min(one, other), max(one, other));
      final mark = TextMark.values[random.nextInt(3)];
      final typed = pieces[random.nextInt(pieces.length)];
      final rules = random.nextInt(5) > 0;
      final String did;

      switch (random.nextInt(6)) {
        case 0:
          did = 'toggle ${mark.name} $start-$end';
          value = value.toggled(mark, start, end);
        case 1:
          did = 'list $start-$end';
          final change = value.bulletsToggled(start, end);
          value = change.value;
          expect(change.start, inInclusiveRange(0, value.text.length));
          expect(change.end, inInclusiveRange(change.start, value.text.length));
        case 2:
          // No more than a few characters at a time, or nothing is left.
          final to = min(end, start + 8);
          did = 'replace $start-$to with "$typed"';
          final change = _replace(value, start, to, typed, rules: rules);
          value = change.value;
          expect(change.start, inInclusiveRange(0, value.text.length));
        default:
          final typing = random.nextInt(4) == 0 ? {mark} : null;
          did = 'type "$typed" at $start';
          final keyboard = text.replaceRange(start, start, typed);
          final change = _type(
            value,
            start,
            typed,
            typing: typing,
            rules: rules,
          );
          value = change.value;
          expect(change.start, inInclusiveRange(0, value.text.length));
          expect(change.rewritten, value.text != keyboard, reason: did);
          if (!rules) expect(change.rewritten, isFalse, reason: did);
      }

      _expectSound(value, 'step $step: $did');
      final lines = value.toLines();
      expect(
        FormattedText.fromLines(lines).toLines(),
        lines,
        reason: 'step $step: $did',
      );
      if (value.text.length > 300) {
        value = _delete(value, 0, value.text.length ~/ 2).value;
      }
    }
  });
}
