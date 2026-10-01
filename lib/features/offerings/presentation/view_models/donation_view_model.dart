import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/command.dart';
import '../../../../core/error/validation_issue.dart';
import '../../../../core/utils/validators.dart';
import '../../../members/domain/member.dart' show PaymentMethod;
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../data/offering_repositories.dart';
import '../../domain/offering.dart';

enum DonationField { donor, contact, note }

@immutable
class DonationState {
  const DonationState({
    required this.kind,
    this.donor = '',
    this.contact = '',
    this.note = '',
    this.amount = 50,
    this.payment = PaymentMethod.card,
    this.issues = const {},
    this.submitting = false,
    this.receipt,
  });

  static const amounts = [25, 50, 108, 250];

  final OfferingKind kind;
  final String donor;
  final String contact;
  final String note;
  final int amount;
  final PaymentMethod payment;
  final Map<DonationField, ValidationIssue> issues;
  final bool submitting;

  /// Set once saved; the screen then shows the confirmation.
  final Receipt? receipt;

  /// "Other" has no built-in purpose, so the note must say what it is for.
  bool get noteRequired => kind == OfferingKind.other;

  DonationState copyWith({
    String? donor,
    String? contact,
    String? note,
    int? amount,
    PaymentMethod? payment,
    Map<DonationField, ValidationIssue>? issues,
    bool? submitting,
    Receipt? receipt,
  }) {
    return DonationState(
      kind: kind,
      donor: donor ?? this.donor,
      contact: contact ?? this.contact,
      note: note ?? this.note,
      amount: amount ?? this.amount,
      payment: payment ?? this.payment,
      issues: issues ?? this.issues,
      submitting: submitting ?? this.submitting,
      receipt: receipt ?? this.receipt,
    );
  }
}

class DonationViewModel extends Notifier<DonationState> {
  DonationViewModel(this._kind);

  final OfferingKind _kind;

  @override
  DonationState build() => DonationState(kind: _kind);

  void setDonor(String value) =>
      state = _clearing(DonationField.donor).copyWith(donor: value);

  void setContact(String value) =>
      state = _clearing(DonationField.contact).copyWith(contact: value);

  void setNote(String value) =>
      state = _clearing(DonationField.note).copyWith(note: value);

  void setAmount(int amount) => state = state.copyWith(amount: amount);

  void setPayment(PaymentMethod payment) =>
      state = state.copyWith(payment: payment);

  DonationState _clearing(DonationField field) =>
      state.copyWith(issues: {...state.issues}..remove(field));

  Future<void> submit() async {
    final donor = Validators.required(
      state.donor,
      ValidationIssue.donorRequired,
    );
    final contact = Validators.optionalContact(state.contact);
    final note = state.noteRequired
        ? Validators.required(state.note, ValidationIssue.purposeRequired)
        : null;
    final issues = {
      DonationField.donor: ?donor,
      DonationField.contact: ?contact,
      DonationField.note: ?note,
    };
    state = state.copyWith(issues: issues);
    if (issues.isNotEmpty) return;

    state = state.copyWith(submitting: true);
    final templeId = ref.read(activeTempleIdProvider);
    final donation = Donation(
      kind: state.kind,
      donor: state.donor.trim(),
      contact: state.contact.trim(),
      note: state.note.trim(),
      amount: state.amount,
      payment: state.payment,
    );
    final result = await runCommand(
      ref,
      () => ref
          .read(offeringRepositoryProvider)
          .recordDonation(templeId, donation),
      source: 'offerings.recordDonation',
    );
    if (!ref.mounted) return;
    state = state.copyWith(submitting: false, receipt: result.valueOrNull);
  }
}

final donationViewModelProvider = NotifierProvider.autoDispose
    .family<DonationViewModel, DonationState, OfferingKind>(
      DonationViewModel.new,
    );
