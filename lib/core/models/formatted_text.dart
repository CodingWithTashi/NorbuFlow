import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The ways a stretch of wording can be set. Nothing else is offered.
enum TextMark { bold, italic, underline }

/// A stretch of one line set one way.
@immutable
class TextRun {
  const TextRun(this.text, {this.marks = const {}});

  final String text;
  final Set<TextMark> marks;

  @override
  bool operator ==(Object other) =>
      other is TextRun && other.text == text && setEquals(other.marks, marks);

  @override
  int get hashCode => Object.hash(text, Object.hashAllUnordered(marks));

  @override
  String toString() => 'TextRun("$text", ${_names(marks)})';
}

/// One line as written. No runs is an empty line.
@immutable
class TextLine {
  const TextLine(this.runs, {this.bullet = false});

  final List<TextRun> runs;

  /// Whether the line is an item of a list.
  final bool bullet;

  String get text => runs.map((run) => run.text).join();
  bool get isEmpty => text.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is TextLine &&
      other.bullet == bullet &&
      listEquals(other.runs, runs);

  @override
  int get hashCode => Object.hash(bullet, Object.hashAll(runs));

  @override
  String toString() => 'TextLine($runs, bullet: $bullet)';
}

/// Where one mark is on: from [start] up to, not including, [end].
@immutable
class MarkRange {
  const MarkRange(this.mark, this.start, this.end);

  final TextMark mark;
  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is MarkRange &&
      other.mark == mark &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(mark, start, end);

  @override
  String toString() => '${mark.name} $start-$end';
}

/// A letter's wording as it is typed: plain text, and where it is bold,
/// italic or underlined. A line that starts with [bullet] is a list item.
@immutable
class FormattedText {
  const FormattedText.empty() : text = '', ranges = const [];

  const FormattedText._(this.text, this.ranges);

  /// [text] as typed: nothing cleaned, nothing marked.
  factory FormattedText.plain(String text) => FormattedText._(text, const []);

  /// Copied text, tidied as every paste is.
  factory FormattedText.fromPaste(String raw) =>
      FormattedText.plain(_tidied(raw));

  /// What [toLines] gave, as text again.
  factory FormattedText.fromLines(List<TextLine> lines) {
    final text = StringBuffer();
    final bits = <int>[];
    for (final (index, line) in lines.indexed) {
      if (index > 0) {
        text.write('\n');
        bits.add(0);
      }
      if (line.bullet) {
        text.write(bullet);
        bits.addAll(List.filled(bullet.length, 0));
      }
      for (final run in line.runs) {
        text.write(run.text);
        bits.addAll(List.filled(run.text.length, _bitsOf(run.marks)));
      }
    }
    return FormattedText._marked(text.toString(), bits);
  }

  /// The normal form of [text] with the marks in [bits], one number for
  /// each character: equal wording is then equal ranges.
  factory FormattedText._marked(String text, List<int> bits) {
    final free = _markable(text);
    for (var at = 0; at < text.length; at++) {
      if (!free[at]) {
        bits[at] = 0;
      } else if (at > 0 &&
          _trails(text.codeUnitAt(at)) &&
          _leads(text.codeUnitAt(at - 1))) {
        // The two halves of an emoji are set alike.
        bits[at] = bits[at - 1];
      }
    }
    final ranges = <MarkRange>[];
    for (final mark in TextMark.values) {
      final bit = 1 << mark.index;
      var start = -1;
      for (var at = 0; at <= text.length; at++) {
        final on = at < text.length && (bits[at] & bit) != 0;
        if (on && start < 0) start = at;
        if (!on && start >= 0) {
          ranges.add(MarkRange(mark, start, at));
          start = -1;
        }
      }
    }
    return FormattedText._(text, List.unmodifiable(ranges));
  }

  /// What a list item's line starts with.
  static const bullet = '• ';

  /// The lines, joined by line breaks.
  final String text;

  /// Each mark's stretches in order: none empty, none on a line break or a
  /// bullet, and no two of one mark touching.
  final List<MarkRange> ranges;

  /// Whether there is nothing but spaces, line breaks and bullets.
  bool get isBlank => !text.contains(_written);

  /// What is sent and stored: each line trimmed, with its runs, and no
  /// empty lines before the first line or after the last.
  List<TextLine> toLines() {
    final bits = _bits();
    final lines = <TextLine>[];
    var lineStart = 0;
    for (final line in text.split('\n')) {
      var from = line.length - line.trimLeft().length;
      final listed = line.startsWith(bullet, from);
      if (listed) {
        from += bullet.length;
        from += line.length - from - line.substring(from).trimLeft().length;
      }
      final to = math.max(from, line.trimRight().length);
      final runs = <TextRun>[];
      for (var at = from; at < to;) {
        final mask = bits[lineStart + at];
        var end = at;
        while (end < to && bits[lineStart + end] == mask) {
          end++;
        }
        runs.add(TextRun(line.substring(at, end), marks: _marksOf(mask)));
        at = end;
      }
      lines.add(TextLine(runs, bullet: listed && runs.isNotEmpty));
      lineStart += line.length + 1;
    }
    var first = 0;
    var last = lines.length;
    while (first < last && lines[first].isEmpty) {
      first++;
    }
    while (last > first && lines[last - 1].isEmpty) {
      last--;
    }
    return lines.sublist(first, last);
  }

  /// One edit by the user: the field's text became [text], with the caret
  /// at [caret]. With [rules], lists and pastes are looked after too.
  TextChange edited({
    required String text,
    required int caret,
    Set<TextMark>? typing,
    bool rules = true,
  }) {
    final old = this.text;
    final pinned = caret >= 0 && caret <= text.length;
    if (text == old) {
      final at = pinned ? caret : text.length;
      return TextChange(this, start: at, end: at);
    }

    // What the two share at each end is what stayed. The end stops at the
    // caret, where an edit leaves it: that settles an "a" typed in "aaa".
    final most = math.min(old.length, text.length);
    final behind = pinned ? math.min(most, text.length - caret) : most;
    var suffix = 0;
    while (suffix < behind &&
        old.codeUnitAt(old.length - 1 - suffix) ==
            text.codeUnitAt(text.length - 1 - suffix)) {
      suffix++;
    }
    var prefix = 0;
    while (prefix < most - suffix &&
        old.codeUnitAt(prefix) == text.codeUnitAt(prefix)) {
      prefix++;
    }
    // Never between the two halves of an emoji.
    if (prefix > 0 && _leads(old.codeUnitAt(prefix - 1))) prefix--;
    if (suffix > 0 && _trails(old.codeUnitAt(old.length - suffix))) suffix--;

    var inserted = text.substring(prefix, text.length - suffix);
    var (start, end) = (prefix, old.length - suffix);
    if (rules) (start, end) = _aroundBullets(start, end, inserted);

    // What is typed is set as what it replaces, or as what it follows.
    final bits = _bits();
    var mask = switch (typing) {
      final typing? => _bitsOf(typing),
      null when start < end => bits[start],
      null => start > 0 ? bits[start - 1] : 0,
    };

    final line = _lineStart(start);
    final item = _listed(line) && start >= line + bullet.length;
    // One line break, at the very end, is Enter: before it comes the word
    // the keyboard corrected on the way, if it did.
    final entered =
        rules &&
        inserted.endsWith('\n') &&
        !inserted.contains(_lineBreaks) &&
        inserted.indexOf('\n') == inserted.length - 1;
    if (entered) inserted = inserted.substring(0, inserted.length - 1);

    if (rules && inserted.length > 1) {
      final itemStart = item && start == line + bullet.length;
      var tidy = _tidied(
        inserted,
        whole: start == 0 && end == old.length && inserted.contains('\n'),
        lineStart: start == line || itemStart,
      );
      // A list pasted into a list item brings a bullet of its own.
      if (itemStart && tidy.startsWith(bullet)) {
        tidy = tidy.substring(bullet.length);
      }
      if (inserted.contains('\n') || tidy != inserted) {
        inserted = tidy;
        mask = 0;
      }
    }
    if (entered && item) {
      final rest = old.substring(line + bullet.length, _lineEnd(line));
      if (start == end && inserted.isEmpty && rest.trim().isEmpty) {
        // Enter on an item with nothing in it ends the list.
        (start, end) = (line, line + bullet.length);
      } else {
        inserted += '\n$bullet';
      }
    } else if (entered) {
      inserted += '\n';
    }

    final next = FormattedText._marked(
      old.replaceRange(start, end, inserted),
      bits..replaceRange(start, end, List.filled(inserted.length, mask)),
    );
    final rewritten = next.text != text;
    final at = rewritten || !pinned ? start + inserted.length : caret;
    return TextChange(next, start: at, end: at, rewritten: rewritten);
  }

  /// [start] to [end], the stretch [inserted] replaces, moved so that no
  /// bullet is typed into, cut in half or left in the middle of a line.
  (int, int) _aroundBullets(int start, int end, String inserted) {
    final line = _lineStart(start);
    final item = line + bullet.length;
    if (start == end) {
      return _listed(line) && start < item ? (item, item) : (start, end);
    }
    if (_listed(line) && start == line + 1) start = line;
    final last = _lineStart(end);
    // Whether what follows is joined onto a line already begun.
    final joins = inserted.isEmpty ? start > line : !inserted.endsWith('\n');
    if (_listed(last) &&
        (end == last + 1 || (end == last && start < last && joins))) {
      end = last + bullet.length;
    }
    return (start, end);
  }

  /// The marks on all of [start] to [end]. For a caret, the marks the next
  /// typed character would get.
  Set<TextMark> marksAt(int start, int end) {
    final bits = _bits();
    if (start >= end) return _marksOf(start > 0 ? bits[start - 1] : 0);
    final free = _markable(text);
    int? shared;
    for (var at = start; at < end; at++) {
      if (free[at]) shared = (shared ?? bits[at]) & bits[at];
    }
    return _marksOf(shared ?? 0);
  }

  /// [mark] taken off [start] to [end] if all of it has it, else put on
  /// all of it.
  FormattedText toggled(TextMark mark, int start, int end) {
    if (start >= end) return this;
    final bit = 1 << mark.index;
    final on = marksAt(start, end).contains(mark);
    final bits = _bits();
    for (var at = start; at < end; at++) {
      bits[at] = on ? bits[at] & ~bit : bits[at] | bit;
    }
    return FormattedText._marked(text, bits);
  }

  /// Whether every line [start] to [end] touches is a list item.
  bool bulletedAt(int start, int end) => _listLines(start, end).every(_listed);

  /// The lines [start] to [end] touches made list items, or plain lines
  /// again if they all are items already.
  TextChange bulletsToggled(int start, int end) {
    final lines = _listLines(start, end);
    final remove = lines.every(_listed);
    var next = this;
    // Last line first, so the lines before it keep their places.
    for (final line in lines.reversed) {
      if (remove) {
        next = next._replaced(line, line + bullet.length, '');
        if (start > line) start = math.max(line, start - bullet.length);
        if (end > line) end = math.max(line, end - bullet.length);
      } else if (!_listed(line)) {
        next = next._replaced(line, line, bullet);
        if (start >= line) start += bullet.length;
        if (end >= line) end += bullet.length;
      }
    }
    return TextChange(next, start: start, end: end, rewritten: true);
  }

  /// The word a caret at [offset] is inside, with a letter on each side of
  /// it, or null.
  (int, int)? wordAt(int offset) {
    bool letter(int at) =>
        at >= 0 && at < text.length && _letter.hasMatch(text[at]);
    if (!letter(offset - 1) || !letter(offset)) return null;
    var start = offset;
    var end = offset;
    while (letter(start - 1)) {
      start--;
    }
    while (letter(end)) {
      end++;
    }
    return (start, end);
  }

  /// One number for each character: its marks, a bit for each.
  List<int> _bits() {
    final bits = List.filled(text.length, 0, growable: true);
    for (final range in ranges) {
      for (var at = range.start; at < range.end; at++) {
        bits[at] |= 1 << range.mark.index;
      }
    }
    return bits;
  }

  FormattedText _replaced(int start, int end, String inserted) =>
      FormattedText._marked(
        text.replaceRange(start, end, inserted),
        _bits()..replaceRange(start, end, List.filled(inserted.length, 0)),
      );

  int _lineStart(int at) => at == 0 ? 0 : text.lastIndexOf('\n', at - 1) + 1;

  int _lineEnd(int at) {
    final next = text.indexOf('\n', at);
    return next < 0 ? text.length : next;
  }

  bool _listed(int lineStart) => text.startsWith(bullet, lineStart);

  /// Where the lines the List button acts on begin: the ones [start] to
  /// [end] touches, less the empty ones when there are several.
  List<int> _listLines(int start, int end) {
    final through = start < end ? end - 1 : end;
    final lines = [_lineStart(start)];
    while (_lineEnd(lines.last) < through) {
      lines.add(_lineEnd(lines.last) + 1);
    }
    final written = [
      for (final line in lines)
        if (text.substring(line, _lineEnd(line)).contains(_written)) line,
    ];
    return lines.length == 1 || written.isEmpty ? lines : written;
  }

  /// Which characters can carry a mark: all but line breaks and bullets.
  static List<bool> _markable(String text) {
    final free = List.filled(text.length, true);
    var lineStart = 0;
    for (var at = 0; at < text.length; at++) {
      if (text.codeUnitAt(at) == _lineBreak) {
        free[at] = false;
        lineStart = at + 1;
      } else if (at - lineStart < bullet.length &&
          text.startsWith(bullet, lineStart)) {
        free[at] = false;
      }
    }
    return free;
  }

  @override
  bool operator ==(Object other) =>
      other is FormattedText &&
      other.text == text &&
      listEquals(other.ranges, ranges);

  @override
  int get hashCode => Object.hash(text, Object.hashAll(ranges));

  @override
  String toString() => 'FormattedText("$text", $ranges)';
}

/// The value after an edit, and where the selection now is.
@immutable
class TextChange {
  const TextChange(
    this.value, {
    required this.start,
    required this.end,
    this.rewritten = false,
  });

  final FormattedText value;
  final int start;
  final int end;

  /// Whether the text is other than what the keyboard produced, so that
  /// the field has to be set to it.
  final bool rewritten;
}

const _lineBreak = 0x0A;

/// The most one paste brings.
const _pasteLimit = 20000;

/// Anything that is neither a space, a line break nor a bullet.
final _written = RegExp(r'[^\s•]');

/// What a word is made of, for a caret to be inside one.
final _letter = RegExp(r"[\p{L}\p{N}\p{M}'\u2019]", unicode: true);

final _lineBreaks = RegExp(r'\r\n|[\r\x0B\x0C\x85\u2028\u2029]');
final _ligature = RegExp(r'[\uFB00-\uFB04]');
const _ligatureLetters = ['ff', 'fi', 'fl', 'ffi', 'ffl'];

/// Characters that take no room: controls, joiners, direction marks, the
/// soft hyphen.
final _unseen = RegExp(
  r'[\x00-\x08\x0E-\x1F\x7F-\x9F\xAD\u061C\u180E\u200B-\u200F\u202A-\u202E'
  r'\u2060-\u2064\u2066-\u2069\uFEFF]',
);
final _spaces = RegExp(r'[ \t\xA0\u1680\u2000-\u200A\u202F\u205F\u3000]+');

/// The bullets of other apps, Word's two among them, and typed list marks.
final _glyphItem = RegExp(r'^[•\u25CF\u25E6\u25AA\u2023\xB7\uF0B7\uF0A7] ');
final _dashItem = RegExp(r'^[-\u2013*] ');
final _sentenceEnd = RegExp(r'''[.!?:]["'\u201D\u2019)\]]*$''');

bool _leads(int unit) => unit & 0xFC00 == 0xD800;
bool _trails(int unit) => unit & 0xFC00 == 0xDC00;

int _bitsOf(Set<TextMark> marks) =>
    marks.fold(0, (bits, mark) => bits | 1 << mark.index);

Set<TextMark> _marksOf(int bits) => {
  for (final mark in TextMark.values)
    if ((bits & 1 << mark.index) != 0) mark,
};

String _names(Set<TextMark> marks) => marks.map((mark) => mark.name).join('+');

/// Copied text made fit for a letter. A [whole] paste loses its empty ends;
/// a part of one keeps them, and starts a line only at a [lineStart].
String _tidied(String raw, {bool whole = true, bool lineStart = true}) {
  var text = raw;
  if (text.length > _pasteLimit) {
    final split = _leads(text.codeUnitAt(_pasteLimit - 1));
    text = text.substring(0, split ? _pasteLimit - 1 : _pasteLimit);
  }
  final lines = text
      .replaceAll(_lineBreaks, '\n')
      .replaceAllMapped(
        _ligature,
        (found) => _ligatureLetters[found[0]!.codeUnitAt(0) - 0xFB00],
      )
      .replaceAll(_unseen, '')
      .replaceAll(_spaces, ' ')
      .split('\n');
  final last = lines.length - 1;
  bool starts(int at) => at > 0 || lineStart;

  for (var at = 0; at <= last; at++) {
    var line = lines[at];
    // One line in the middle of other text may be a word from the keyboard,
    // space and all: it is left as it is.
    if (whole || at > 0 || (lineStart && last > 0)) line = line.trimLeft();
    if (whole || at < last) line = line.trimRight();
    if (starts(at)) line = line.replaceFirst(_glyphItem, FormattedText.bullet);
    lines[at] = line;
  }

  // "- " and "* " are a list when two lines or more in a row have them.
  bool dashed(int at) =>
      at <= last && starts(at) && _dashItem.hasMatch(lines[at]);
  for (var at = 0; at <= last; at++) {
    var end = at;
    while (dashed(end)) {
      end++;
    }
    for (var item = at; end - at > 1 && item < end; item++) {
      lines[item] = lines[item].replaceFirst(_dashItem, FormattedText.bullet);
    }
    if (end > at) at = end - 1;
  }

  // Empty lines in a row are one. The two ends of a part are not lines.
  final kept = <String>[];
  for (var at = 0; at <= last; at++) {
    final empty = lines[at].isEmpty && (whole || (at > 0 && at < last));
    final repeats = whole
        ? kept.isEmpty || kept.last.isEmpty
        : kept.length > 1 && kept.last.isEmpty;
    if (!empty || !repeats) kept.add(lines[at]);
  }
  while (whole && kept.isNotEmpty && kept.last.isEmpty) {
    kept.removeLast();
  }

  // Word gives each paragraph one line break; a letter has a line between.
  final paragraphs =
      lineStart &&
      kept.length > 1 &&
      kept.every(
        (line) => line.isNotEmpty && !line.startsWith(FormattedText.bullet),
      ) &&
      kept.take(kept.length - 1).every(_sentenceEnd.hasMatch);
  return kept.join(paragraphs ? '\n\n' : '\n');
}
