import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/validation_issue.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/member.dart';
import 'members_view_model.dart';
import 'photo_draft.dart';

enum AddMemberStep { photo, details, type, payment }

enum AddMemberField { nameEn, phone, email }

@immutable
class AddMemberState {
  const AddMemberState({
    this.step = AddMemberStep.photo,
    this.nameEn = '',
    this.nameBo = '',
    this.phone = '',
    this.email = '',
    this.type = MembershipType.family,
    this.payment = PaymentMethod.card,
    this.photo = const PhotoDraft(),
    this.issues = const {},
    this.submitting = false,
    this.created,
  });

  final AddMemberStep step;
  final String nameEn;
  final String nameBo;
  final String phone;
  final String email;
  final MembershipType type;
  final PaymentMethod payment;
  final PhotoDraft photo;
  final Map<AddMemberField, ValidationIssue> issues;
  final bool submitting;

  /// Set once the member has been saved; the screen then shows the
  /// confirmation.
  final Member? created;

  AddMemberState copyWith({
    AddMemberStep? step,
    String? nameEn,
    String? nameBo,
    String? phone,
    String? email,
    MembershipType? type,
    PaymentMethod? payment,
    PhotoDraft? photo,
    Map<AddMemberField, ValidationIssue>? issues,
    bool? submitting,
    Member? created,
  }) {
    return AddMemberState(
      step: step ?? this.step,
      nameEn: nameEn ?? this.nameEn,
      nameBo: nameBo ?? this.nameBo,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      type: type ?? this.type,
      payment: payment ?? this.payment,
      photo: photo ?? this.photo,
      issues: issues ?? this.issues,
      submitting: submitting ?? this.submitting,
      created: created ?? this.created,
    );
  }
}

class AddMemberViewModel extends Notifier<AddMemberState>
    with PhotoDraftCommands<AddMemberState> {
  @override
  AddMemberState build() => const AddMemberState();

  @override
  PhotoDraft get photo => state.photo;

  @override
  set photo(PhotoDraft value) => state = state.copyWith(photo: value);

  void setNameEn(String value) =>
      state = _clearing(AddMemberField.nameEn).copyWith(nameEn: value);

  void setNameBo(String value) => state = state.copyWith(nameBo: value);

  void setPhone(String value) =>
      state = _clearing(AddMemberField.phone).copyWith(phone: value);

  void setEmail(String value) =>
      state = _clearing(AddMemberField.email).copyWith(email: value);

  void setType(MembershipType type) => state = state.copyWith(type: type);

  void setPayment(PaymentMethod payment) =>
      state = state.copyWith(payment: payment);

  AddMemberState _clearing(AddMemberField field) =>
      state.copyWith(issues: {...state.issues}..remove(field));

  /// Returns false when already on the first step, so the screen can leave.
  bool back() {
    if (state.step == AddMemberStep.photo) return false;
    state = state.copyWith(step: AddMemberStep.values[state.step.index - 1]);
    return true;
  }

  /// Moves forward, validating the details step and saving on the last one.
  Future<void> next() async {
    switch (state.step) {
      case AddMemberStep.photo || AddMemberStep.type:
        _advance();
      case AddMemberStep.details:
        final issues = _validate();
        state = state.copyWith(issues: issues);
        if (issues.isEmpty) _advance();
      case AddMemberStep.payment:
        await _submit();
    }
  }

  void _advance() =>
      state = state.copyWith(step: AddMemberStep.values[state.step.index + 1]);

  Map<AddMemberField, ValidationIssue> _validate() {
    final name = Validators.required(
      state.nameEn,
      ValidationIssue.memberNameRequired,
    );
    final phone = Validators.phone(state.phone);
    final email = Validators.optionalEmail(state.email);
    return {
      AddMemberField.nameEn: ?name,
      AddMemberField.phone: ?phone,
      AddMemberField.email: ?email,
    };
  }

  Future<void> _submit() async {
    state = state.copyWith(submitting: true);
    final result = await ref
        .read(membersProvider.notifier)
        .add(
          NewMember(
            nameEn: state.nameEn,
            nameBo: state.nameBo,
            phone: state.phone,
            email: state.email,
            type: state.type,
            payment: state.payment,
            photo: state.photo.cropped,
          ),
        );
    if (!ref.mounted) return;
    state = state.copyWith(submitting: false, created: result.valueOrNull);
  }
}

final addMemberViewModelProvider =
    NotifierProvider.autoDispose<AddMemberViewModel, AddMemberState>(
      AddMemberViewModel.new,
    );

/// What the new member's number and expiry will be, shown before saving.
@immutable
class NewMemberPreview {
  const NewMemberPreview({required this.number, required this.expiresOn});

  final int number;

  /// Null for a life membership.
  final DateTime? expiresOn;
}

final newMemberPreviewProvider = Provider.autoDispose<NewMemberPreview>((ref) {
  final members = ref.watch(membersProvider).value ?? const <Member>[];
  final type = ref.watch(addMemberViewModelProvider.select((s) => s.type));
  final highest = members.fold(0, (max, m) => m.number > max ? m.number : max);
  return NewMemberPreview(
    number: highest + 1,
    expiresOn: type.isLifetime ? null : ref.watch(todayProvider).plusOneYear,
  );
});
