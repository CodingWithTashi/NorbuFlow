import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/command.dart';
import '../../../../core/error/result.dart';
import '../../../../core/error/validation_issue.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/models/photo_source.dart';
import '../../../../core/services/document_printer.dart';
import '../../../../core/utils/ids.dart';
import '../../../../core/utils/validators.dart';
import '../../data/member_repositories.dart';
import '../../domain/card.dart';
import 'photo_draft.dart';

/// What a card is made from. The names are also the field names the backend
/// reports a problem against.
enum NewCardField { photo, name, phone, email }

@immutable
class NewCardState {
  const NewCardState({
    required this.cardId,
    this.name = '',
    this.phone = '',
    this.email = '',
    this.photo = const PhotoDraft(),
    this.issues = const {},
    this.submitting = false,
    this.issued,
  });

  /// Names the card being filled in. Sent with every attempt, so trying
  /// again after a failure cannot add the member twice.
  final String cardId;
  final String name;
  final String phone;
  final String email;
  final PhotoDraft photo;
  final Map<NewCardField, ValidationIssue> issues;
  final bool submitting;

  /// Set once the card exists; the screen then shows and prints it.
  final IssuedCard? issued;

  NewCardState copyWith({
    String? name,
    String? phone,
    String? email,
    PhotoDraft? photo,
    Map<NewCardField, ValidationIssue>? issues,
    bool? submitting,
    IssuedCard? issued,
  }) {
    return NewCardState(
      cardId: cardId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photo: photo ?? this.photo,
      issues: issues ?? this.issues,
      submitting: submitting ?? this.submitting,
      issued: issued ?? this.issued,
    );
  }
}

/// A new ID card from a photo and a few details. The backend does the rest:
/// the membership number, the dates, and the card itself.
class NewCardViewModel extends Notifier<NewCardState>
    with PhotoDraftCommands<NewCardState> {
  @override
  NewCardState build() => NewCardState(cardId: ref.watch(newIdProvider)());

  void setName(String value) =>
      state = _clearing(NewCardField.name).copyWith(name: value);

  void setPhone(String value) =>
      state = _clearing(NewCardField.phone).copyWith(phone: value);

  void setEmail(String value) =>
      state = _clearing(NewCardField.email).copyWith(email: value);

  @override
  PhotoDraft get photo => state.photo;

  @override
  set photo(PhotoDraft value) {
    // A cropped photo answers "please add one". Picking or cancelling does not.
    final answered = value.cropped != state.photo.cropped;
    final current = answered ? _clearing(NewCardField.photo) : state;
    state = current.copyWith(photo: value);
  }

  NewCardState _clearing(NewCardField field) =>
      state.copyWith(issues: {...state.issues}..remove(field));

  /// Creates the card, or marks the fields that need attention.
  Future<void> submit() async {
    if (state.submitting) return;
    final photo = state.photo.cropped;
    final issues = {
      if (photo == null) NewCardField.photo: ValidationIssue.photoRequired,
      NewCardField.name: ?Validators.required(
        state.name,
        ValidationIssue.memberNameRequired,
      ),
      NewCardField.phone: ?Validators.phone(state.phone),
      NewCardField.email: ?Validators.optionalEmail(state.email),
    };
    state = state.copyWith(issues: issues);
    if (photo == null || issues.isNotEmpty) return;

    state = state.copyWith(submitting: true);
    final card = NewCard(
      id: state.cardId,
      name: state.name.trim(),
      phone: state.phone.trim(),
      email: state.email.trim(),
      photo: photo.bytes,
    );
    final result = await runCommand(
      ref,
      () => ref.read(cardRepositoryProvider).issue(card),
      notify: false,
      source: 'cards.issue',
    );
    if (!ref.mounted) return;
    switch (result) {
      case Ok(value: final issued):
        state = state.copyWith(submitting: false, issued: issued);
      case Err(:final failure):
        // A problem with a field is shown beside it; anything else is a toast.
        final rejected = _fieldIssues(failure);
        if (rejected.isEmpty) {
          ref.read(appMessengerProvider.notifier).showFailure(failure);
        }
        state = state.copyWith(submitting: false, issues: rejected);
    }
  }

  /// What the backend said about a field, if that is why it refused.
  static Map<NewCardField, ValidationIssue> _fieldIssues(AppFailure failure) {
    if (failure is! ValidationFailure) return const {};
    final fields = NewCardField.values.asNameMap();
    return {
      for (final MapEntry(:key, :value) in failure.issues.entries)
        ?fields[key]: value,
    };
  }

  /// Sends the card to a printer, as a print job called [title].
  Future<void> printCard(String title) => _withIssuedCard(
    (printer, card) => printer.print(card.pdf, name: title),
    'cards.print',
  );

  /// Opens the share sheet with the card, as a file named after [title].
  Future<void> shareCard(String title) => _withIssuedCard(
    (printer, card) => printer.share(card.pdf, fileName: '$title.pdf'),
    'cards.share',
  );

  Future<void> _withIssuedCard(
    Future<void> Function(DocumentPrinter printer, IssuedCard card) action,
    String source,
  ) async {
    final card = state.issued;
    if (card == null) return;
    await runCommand(
      ref,
      () => action(ref.read(documentPrinterProvider), card),
      source: source,
    );
  }

  /// Clears the form for the next person, who is a new card.
  void startAnother() => ref.invalidateSelf();
}

final newCardViewModelProvider =
    NotifierProvider.autoDispose<NewCardViewModel, NewCardState>(
      NewCardViewModel.new,
    );

/// The issued card's own pages as pictures, front then back: what is shown is
/// what will print. Derived from the card, so the two never disagree.
final cardPagesProvider = FutureProvider.autoDispose<List<MemoryPhoto>>((
  ref,
) async {
  final pdf = ref.watch(
    newCardViewModelProvider.select((state) => state.issued?.pdf),
  );
  if (pdf == null) return const [];
  final pages = await ref.watch(documentPrinterProvider).pages(pdf);
  return [for (final page in pages) MemoryPhoto(page)];
});
