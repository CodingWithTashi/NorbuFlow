import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/failure_text.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/success_view.dart';
import '../../domain/card.dart';
import '../view_models/new_card_view_model.dart';
import '../widgets/card_pages.dart';
import '../widgets/photo_cropper.dart';
import '../widgets/photo_field.dart';

/// New ID card: a photo and a name in, a print-ready card out. The
/// membership number and expiry come from the backend.
class NewCardScreen extends ConsumerStatefulWidget {
  const NewCardScreen({super.key});

  @override
  ConsumerState<NewCardScreen> createState() => _NewCardScreenState();
}

class _NewCardScreenState extends ConsumerState<NewCardScreen> {
  final _crop = PhotoCropController(shape: const PhotoCropShape.idCard());

  @override
  void dispose() {
    _crop.dispose();
    super.dispose();
  }

  NewCardViewModel get _viewModel =>
      ref.read(newCardViewModelProvider.notifier);

  Future<void> _usePhoto() async {
    _viewModel.useCroppedPhoto(await _crop.export(size: CardPhoto.longSide));
    if (mounted) ref.toast(context.l10n.toastPhotoCropped);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final state = ref.watch(newCardViewModelProvider);
    void toMembers() => context.popOrGo(AppRoutes.members);

    final issued = state.issued;
    if (issued != null) {
      final title = l10n.newCardDocumentName(issued.number);
      return SuccessView(
        title: l10n.newCardReadyTitle,
        message: l10n.newCardReadyBody(
          issued.name,
          issued.number,
          Formats.date(issued.expiresOn),
        ),
        preview: CardPages(ref.watch(cardPagesProvider).value ?? const []),
        primaryLabel: l10n.newCardPrint,
        onPrimary: () => _viewModel.printCard(title),
        onDone: toMembers,
        shareActions: [
          ShareAction(
            icon: AppIcons.share,
            label: l10n.newCardShare,
            onTap: () => _viewModel.shareCard(title),
          ),
          ShareAction(
            icon: AppIcons.plus,
            label: l10n.newCardAnother,
            onTap: _viewModel.startAnother,
          ),
        ],
      );
    }

    String? error(NewCardField field) {
      final issue = state.issues[field];
      return issue == null ? null : validationText(l10n, issue);
    }

    return AppPage(
      backLabel: l10n.navMembers,
      onBack: toMembers,
      bottom: state.photo.cropping
          ? PrimaryButton(label: l10n.addUseThisPhoto, onPressed: _usePhoto)
          : PrimaryButton(
              label: l10n.newCardSubmit,
              onPressed: _viewModel.submit,
              busy: state.submitting,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.newCardTitle, style: type.screenTitle),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.newCardIntro,
            style: type.sans(16, color: colors.inkMuted, height: 1.5),
          ),
          const SizedBox(height: 20),
          PhotoField(
            photo: state.photo,
            crop: _crop,
            onPick: _viewModel.pickPhoto,
            onAdjustCrop: _viewModel.reopenCrop,
            onCancelCrop: _viewModel.cancelCrop,
            help: l10n.newCardPhotoHelp,
            cropHelp: l10n.newCardCropHelp,
            errorText: error(NewCardField.photo),
          ),
          if (!state.photo.cropping) ...[
            const SizedBox(height: 20),
            AppTextField(
              label: l10n.newCardNameLabel,
              hint: l10n.addFieldNameEnHint,
              value: state.name,
              onChanged: _viewModel.setName,
              errorText: error(NewCardField.name),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              fontSize: 19,
            ),
            const SizedBox(height: 18),
            AppTextField(
              label: l10n.addFieldPhone,
              hint: l10n.addFieldPhoneHint,
              value: state.phone,
              onChanged: _viewModel.setPhone,
              errorText: error(NewCardField.phone),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              fontSize: 19,
            ),
            const SizedBox(height: 18),
            AppTextField(
              label: l10n.addFieldEmail,
              optionalTag: l10n.commonOptional,
              hint: l10n.commonEmailHint,
              value: state.email,
              onChanged: _viewModel.setEmail,
              errorText: error(NewCardField.email),
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
}
