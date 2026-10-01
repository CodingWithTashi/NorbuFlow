import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/failure_text.dart';
import '../../../../core/error/validation_issue.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/feedback/dialogs.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/tiles.dart';
import '../../../outbox/domain/outbox.dart';
import '../../../outbox/presentation/outbox_actions.dart';
import '../../../outbox/presentation/send_preview_sheet.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../domain/report.dart';
import '../view_models/report_view_models.dart';

/// Year-end tax receipts: one per donor, sent together once every donor has
/// a mailing address on file.
class TaxReceiptsScreen extends ConsumerWidget {
  const TaxReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(taxViewModelProvider);
    final temple = ref.watch(currentTempleProvider);
    final value = summary.value;

    Future<void> emailAll(TaxSummary tax) async {
      final sent = await showSendPreview(
        context,
        OutgoingMessage(
          channel: DeliveryChannel.email,
          recipient: l10n.msgTaxTo(tax.donorCount),
          body: l10n.msgTaxBody(
            tax.year,
            temple?.nameEn ?? '',
            temple?.charityRegistration ?? '',
          ),
          attachment: l10n.msgTaxAttachment(tax.donorCount),
        ),
      );
      if (!sent) return;
      ref.toast(
        tax.missingAddresses == 0
            ? l10n.toastTaxSent(tax.readyCount)
            : l10n.toastTaxSentWaiting(tax.readyCount, tax.missingAddresses),
      );
    }

    Future<void> openDonor(Donor donor) async {
      if (donor.hasAddress) return ref.toast(l10n.toastTaxReady(donor.name));
      final saved = await showAppSheet<bool>(
        context: context,
        title: l10n.taxAddressTitle(donor.name),
        builder: (_) => _AddressForm(donor: donor),
      );
      if (saved ?? false) ref.toast(l10n.toastTaxAddressSaved(donor.name));
    }

    return AppPage(
      backLabel: l10n.navHome,
      onBack: () => context.popOrGo(AppRoutes.home),
      bottom: value == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PrimaryButton(
                  label: l10n.taxEmailAll,
                  onPressed: () => emailAll(value),
                ),
                LinkButton(
                  label: l10n.taxDownloadAll,
                  minHeight: 48,
                  expand: true,
                  onPressed: () async {
                    final saved = await ref
                        .read(outboxActionsProvider)
                        .export(l10n.taxTitle, ExportFormat.pdf);
                    if (saved) ref.toast(l10n.toastTaxPdf(value.donorCount));
                  },
                ),
              ],
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeading(
            title: l10n.taxTitle,
            subtitle: value == null ? null : l10n.taxSubtitle(value.year),
          ),
          const SizedBox(height: 14),
          AsyncValueView(
            value: summary,
            onRetry: () => ref.invalidate(taxViewModelProvider),
            data: (tax) => _TaxBody(tax: tax, onOpenDonor: openDonor),
          ),
        ],
      ),
    );
  }
}

class _TaxBody extends StatelessWidget {
  const _TaxBody({required this.tax, required this.onOpenDonor});

  final TaxSummary tax;
  final ValueChanged<Donor> onOpenDonor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;

    Widget stat(String value, String label) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: type.serif(32, height: 1.1)),
          const SizedBox(height: 2),
          Text(label, style: type.sans(15, color: colors.inkMuted)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EqualRow(
          children: [
            stat('${tax.donorCount}', l10n.taxDonors),
            stat(Formats.money(tax.totalGiven), l10n.taxTotalGiven),
          ],
        ),
        if (tax.missingAddresses > 0) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppPalette.warningBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: AppIcon(
                    AppIcons.hours,
                    size: 18,
                    color: AppPalette.warningInk,
                    strokeWidth: 2.2,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: l10n.taxMissingLead(tax.missingAddresses),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      children: [
                        TextSpan(
                          text: ' ${l10n.taxMissingRest}',
                          style: const TextStyle(fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                    style: type.sans(
                      16,
                      color: AppPalette.warningInk,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        GroupedCard(
          children: [
            for (final donor in tax.topDonors)
              ListRow(
                title: donor.name,
                subtitle: l10n.taxDonorMeta(
                  donor.gifts,
                  Formats.money(donor.total),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                onTap: () => onOpenDonor(donor),
                trailing: StatusPill(
                  label: donor.hasAddress
                      ? l10n.taxReady
                      : l10n.taxNeedsAddress,
                  icon: donor.hasAddress ? AppIcons.check : null,
                  tone: donor.hasAddress ? PillTone.success : PillTone.warning,
                ),
              ),
            if (tax.donorCount > tax.topDonors.length)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  l10n.taxMoreDonors(tax.donorCount - tax.topDonors.length),
                  style: type.sans(15, color: colors.inkMuted),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Collects the mailing address a donor's receipt is missing.
class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm({required this.donor});

  final Donor donor;

  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
  String _address = '';
  ValidationIssue? _issue;
  bool _saving = false;

  Future<void> _save() async {
    final viewModel = ref.read(taxViewModelProvider.notifier);
    final issue = viewModel.validateAddress(_address);
    if (issue != null) {
      setState(() => _issue = issue);
      return;
    }
    setState(() => _saving = true);
    final saved = await viewModel.saveAddress(widget.donor, _address);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: l10n.taxAddressLabel,
          hint: l10n.taxAddressHint,
          value: _address,
          onChanged: (value) => setState(() {
            _address = value;
            _issue = null;
          }),
          errorText: _issue == null ? null : validationText(l10n, _issue!),
          minLines: 2,
          maxLines: 4,
          keyboardType: TextInputType.streetAddress,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: l10n.taxAddressSave,
          onPressed: _save,
          busy: _saving,
        ),
        LinkButton(
          label: l10n.commonCancel,
          expand: true,
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
