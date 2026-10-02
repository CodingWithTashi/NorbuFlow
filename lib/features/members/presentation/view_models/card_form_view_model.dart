import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/command.dart';
import '../../../../core/error/result.dart';
import '../../../../core/error/validation_issue.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/models/phone_country.dart';
import '../../../../core/models/photo_source.dart';
import '../../../../core/services/device_country.dart';
import '../../../../core/services/document_printer.dart';
import '../../../../core/utils/ids.dart';
import '../../../../core/utils/validators.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../data/member_repositories.dart';
import '../../domain/card.dart';
import 'members_view_model.dart';
import 'photo_draft.dart';

/// What a card is made from. The names are also the field names the backend
/// reports a problem against.
enum CardField { photo, name, phone, email, number }

@immutable
class CardFormState {
  const CardFormState({
    required this.requestId,
    required this.country,
    this.memberId,
    this.name = '',
    this.phone = '',
    this.email = '',
    this.photo = const PhotoDraft(),
    this.photoOnFile,
    this.issues = const {},
    this.busy = false,
    this.number,
    this.numberInput = '',
    this.preview,
    this.previewed,
    this.taken,
    this.issued,
  });

  /// Names the card being asked for. Sent with every attempt, so trying
  /// again after a failure cannot add the member twice.
  final String requestId;

  /// Whose details these are. Null while adding a new member.
  final String? memberId;
  final String name;

  /// Where [phone] is from, and the number as typed inside that country.
  final PhoneCountry country;
  final String phone;
  final String email;

  /// A new photo being chosen. Left empty, a member on file keeps theirs.
  final PhotoDraft photo;

  /// The photo a member being edited has now.
  final PhotoSource? photoOnFile;
  final Map<CardField, ValidationIssue> issues;

  /// A card is being drawn or saved.
  final bool busy;

  /// The digits of a membership number typed by hand, once it is on the
  /// preview. Null leaves the number to the temple.
  final String? number;

  /// What is being typed into "Edit ID number".
  final String numberInput;

  /// The card as it would print. Set, the screen shows it for checking.
  final CardPreview? preview;

  /// What [preview] was drawn from: exactly what saving sends.
  final CardRequest? previewed;

  /// The number asked for is someone else's: the screen asks what to do.
  final NumberTaken? taken;

  /// Set once the card exists; the screen then shows and prints it.
  final IssuedCard? issued;

  bool get editing => memberId != null;

  CardFormState copyWith({
    String? name,
    PhoneCountry? country,
    String? phone,
    String? email,
    PhotoDraft? photo,
    Map<CardField, ValidationIssue>? issues,
    bool? busy,
    String? Function()? number,
    String? numberInput,
    CardPreview? Function()? preview,
    CardRequest? Function()? previewed,
    NumberTaken? Function()? taken,
    IssuedCard? issued,
  }) {
    return CardFormState(
      requestId: requestId,
      memberId: memberId,
      name: name ?? this.name,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photo: photo ?? this.photo,
      photoOnFile: photoOnFile,
      issues: issues ?? this.issues,
      busy: busy ?? this.busy,
      number: number == null ? this.number : number(),
      numberInput: numberInput ?? this.numberInput,
      preview: preview == null ? this.preview : preview(),
      previewed: previewed == null ? this.previewed : previewed(),
      taken: taken == null ? this.taken : taken(),
      issued: issued ?? this.issued,
    );
  }
}

/// An ID card from a photo and a few details, for a new member or [memberId].
/// It is previewed first, and the preview is where its number can be changed.
class CardFormViewModel extends Notifier<CardFormState>
    with PhotoDraftCommands<CardFormState> {
  CardFormViewModel(this.memberId);

  final String? memberId;

  static final _leadingZeros = RegExp('^0+');

  @override
  CardFormState build() {
    final requestId = ref.watch(newIdProvider)();
    final home = ref.watch(homePhoneCountryProvider);
    final id = memberId;
    // Read, not watched: the form starts from the member as they are now,
    // and saving them must not reset it.
    final member = id == null ? null : ref.read(memberProvider(id)).value;
    if (member == null) {
      return CardFormState(requestId: requestId, country: home, memberId: id);
    }
    final (country, phone) = PhoneNumbers.parse(member.phone, fallback: home);
    return CardFormState(
      requestId: requestId,
      memberId: id,
      name: member.nameEn,
      country: country,
      phone: phone,
      email: member.email,
      photoOnFile: member.photo,
    );
  }

  void setName(String value) =>
      state = _clearing(CardField.name).copyWith(name: value);

  void setCountry(PhoneCountry value) =>
      state = _clearing(CardField.phone).copyWith(country: value);

  void setPhone(String value) =>
      state = _clearing(CardField.phone).copyWith(phone: value);

  void setEmail(String value) =>
      state = _clearing(CardField.email).copyWith(email: value);

  void setNumberInput(String value) =>
      state = _clearing(CardField.number).copyWith(numberInput: value);

  @override
  PhotoDraft get photo => state.photo;

  @override
  set photo(PhotoDraft value) {
    // A cropped photo answers "please add one". Picking or cancelling does not.
    final answered = value.cropped != state.photo.cropped;
    final current = answered ? _clearing(CardField.photo) : state;
    state = current.copyWith(photo: value);
  }

  CardFormState _clearing(CardField field) =>
      state.copyWith(issues: {...state.issues}..remove(field));

  CardRequest get _request => CardRequest(
    id: state.requestId,
    memberId: memberId,
    name: state.name.trim(),
    phone: PhoneNumbers.compose(state.country, state.phone),
    email: state.email.trim(),
    photo: state.photo.cropped?.bytes,
    number: state.number,
  );

  /// Draws the card for checking, or marks the fields that need attention.
  /// Nothing is saved.
  Future<void> previewCard() async {
    if (state.busy) return;
    final issues = {
      // A member on file already has a photo.
      if (!state.editing && state.photo.cropped == null)
        CardField.photo: ValidationIssue.photoRequired,
      CardField.name: ?Validators.required(
        state.name,
        ValidationIssue.memberNameRequired,
      ),
      CardField.phone: ?Validators.optionalPhone(state.phone, state.country),
      CardField.email: ?Validators.optionalEmail(state.email),
    };
    state = state.copyWith(issues: issues);
    if (issues.isEmpty) await _draw();
  }

  /// Starts "Edit ID number" from the number on the preview.
  void editNumber() => state = _clearing(
    CardField.number,
  ).copyWith(numberInput: state.preview?.number ?? '');

  /// Puts the number that was typed on the card and draws it again. False
  /// if it cannot be used, with the reason against [CardField.number].
  Future<bool> applyNumber() async {
    if (state.busy) return false;
    final typed = state.numberInput.trim();
    if (Validators.memberNumber(typed) case final issue?) {
      state = state.copyWith(
        issues: {...state.issues, CardField.number: issue},
      );
      return false;
    }
    final digits = typed.replaceFirst(_leadingZeros, '');
    // The number the card already carries: nothing was typed by hand.
    if (digits == state.preview?.number) return true;
    final before = state.number;
    state = state.copyWith(number: () => digits);
    final drawn = await _draw(numberShown: true);
    // A number that could not be drawn is not the card's number.
    if (!drawn && ref.mounted) state = state.copyWith(number: () => before);
    return drawn;
  }

  Future<bool> _draw({bool numberShown = false}) async {
    state = state.copyWith(busy: true);
    final request = _request;
    final result = await runCommand(
      ref,
      () => ref
          .read(cardRepositoryProvider)
          .preview(ref.read(activeTempleIdProvider), request),
      notify: false,
      source: 'cards.preview',
    );
    if (!ref.mounted) return false;
    switch (result) {
      case Ok(value: final preview):
        state = state.copyWith(
          busy: false,
          preview: () => preview,
          previewed: () => request,
          numberInput: preview.number,
        );
        return true;
      case Err(:final failure):
        _refused(failure, numberShown: numberShown);
        return false;
    }
  }

  /// Leaves the preview to change the details.
  void backToDetails() {
    if (state.busy) return;
    state = state.copyWith(
      preview: () => null,
      previewed: () => null,
      taken: () => null,
    );
  }

  /// Makes the card that was previewed. A number someone else holds saves
  /// nothing and sets [CardFormState.taken], unless a new member [replace]s.
  Future<void> save({bool replace = false}) async {
    final request = state.previewed;
    if (state.busy || request == null) return;
    state = state.copyWith(busy: true, taken: () => null);
    // Held now: the list is told even if this form is left before the answer.
    final members = ref.read(membersProvider.notifier);
    final result = await runCommand(
      ref,
      () => ref
          .read(cardRepositoryProvider)
          .issue(
            ref.read(activeTempleIdProvider),
            request,
            // A member on file changes their own record, never another's.
            replace: replace && !state.editing,
          ),
      notify: false,
      source: 'cards.issue',
    );
    // The list, and every screen that reads it, has them at once.
    if (result case Ok(value: CardIssued(:final card))) {
      members.put(card.member);
    }
    if (!ref.mounted) return;
    switch (result) {
      case Ok(value: CardIssued(:final card)):
        state = state.copyWith(busy: false, issued: card);
      case Ok(value: final NumberTaken taken):
        state = state.copyWith(busy: false, taken: () => taken);
      case Err(:final failure):
        _refused(failure);
    }
  }

  /// The person chose not to act on [CardFormState.taken].
  void dismissTaken() => state = state.copyWith(taken: () => null);

  /// A problem with a field is shown beside it; anything else is a toast.
  /// The number's field is on screen only while its sheet is ([numberShown]).
  void _refused(AppFailure failure, {bool numberShown = false}) {
    final rejected = _fieldIssues(failure);
    // The details are on the form, so a problem with one goes back to it.
    final onForm = rejected.keys.any((field) => field != CardField.number);
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
  static Map<CardField, ValidationIssue> _fieldIssues(AppFailure failure) {
    if (failure is! ValidationFailure) return const {};
    final fields = CardField.values.asNameMap();
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

final cardFormViewModelProvider = NotifierProvider.autoDispose
    .family<CardFormViewModel, CardFormState, String?>(CardFormViewModel.new);

/// The form's card as pictures, front then back: the preview, then the card
/// that was issued. What is shown is what will print.
final cardFormPagesProvider = FutureProvider.autoDispose
    .family<List<MemoryPhoto>, String?>((ref, memberId) {
      final pdf = ref.watch(
        cardFormViewModelProvider(
          memberId,
        ).select((state) => state.issued?.pdf ?? state.preview?.pdf),
      );
      if (pdf == null) return const [];
      return ref.watch(documentPrinterProvider).photos(pdf);
    });
