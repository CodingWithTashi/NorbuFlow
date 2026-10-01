import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/failure_text.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../core/widgets/success_view.dart';
import '../../../members/domain/member.dart' show PaymentMethod;
import '../../../members/presentation/member_labels.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../domain/offering.dart';
import '../offering_labels.dart';
import '../receipt_sharing.dart';
import '../view_models/donation_view_model.dart';

/// Records a donation, butter lamp, building-fund gift or other offering and
/// issues its receipt.
class DonationScreen extends ConsumerWidget {
  const DonationScreen({super.key, required this.kind});

  final OfferingKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = context.type;
    final l10n = context.l10n;
    final provider = donationViewModelProvider(kind);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);
    final temple = ref.watch(currentTempleProvider);
    final kindLabel = kind.label(l10n);

    final receipt = state.receipt;
    if (receipt != null && temple != null) {
      return SuccessView(
        title: l10n.offeringRecordedTitle,
        message: l10n.offeringRecordedDonation(
          Formats.money(receipt.amount),
          kindLabel.toLowerCase(),
          receipt.receivedFrom,
          receipt.number,
        ),
        primaryLabel: l10n.offeringViewReceipt,
        onPrimary: () => context.go(AppRoutes.receipt(receipt.number)),
        onDone: () => context.go(AppRoutes.offerings),
        shareActions: receiptShareActions(
          context,
          ref,
          receipt: receipt,
          temple: temple,
        ),
      );
    }

    String? error(DonationField field) {
      final issue = state.issues[field];
      return issue == null ? null : validationText(l10n, issue);
    }

    return AppPage(
      backLabel: l10n.navOfferings,
      onBack: () => context.popOrGo(AppRoutes.offerings),
      bottom: PrimaryButton(
        label: l10n.donationSubmit(
          Formats.money(state.amount),
          kindLabel.toLowerCase(),
        ),
        onPressed: viewModel.submit,
        busy: state.submitting,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeading(title: kindLabel, subtitle: l10n.donationSubtitle),
          const SizedBox(height: 16),
          AppTextField(
            label: l10n.donationDonor,
            hint: l10n.addFieldNameEnHint,
            value: state.donor,
            onChanged: viewModel.setDonor,
            errorText: error(DonationField.donor),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: l10n.pujaReceiptContact,
            optionalTag: l10n.commonOptional,
            hint: l10n.commonEmailHint,
            value: state.contact,
            onChanged: viewModel.setContact,
            errorText: error(DonationField.contact),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: state.noteRequired
                ? l10n.donationNoteOther
                : l10n.donationNote,
            optionalTag: state.noteRequired ? null : l10n.commonOptional,
            hint: kind.noteHint(l10n),
            value: state.note,
            onChanged: viewModel.setNote,
            errorText: error(DonationField.note),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          Text(l10n.commonAmount, style: type.sectionTitle),
          const SizedBox(height: 16),
          AmountPicker(
            amounts: DonationState.amounts,
            selected: state.amount,
            onChanged: viewModel.setAmount,
            format: Formats.money,
          ),
          const SizedBox(height: 16),
          Text(l10n.commonPayment, style: type.sectionTitle),
          const SizedBox(height: 16),
          ResponsiveGrid(
            minItemWidth: 150,
            maxColumns: 2,
            spacing: 10,
            children: [
              for (final method in PaymentMethod.values)
                ChoiceButton(
                  label: method.label(l10n),
                  selected: method == state.payment,
                  onTap: () => viewModel.setPayment(method),
                  minHeight: 56,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
