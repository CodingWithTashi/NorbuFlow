import 'package:flutter/foundation.dart';

import '../../../core/models/formatted_text.dart';
import '../../../core/utils/date_only.dart';

/// What a letter's files are kept as on the device (`FileCache`). A letter
/// never changes once issued, so its id names them for good.
abstract final class LetterFiles {
  static String pdf(String letterId) => 'letters/$letterId.pdf';

  /// What it says, as JSON: the wording to start another letter from.
  static String body(String letterId) => 'letters/$letterId.json';

  /// The picture of its page.
  static String page(String letterId) => 'letters/$letterId-1.png';
}

/// A support letter that was issued. It never changes.
@immutable
class Letter {
  const Letter({
    required this.id,
    required this.number,
    required this.name,
    required this.validUntil,
    required this.issuedOn,
    this.memberId,
  });

  final String id;

  /// The digits printed after "No."
  final String number;

  /// Who it is for.
  final String name;

  /// The member it is for, when it is for one.
  final String? memberId;

  /// The last day it holds.
  final DateTime validUntil;
  final DateTime issuedOn;

  bool expiredOn(DateTime today) =>
      validUntil.dateOnly.isBefore(today.dateOnly);

  /// Whether [query] is part of the name or of the number.
  bool matches(String query) {
    final wanted = query.trim().toLowerCase();
    if (wanted.isEmpty) return true;
    return name.toLowerCase().contains(wanted) || number.contains(wanted);
  }

  @override
  bool operator ==(Object other) =>
      other is Letter &&
      other.id == id &&
      other.number == number &&
      other.name == name &&
      other.memberId == memberId &&
      other.validUntil == validUntil &&
      other.issuedOn == issuedOn;

  @override
  int get hashCode =>
      Object.hash(id, number, name, memberId, validUntil, issuedOn);
}

/// What an admin enters for a support letter.
@immutable
class LetterRequest {
  const LetterRequest({
    required this.id,
    required this.name,
    required this.validUntil,
    required this.body,
    this.memberId,
    this.number,
  });

  /// A UUID the app chooses, so that sending a request twice issues one
  /// letter.
  final String id;
  final String name;
  final String? memberId;
  final DateTime validUntil;

  /// What it says, line by line. Empty lines before the first words set how
  /// far down the page it starts.
  final List<TextLine> body;

  /// The digits of a number typed by hand. Null leaves it to the temple.
  final String? number;
}

/// A letter as it would print, before anything is saved.
@immutable
class LetterPreview {
  const LetterPreview({
    required this.number,
    required this.pdf,
    this.spare = 0,
  });

  /// The digits of the number on the letter.
  final String number;

  /// One page, at the size of the letterhead.
  final Uint8List pdf;

  /// Lines of room left under the body: how much lower it could start.
  final int spare;
}

/// A letter as saved, with its print-ready page.
@immutable
class IssuedLetter {
  const IssuedLetter({required this.letter, required this.pdf});

  final Letter letter;
  final Uint8List pdf;
}

/// A letter on file: its page, and what it says.
@immutable
class LetterOnFile {
  const LetterOnFile({
    required this.letter,
    required this.body,
    required this.pdf,
  });

  final Letter letter;
  final List<TextLine> body;
  final Uint8List pdf;
}

/// What came of asking to see a letter before it is issued.
sealed class LetterPreviewOutcome {
  const LetterPreviewOutcome();
}

final class LetterPreviewed extends LetterPreviewOutcome {
  const LetterPreviewed(this.preview);

  final LetterPreview preview;
}

/// The body runs [lines] past the room the page has. Nothing was drawn.
@immutable
final class LetterTooLong extends LetterPreviewOutcome {
  const LetterTooLong(this.lines);

  final int lines;
}

/// What came of asking for a letter.
sealed class LetterOutcome {
  const LetterOutcome();
}

final class LetterIssued extends LetterOutcome {
  const LetterIssued(this.issued);

  final IssuedLetter issued;
}

/// The number typed by hand is on another letter. Nothing was saved.
@immutable
final class LetterNumberTaken extends LetterOutcome {
  const LetterNumberTaken({required this.name, required this.number});

  /// Who that letter is for.
  final String name;
  final String number;
}

abstract interface class LetterRepository {
  /// The temple's letters, the newest first.
  Future<List<Letter>> fetchLetters(String templeId);

  /// Draws the letter [request] would issue, with the number it would carry.
  /// A field that cannot be used fails as a `ValidationFailure` keyed by it.
  Future<LetterPreviewOutcome> preview(String templeId, LetterRequest request);

  /// Issues the letter and returns it: the same letter if asked again.
  Future<LetterOutcome> issue(String templeId, LetterRequest request);

  /// [letter] with its page and wording. One that was fetched before comes
  /// from the device, without asking the backend again.
  Future<LetterOnFile> fetch(String templeId, Letter letter);
}

/// A half-written letter, kept on the device until it is issued.
@immutable
class LetterDraft {
  const LetterDraft({
    this.name = '',
    this.memberId,
    this.validUntil,
    this.body = const [],
  });

  final String name;
  final String? memberId;

  /// Null while it is still the day the form suggests.
  final DateTime? validUntil;
  final List<TextLine> body;

  /// Nothing worth keeping.
  bool get isEmpty => name.trim().isEmpty && body.isEmpty;
}

/// Where a half-written letter waits, one per temple.
abstract interface class LetterDraftStore {
  Future<LetterDraft?> read(String key);

  Future<void> write(String key, LetterDraft draft);

  Future<void> clear(String key);
}
