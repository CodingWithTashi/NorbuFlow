import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/failure_text.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/feedback/dialogs.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/phone_field.dart';
import '../../../../core/widgets/success_view.dart';
import '../../../../core/widgets/tiles.dart';
import '../../domain/card.dart';
import '../view_models/card_form_view_model.dart';
import '../view_models/members_view_model.dart';
import '../widgets/card_pages.dart';
import '../widgets/photo_cropper.dart';
import '../widgets/photo_field.dart';

/// Changes a member's details: the card form, opened once they are known.
class EditMemberScreen extends ConsumerWidget {
  const EditMemberScreen({super.key, required this.memberId});

  final String memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return AsyncValueView(
      value: ref.watch(memberProvider(memberId)),
      onRetry: () => ref.invalidate(membersProvider),
      data: (member) => member == null
          ? AppPage(
              backLabel: l10n.navMembers,
              onBack: () => context.popOrGo(AppRoutes.members),
              child: MessageView(message: l10n.cardNotFound),
            )
          : CardFormScreen(memberId: memberId),
    );
  }
}

/// An ID card in three steps: details, the card to check, the card to print.
/// For a new member, or with [memberId] for one on file.
class CardFormScreen extends ConsumerStatefulWidget {
  const CardFormScreen({super.key, this.memberId});

  final String? memberId;

  @override
  ConsumerState<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends ConsumerState<CardFormScreen> {
  final _crop = PhotoCropController(shape: const PhotoCropShape.idCard());

  @override
  void dispose() {
    _crop.dispose();
    super.dispose();
  }

  String? get _memberId => widget.memberId;

  bool get _editing => _memberId != null;

  CardFormViewModel get _viewModel =>
      ref.read(cardFormViewModelProvider(_memberId).notifier);

  Future<void> _usePhoto() async {
    final cropped = await _crop.export(size: CardPhoto.longSide);
    if (!mounted) return;
    _viewModel.useCroppedPhoto(cropped);
    ref.toast(context.l10n.toastPhotoCropped);
  }

  Future<void> _editNumber() {
    _viewModel.editNumber();
    return showAppSheet<void>(
      context: context,
      title: context.l10n.cardNumberEditTitle,
      builder: (_) => _NumberSheet(memberId: _memberId),
    );
  }

  /// The number on the card is someone else's: asks what to do about it.
  Future<void> _resolveTaken(NumberTaken taken) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.cardNumberTakenTitle(taken.number),
      message: _editing
          ? l10n.cardNumberTakenEditBody(taken.number, taken.name)
          : l10n.cardNumberTakenBody(taken.number, taken.name),
      confirmLabel: _editing ? l10n.cardNumberChoose : l10n.cardNumberReplace,
      cancelLabel: l10n.commonCancel,
    );
    if (!mounted) return;
    if (confirmed && !_editing) {
      await _viewModel.save(replace: true);
      return;
    }
    _viewModel.dismissTaken();
    if (confirmed) await _editNumber();
  }

  /// The form's card: a spinner while it is drawn, the reason if it cannot be.
  Widget _card({bool frontOnly = false}) {
    final pages = cardFormPagesProvider(_memberId);
    return AsyncValueView(
      value: ref.watch(pages),
      onRetry: () => ref.invalidate(pages),
      data: (pages) => CardPages(pages, frontOnly: frontOnly),
    );
  }

  void _leave() => context.popOrGo(
    _editing ? AppRoutes.member(_memberId!) : AppRoutes.members,
  );

  @override
  Widget build(BuildContext context) {
    final provider = cardFormViewModelProvider(_memberId);
    final state = ref.watch(provider);
    ref.listen(provider.select((state) => state.taken), (_, taken) {
      if (taken != null) _resolveTaken(taken);
    });

    if (state.issued case final issued?) return _issued(issued);
    if (state.preview case final preview?) return _preview(state, preview);
    return _details(state);
  }

  Widget _details(CardFormState state) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;

    String? error(CardField field) {
      final issue = state.issues[field];
      return issue == null ? null : validationText(l10n, issue);
    }

    return AppPage(
      backLabel: _editing ? l10n.commonBack : l10n.navMembers,
      onBack: _leave,
      bottom: state.photo.cropping
          ? PrimaryButton(label: l10n.addUseThisPhoto, onPressed: _usePhoto)
          : PrimaryButton(
              label: l10n.cardFormPreview,
              onPressed: _viewModel.previewCard,
              busy: state.busy,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              _editing ? l10n.cardFormEditTitle : l10n.newCardTitle,
              style: type.screenTitle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _editing ? l10n.cardFormEditIntro : l10n.newCardIntro,
            style: type.sans(16, color: colors.inkMuted, height: 1.5),
          ),
          const SizedBox(height: 20),
          PhotoField(
            photo: state.photo,
            current: state.photoOnFile,
            crop: _crop,
            onPick: _viewModel.pickPhoto,
            onAdjustCrop: _viewModel.reopenCrop,
            onCancelCrop: _viewModel.cancelCrop,
            // Said only while the photo on file is the one being shown.
            help: state.photoOnFile != null && state.photo.cropped == null
                ? l10n.cardFormKeepPhoto
                : l10n.newCardPhotoHelp,
            cropHelp: l10n.newCardCropHelp,
            errorText: error(CardField.photo),
          ),
          if (!state.photo.cropping) ...[
            const SizedBox(height: 20),
            AppTextField(
              label: l10n.newCardNameLabel,
              hint: l10n.addFieldNameEnHint,
              value: state.name,
              onChanged: _viewModel.setName,
              errorText: error(CardField.name),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              fontSize: 19,
            ),
            const SizedBox(height: 18),
            PhoneField(
              label: l10n.addFieldPhone,
              optionalTag: l10n.commonOptional,
              hint: l10n.addFieldPhoneHint,
              country: state.country,
              onCountryChanged: _viewModel.setCountry,
              value: state.phone,
              onChanged: _viewModel.setPhone,
              errorText: error(CardField.phone),
              textInputAction: TextInputAction.next,
              fontSize: 19,
            ),
            const SizedBox(height: 18),
            AppTextField(
              label: l10n.addFieldEmail,
              optionalTag: l10n.commonOptional,
              hint: l10n.commonEmailHint,
              value: state.email,
              onChanged: _viewModel.setEmail,
              errorText: error(CardField.email),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              fontSize: 19,
            ),
          ],
        ],
      ),
    );
  }

  Widget _preview(CardFormState state, CardPreview preview) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;

    return AppPage(
      backLabel: l10n.cardPreviewBack,
      onBack: _viewModel.backToDetails,
      bottom: PrimaryButton(
        label: _editing ? l10n.cardPreviewSave : l10n.newCardSubmit,
        onPressed: _viewModel.save,
        busy: state.busy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.cardPreviewTitle, style: type.screenTitle),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.cardPreviewIntro,
            style: type.sans(16, color: colors.inkMuted, height: 1.5),
          ),
          const SizedBox(height: 20),
          Center(child: _card(frontOnly: true)),
          const SizedBox(height: 20),
          GroupedCard(
            children: [
              ListRow(
                title: l10n.cardPreviewNumber(preview.label),
                subtitle: state.number != null
                    ? l10n.cardPreviewNumberTyped
                    : _editing
                    ? l10n.cardPreviewNumberKept
                    : l10n.cardPreviewNumberHelp,
                onTap: _editNumber,
                trailing: Text(
                  l10n.cardPreviewEditNumber,
                  style: type.sans(
                    15,
                    weight: FontWeight.w700,
                    color: colors.accentText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _issued(IssuedCard issued) {
    final l10n = context.l10n;
    final member = issued.member;
    final expiry = member.expiresOn;
    final title = l10n.newCardDocumentName(member.number);

    return SuccessView(
      title: _editing ? l10n.cardSavedTitle : l10n.newCardReadyTitle,
      message: l10n.newCardReadyBody(
        member.nameEn,
        member.number,
        expiry == null ? l10n.commonLifetime : Formats.date(expiry),
      ),
      preview: _card(),
      primaryLabel: l10n.newCardPrint,
      onPrimary: () => _viewModel.printCard(title),
      onDone: _leave,
      shareActions: [
        ShareAction(
          icon: AppIcons.share,
          label: l10n.newCardShare,
          onTap: () => _viewModel.shareCard(title),
        ),
        if (!_editing)
          ShareAction(
            icon: AppIcons.plus,
            label: l10n.newCardAnother,
            onTap: _viewModel.startAnother,
          ),
      ],
    );
  }
}

/// "Edit ID number": the one place a membership number is typed by hand.
class _NumberSheet extends ConsumerWidget {
  const _NumberSheet({required this.memberId});

  final String? memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = cardFormViewModelProvider(memberId);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);
    final issue = state.issues[CardField.number];

    Future<void> apply() async {
      final applied = await viewModel.applyNumber();
      if (applied && context.mounted) Navigator.of(context).pop();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.cardNumberEditHelp,
          style: context.type.sans(
            16,
            color: context.colors.inkMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: l10n.cardNumberEditLabel,
          value: state.numberInput,
          onChanged: viewModel.setNumberInput,
          onSubmitted: (_) => apply(),
          errorText: issue == null ? null : validationText(l10n, issue),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          fontSize: 19,
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: l10n.cardNumberEditApply,
          onPressed: apply,
          busy: state.busy,
        ),
        const SizedBox(height: 4),
        LinkButton(
          label: l10n.commonCancel,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
