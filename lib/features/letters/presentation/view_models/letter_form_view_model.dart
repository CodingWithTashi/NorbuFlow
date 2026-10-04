import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/command.dart';
import '../../../../core/error/result.dart';
import '../../../../core/error/validation_issue.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/models/formatted_text.dart';
import '../../../../core/models/photo_source.dart';
import '../../../../core/services/clipboard_reader.dart';
import '../../../../core/services/document_printer.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/ids.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/view_models/auth_view_model.dart';
import '../../../members/domain/member.dart';
import '../../../members/presentation/view_models/members_view_model.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../data/letter_repositories.dart';
import '../../domain/letter.dart';
import 'letters_view_model.dart';

/// What a letter is made from. The names are also the field names the
/// backend reports a problem against.
enum LetterField { name, body, validUntil, number }

/// What a new letter starts from: a name already known, or the wording of
/// the letter with the id [like]. Neither, it starts from the draft.
typedef LetterStart = ({String? name, String? like});

@immutable
class LetterFormState {
  const LetterFormState({
    required this.requestId,
    required this.validUntil,
    this.name = '',
    this.memberId,
    this.body = const FormattedText.empty(),
    this.linesDown = 0,
    this.datePicked = false,
    this.issues = const {},
    this.tooLong,
    this.busy = false,
    this.issuing = false,
    this.number,
    this.numberInput = '',
    this.preview,
    this.previewed,
    this.taken,
    this.issued,
  });

  /// Names the letter being asked for. Sent with every attempt, so trying
  /// again after a failure cannot issue it twice.
  final String requestId;

  /// Who it is for, and the member if one was picked.
  final String name;
  final String? memberId;

  /// What the letter says.
  final FormattedText body;

  /// How many lines below the top of its room the body starts: a short
  /// letter looks better lower on the page.
  final int linesDown;

  /// The last day it holds: a year from today until another is picked.
  final DateTime validUntil;
  final bool datePicked;
  final Map<LetterField, ValidationIssue> issues;

  /// How many lines past the page the body ran when it was last previewed.
  final int? tooLong;

  /// A letter is being fetched, drawn or issued.
  final bool busy;

  /// It is being issued: what is on the preview can no longer be changed.
  final bool issuing;

  /// The digits of a number typed by hand, once it is on the preview. Null
  /// leaves the number to the temple.
  final String? number;

  /// What is being typed into "Change number".
  final String numberInput;

  /// The letter as it would print. Set, the screen shows it for checking.
  final LetterPreview? preview;

  /// What [preview] was drawn from: exactly what issuing sends.
  final LetterRequest? previewed;

  /// The number asked for is on another letter: the screen says so.
  final LetterNumberTaken? taken;

  /// Set once the letter exists; the screen then shows and prints it.
  final IssuedLetter? issued;

  /// How many lines down the body starts in the preview that is shown.
  int get shownDown =>
      previewed?.body.takeWhile((line) => line.isEmpty).length ?? 0;

  /// The furthest down the body can start and still fit, by the preview.
  int get lowest => shownDown + (preview?.spare ?? 0);

  LetterFormState copyWith({
    String? name,
    String? Function()? memberId,
    FormattedText? body,
    int? linesDown,
    DateTime? validUntil,
    bool? datePicked,
    Map<LetterField, ValidationIssue>? issues,
    int? Function()? tooLong,
    bool? busy,
    bool? issuing,
    String? Function()? number,
    String? numberInput,
    LetterPreview? Function()? preview,
    LetterRequest? Function()? previewed,
    LetterNumberTaken? Function()? taken,
    IssuedLetter? issued,
  }) {
    return LetterFormState(
      requestId: requestId,
      name: name ?? this.name,
      memberId: memberId == null ? this.memberId : memberId(),
      body: body ?? this.body,
      linesDown: linesDown ?? this.linesDown,
      validUntil: validUntil ?? this.validUntil,
      datePicked: datePicked ?? this.datePicked,
      issues: issues ?? this.issues,
      tooLong: tooLong == null ? this.tooLong : tooLong(),
      busy: busy ?? this.busy,
      issuing: issuing ?? this.issuing,
      number: number == null ? this.number : number(),
      numberInput: numberInput ?? this.numberInput,
      preview: preview == null ? this.preview : preview(),
      previewed: previewed == null ? this.previewed : previewed(),
      taken: taken == null ? this.taken : taken(),
      issued: issued ?? this.issued,
    );
  }
}

/// A support letter from a name, a last day and its wording. It is previewed
/// first, and the preview is where its number can be changed.
class LetterFormViewModel extends Notifier<LetterFormState> {
  LetterFormViewModel(this.start);

  final LetterStart start;

  static final _leadingZeros = RegExp('^0+');

  /// Whether anything has been entered since the form opened.
  bool _touched = false;

  @override
  LetterFormState build() {
    final requestId = ref.watch(newIdProvider)();
    final today = ref.watch(todayProvider);
    _touched = false;
    unawaited(Future(_begin));
    return LetterFormState(
      requestId: requestId,
      name: start.name ?? '',
      validUntil: today.plusOneYear,
    );
  }

  /// One draft per temple and person: a desk's tablet is shared.
  String get _draftKey {
    final user = ref.read(authViewModelProvider).user?.id ?? '';
    return '$user.${ref.read(activeTempleIdProvider)}';
  }

  /// The draft is the plain "New letter"'s. One begun from a name or from
  /// another letter leaves it alone, so that it is still there afterwards.
  bool get _keepsDraft => start.name == null && start.like == null;

  /// Fills the form with what it starts from, unless typing got there first.
  Future<void> _begin() async {
    if (!ref.mounted) return;
    if (start.like case final letterId?) {
      await _copyWording(letterId);
    } else if (_keepsDraft) {
      final draft = await ref.read(letterDraftStoreProvider).read(_draftKey);
      if (draft == null || draft.isEmpty || !ref.mounted || _touched) return;
      state = state.copyWith(
        name: draft.name,
        memberId: () => draft.memberId,
        body: FormattedText.fromLines(draft.body),
        validUntil: draft.validUntil,
        datePicked: draft.validUntil != null,
      );
    }
  }

  Future<void> _copyWording(String letterId) async {
    // The list may still be on its way, or have failed: a toast says so.
    final listed = await runCommand(
      ref,
      () => ref.read(lettersProvider.future),
      source: 'letters.like',
    );
    final letter = listed.valueOrNull
        ?.where((l) => l.id == letterId)
        .firstOrNull;
    if (letter == null || !ref.mounted) return;
    await useWordingOf(letter);
  }

  void setName(String value) {
    // A name typed over a member's is no longer that member.
    state = _clearing(
      LetterField.name,
    ).copyWith(name: value, memberId: () => null);
    _changed();
  }

  /// Makes the letter out to [member], by the name on their card.
  void pickMember(Member member) {
    state = _clearing(
      LetterField.name,
    ).copyWith(name: member.nameEn, memberId: () => member.id);
    _changed();
  }

  void setBody(FormattedText value) {
    state = _clearing(
      LetterField.body,
    ).copyWith(body: value, tooLong: () => null);
    _changed();
  }

  void setValidUntil(DateTime value) {
    state = _clearing(
      LetterField.validUntil,
    ).copyWith(validUntil: value.dateOnly, datePicked: true);
    _changed();
  }

  void setNumberInput(String value) =>
      state = _clearing(LetterField.number).copyWith(numberInput: value);

  /// Puts what was copied on the device into the body. False if there was
  /// nothing to paste.
  Future<bool> pasteBody() async {
    final result = await runCommand(
      ref,
      () => ref.read(clipboardReaderProvider).text(),
      source: 'letters.paste',
    );
    final copied = result.valueOrNull;
    if (copied == null || !ref.mounted) return false;
    final pasted = FormattedText.fromPaste(copied);
    if (pasted.isBlank) return false;
    setBody(pasted);
    return true;
  }

  /// Starts an empty body from what [letter] says. Words written while it
  /// was being fetched are kept instead.
  Future<void> useWordingOf(Letter letter) async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    final result = await runCommand(
      ref,
      () => ref
          .read(letterRepositoryProvider)
          .fetch(ref.read(activeTempleIdProvider), letter),
      source: 'letters.wording',
    );
    if (!ref.mounted) return;
    state = state.copyWith(busy: false);
    final onFile = result.valueOrNull;
    if (onFile == null || !state.body.isBlank) return;
    // It starts as far down the page as that letter did.
    final lower = onFile.body.takeWhile((line) => line.isEmpty).length;
    state = state.copyWith(linesDown: lower);
    setBody(FormattedText.fromLines(onFile.body.skip(lower).toList()));
  }

  LetterFormState _clearing(LetterField field) =>
      state.copyWith(issues: {...state.issues}..remove(field));

  /// Keeps what has been entered, or drops the draft once nothing is left.
  void _changed() {
    _touched = true;
    if (!_keepsDraft) return;
    final draft = LetterDraft(
      name: state.name,
      memberId: state.memberId,
      validUntil: state.datePicked ? state.validUntil : null,
      body: state.body.toLines(),
    );
    final store = ref.read(letterDraftStoreProvider);
    unawaited(
      draft.isEmpty ? store.clear(_draftKey) : store.write(_draftKey, draft),
    );
  }

  LetterRequest get _request => LetterRequest(
    id: state.requestId,
    name: state.name.trim(),
    memberId: state.memberId,
    validUntil: state.validUntil,
    // An empty line for each line the body was moved down.
    body: [
      for (var line = 0; line < state.linesDown; line++) const TextLine([]),
      ...state.body.toLines(),
    ],
    number: state.number,
  );

  /// Draws the letter for checking, or marks what needs attention. Nothing
  /// is saved.
  Future<void> previewLetter() async {
    if (state.busy) return;
    final issues = {
      LetterField.name: ?Validators.required(
        state.name,
        ValidationIssue.letterNameRequired,
      ),
      if (state.body.isBlank)
        LetterField.body: ValidationIssue.letterBodyRequired,
    };
    state = state.copyWith(issues: issues, tooLong: () => null);
    if (issues.isEmpty) await _draw();
  }

  /// Starts "Change number" from the number on the preview.
  void editNumber() => state = _clearing(
    LetterField.number,
  ).copyWith(numberInput: state.preview?.number ?? '');

  /// Puts the number that was typed on the letter and draws it again. False
  /// if it cannot be used, with the reason against [LetterField.number].
  Future<bool> applyNumber() async {
    if (state.busy) return false;
    final typed = state.numberInput.trim();
    if (Validators.letterNumber(typed) case final issue?) {
      state = state.copyWith(
        issues: {...state.issues, LetterField.number: issue},
      );
      return false;
    }
    final digits = typed.replaceFirst(_leadingZeros, '');
    // The number the letter already carries: nothing was typed by hand.
    if (digits == state.preview?.number) return true;
    final before = state.number;
    state = state.copyWith(number: () => digits);
    final drawn = await _draw(numberShown: true);
    // A number that could not be drawn is not the letter's number.
    if (!drawn && ref.mounted) state = state.copyWith(number: () => before);
    return drawn;
  }

  /// Leaves the number to the temple again, and draws the letter with its
  /// next one. False if it could not be drawn.
  Future<bool> useNextNumber() async {
    if (state.busy) return false;
    final before = state.number;
    state = _clearing(LetterField.number).copyWith(number: () => null);
    final drawn = await _draw(numberShown: true);
    if (!drawn && ref.mounted) state = state.copyWith(number: () => before);
    return drawn;
  }

  /// Starts the body one line lower on the page, and draws it again.
  Future<void> moveDown() => _moveTo(state.linesDown + 1);

  Future<void> moveUp() => _moveTo(state.linesDown - 1);

  /// Puts the body half way down the room it has.
  Future<void> moveToMiddle() => _moveTo(state.lowest ~/ 2);

  Future<void> _moveTo(int linesDown) async {
    // What is being issued is the letter as it was previewed.
    if (state.issuing) return;
    final target = linesDown.clamp(0, state.lowest);
    if (target == state.linesDown) return;
    state = state.copyWith(linesDown: target);
    // A drawing under way draws again when it is done, at the place it
    // finds: several taps in a row cost two drawings, not one each.
    if (!state.busy) await _draw();
  }

  Future<bool> _draw({bool numberShown = false}) async {
    state = state.copyWith(busy: true);
    final down = state.linesDown;
    final request = _request;
    final result = await runCommand(
      ref,
      () => ref
          .read(letterRepositoryProvider)
          .preview(ref.read(activeTempleIdProvider), request),
      notify: false,
      source: 'letters.preview',
    );
    if (!ref.mounted) return false;
    switch (result) {
      case Ok(value: LetterPreviewed(:final preview)):
        state = state.copyWith(
          busy: false,
          preview: () => preview,
          previewed: () => request,
          numberInput: preview.number,
        );
        // Moved again while this was being drawn.
        if (state.linesDown != down) return _draw(numberShown: numberShown);
        return true;
      case Ok(value: LetterTooLong(:final lines)) when down > 0:
        // The words have grown since it was moved down: it starts higher,
        // as far as it has to, before it is called too long.
        state = state.copyWith(linesDown: (down - lines).clamp(0, down));
        return _draw(numberShown: numberShown);
      case Ok(value: LetterTooLong(:final lines)):
        // Said under the body, which is where it is put right.
        state = state.copyWith(
          busy: false,
          tooLong: () => lines,
          preview: () => null,
          previewed: () => null,
        );
        return false;
      case Err(:final failure):
        _refused(failure, numberShown: numberShown);
        // A preview still on screen is where it was before this try.
        if (state.previewed != null) {
          state = state.copyWith(linesDown: state.shownDown);
        }
        return false;
    }
  }

  /// Leaves the preview to change the letter.
  void backToDetails() {
    if (state.busy) return;
    state = state.copyWith(
      preview: () => null,
      previewed: () => null,
      taken: () => null,
    );
  }

  /// Issues the letter that was previewed. A number another letter carries
  /// issues nothing and sets [LetterFormState.taken].
  Future<void> save() async {
    final request = state.previewed;
    if (state.busy || request == null) return;
    state = state.copyWith(busy: true, issuing: true, taken: () => null);
    // Held now: the list is told even if this form is left before the answer.
    final letters = ref.read(lettersProvider.notifier);
    final drafts = ref.read(letterDraftStoreProvider);
    final draftKey = _keepsDraft ? _draftKey : null;
    final result = await runCommand(
      ref,
      () => ref
          .read(letterRepositoryProvider)
          .issue(ref.read(activeTempleIdProvider), request),
      notify: false,
      source: 'letters.issue',
    );
    if (result case Ok(value: LetterIssued(:final issued))) {
      letters.put(issued.letter);
      // It is a letter now, not a draft.
      if (draftKey != null) unawaited(drafts.clear(draftKey));
    }
    if (!ref.mounted) return;
    state = state.copyWith(issuing: false);
    switch (result) {
      case Ok(value: LetterIssued(:final issued)):
        state = state.copyWith(busy: false, issued: issued);
      case Ok(value: final LetterNumberTaken taken):
        state = state.copyWith(busy: false, taken: () => taken);
      case Err(:final failure):
        _refused(failure);
    }
  }

  /// The person has read that the number is [LetterFormState.taken].
  void dismissTaken() => state = state.copyWith(taken: () => null);

  /// A problem with a field is shown beside it; anything else is a toast.
  /// The number's field is on screen only while its sheet is ([numberShown]).
  void _refused(AppFailure failure, {bool numberShown = false}) {
    final rejected = _fieldIssues(failure);
    // The details are on the form, so a problem with one goes back to it.
    final onForm = rejected.keys.any((field) => field != LetterField.number);
    if (!onForm && !(numberShown && rejected.isNotEmpty)) {
      ref.read(appMessengerProvider.notifier).showFailure(failure);
    }
    state = state.copyWith(
      busy: false,
      issues: rejected,
      preview: onForm ? () => null : null,
      previewed: onForm ? () => null : null,
    );
  }

  /// What the backend said about a field, if that is why it refused.
  static Map<LetterField, ValidationIssue> _fieldIssues(AppFailure failure) {
    if (failure is! ValidationFailure) return const {};
    final fields = LetterField.values.asNameMap();
    return {
      for (final MapEntry(:key, :value) in failure.issues.entries)
        ?fields[key]: value,
    };
  }

  /// Sends the letter to a printer, as a print job called [title].
  Future<void> printLetter(String title) => _withIssued(
    (printer, issued) => printer.printPage(issued.pdf, name: title),
    'letters.print',
  );

  /// Opens the share sheet with the letter, as a file named after [title].
  Future<void> shareLetter(String title) => _withIssued(
    (printer, issued) => printer.share(issued.pdf, fileName: '$title.pdf'),
    'letters.share',
  );

  Future<void> _withIssued(
    Future<void> Function(DocumentPrinter printer, IssuedLetter issued) action,
    String source,
  ) async {
    final issued = state.issued;
    if (issued == null) return;
    await runCommand(
      ref,
      () => action(ref.read(documentPrinterProvider), issued),
      source: source,
    );
  }

  /// Clears the form for the next letter.
  void startAnother() => ref.invalidateSelf();
}

final letterFormViewModelProvider = NotifierProvider.autoDispose
    .family<LetterFormViewModel, LetterFormState, LetterStart>(
      LetterFormViewModel.new,
    );

/// The form's letter as a picture: the preview, then the letter that was
/// issued. What is shown is what will print.
final letterFormPageProvider = FutureProvider.autoDispose
    .family<MemoryPhoto?, LetterStart>((ref, start) async {
      final pdf = ref.watch(
        letterFormViewModelProvider(
          start,
        ).select((state) => state.issued?.pdf ?? state.preview?.pdf),
      );
      if (pdf == null) return null;
      final pages = await ref.watch(documentPrinterProvider).pagePhotos(pdf);
      return pages.first;
    });

/// Members whose name matches what is typed in "Who is it for?", to pick
/// one instead of typing the rest.
final letterMemberMatchesProvider = Provider.autoDispose
    .family<List<Member>, LetterStart>((ref, start) {
      const shown = 3;
      final (name, memberId) = ref.watch(
        letterFormViewModelProvider(
          start,
        ).select((state) => (state.name.trim(), state.memberId)),
      );
      // Two letters match half the temple; a picked member needs no list.
      if (memberId != null || name.length < 3) return const [];
      final members = ref.watch(membersProvider).value ?? const <Member>[];
      return members.where((m) => m.matches(name)).take(shown).toList();
    });
