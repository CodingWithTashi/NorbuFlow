import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/failure_text.dart';
import '../../../../core/error/validation_issue.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/services/photo_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/avatars.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/selection.dart';
import '../../../../core/widgets/success_view.dart';
import '../../../outbox/domain/outbox.dart';
import '../../../outbox/presentation/outbox_actions.dart';
import '../../../outbox/presentation/send_preview_sheet.dart';
import '../../../temple/domain/temple.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../domain/member.dart';
import '../member_labels.dart';
import '../view_models/add_member_view_model.dart';
import '../widgets/photo_cropper.dart';

/// Add a Member: photo → details → membership type → payment, ending on a
/// confirmation with the new ID card one tap away.
class AddMemberScreen extends ConsumerStatefulWidget {
  const AddMemberScreen({super.key});

  @override
  ConsumerState<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends ConsumerState<AddMemberScreen> {
  final _crop = PhotoCropController();

  @override
  void dispose() {
    _crop.dispose();
    super.dispose();
  }

  AddMemberViewModel get _viewModel =>
      ref.read(addMemberViewModelProvider.notifier);

  Future<void> _next(AddMemberState state) async {
    if (!state.cropping) return _viewModel.next();
    _viewModel.useCroppedPhoto(await _crop.export());
    if (mounted) ref.toast(context.l10n.toastPhotoCropped);
  }

  void _back() {
    if (!_viewModel.back()) context.popOrGo(AppRoutes.members);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(addMemberViewModelProvider);
    final temple = ref.watch(currentTempleProvider);

    // Opening the crop editor (first pick or "Adjust the crop") loads the
    // original image into the controller.
    ref.listen(addMemberViewModelProvider.select((s) => s.cropping), (_, now) {
      final original = ref.read(addMemberViewModelProvider).photoOriginal;
      if (now && original != null) _crop.load(original);
    });

    final created = state.created;
    if (created != null && temple != null) {
      return _AddedView(member: created, temple: temple);
    }

    final String nextLabel;
    if (state.cropping) {
      nextLabel = l10n.addUseThisPhoto;
    } else if (state.step == AddMemberStep.payment) {
      nextLabel = l10n.addSubmit(Formats.money(state.type.fee));
    } else {
      nextLabel = l10n.commonNext;
    }

    return WizardScaffold(
      flowName: l10n.addFlowName,
      step: state.step.index + 1,
      stepCount: AddMemberStep.values.length,
      title: switch (state.step) {
        AddMemberStep.photo => l10n.addStepPhoto,
        AddMemberStep.details => l10n.addStepDetails,
        AddMemberStep.type => l10n.addStepType,
        AddMemberStep.payment => l10n.addStepPayment,
      },
      onBack: _back,
      nextLabel: nextLabel,
      onNext: () => _next(state),
      busy: state.submitting,
      child: switch (state.step) {
        AddMemberStep.photo => _PhotoStep(state: state, crop: _crop),
        AddMemberStep.details => _DetailsStep(state: state),
        AddMemberStep.type => _TypeStep(state: state, temple: temple),
        AddMemberStep.payment => _PaymentStep(state: state, temple: temple),
      },
    );
  }
}

class _PhotoStep extends ConsumerWidget {
  const _PhotoStep({required this.state, required this.crop});

  final AddMemberState state;
  final PhotoCropController crop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final viewModel = ref.read(addMemberViewModelProvider.notifier);

    if (state.cropping) {
      return Column(
        children: [
          PhotoCropper(controller: crop),
          const SizedBox(height: 8),
          Text(
            l10n.addCropHelp,
            textAlign: TextAlign.center,
            style: type.sans(16, color: colors.inkMuted, height: 1.5),
          ),
          LinkButton(
            label: l10n.addChooseDifferentPhoto,
            onPressed: viewModel.cancelCrop,
          ),
        ],
      );
    }

    Widget pickButton(AppIconData icon, String label, PhotoOrigin origin) {
      return Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppPalette.amber, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => viewModel.pickPhoto(origin),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 104),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppIcon(icon, size: 28, color: colors.accentText),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: type.sans(17, weight: FontWeight.w700, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final photo = state.photo;
    return Column(
      children: [
        if (photo != null) ...[
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppPalette.gold,
                width: 2,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: ClipOval(
              child: SizedBox.square(dimension: 200, child: PhotoImage(photo)),
            ),
          ),
          const SizedBox(height: 16),
          IconLabel(
            icon: AppIcons.check,
            label: l10n.addPhotoReady,
            style: type.sans(
              17,
              weight: FontWeight.w600,
              color: colors.success,
            ),
          ),
          LinkButton(
            label: l10n.addAdjustCrop,
            underline: true,
            onPressed: viewModel.reopenCrop,
          ),
        ] else ...[
          CustomPaint(
            foregroundPainter: _DashedCirclePainter(AppPalette.gold),
            child: Container(
              width: 200,
              height: 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.card,
              ),
              child: AppIcon(
                AppIcons.person,
                size: 72,
                color: colors.inkMuted,
                strokeWidth: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        EqualRow(
          gap: 12,
          children: [
            pickButton(AppIcons.camera, l10n.addTakePhoto, PhotoOrigin.camera),
            pickButton(
              AppIcons.image,
              l10n.addUploadPhoto,
              PhotoOrigin.gallery,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.addPhotoHelp,
          textAlign: TextAlign.center,
          style: type.sans(15, color: colors.inkMuted, height: 1.5),
        ),
      ],
    );
  }
}

class _DetailsStep extends ConsumerWidget {
  const _DetailsStep({required this.state});

  final AddMemberState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final viewModel = ref.read(addMemberViewModelProvider.notifier);
    String? error(AddMemberField field) {
      final ValidationIssue? issue = state.issues[field];
      return issue == null ? null : validationText(l10n, issue);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: l10n.addFieldNameEn,
          hint: l10n.addFieldNameEnHint,
          value: state.nameEn,
          onChanged: viewModel.setNameEn,
          errorText: error(AddMemberField.nameEn),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          fontSize: 19,
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: l10n.addFieldNameBo,
          optionalTag: l10n.commonOptional,
          hint: l10n.addFieldNameBoHint,
          value: state.nameBo,
          onChanged: viewModel.setNameBo,
          textInputAction: TextInputAction.next,
          fontSize: 19,
        ),
        const SizedBox(height: 18),
        AppTextField(
          label: l10n.addFieldPhone,
          hint: l10n.addFieldPhoneHint,
          value: state.phone,
          onChanged: viewModel.setPhone,
          errorText: error(AddMemberField.phone),
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
          onChanged: viewModel.setEmail,
          errorText: error(AddMemberField.email),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          fontSize: 19,
        ),
      ],
    );
  }
}

class _TypeStep extends ConsumerWidget {
  const _TypeStep({required this.state, required this.temple});

  final AddMemberState state;
  final Temple? temple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final viewModel = ref.read(addMemberViewModelProvider.notifier);
    final preview = ref.watch(newMemberPreviewProvider);

    Widget fact(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: type.sans(16, color: colors.inkMuted)),
          const SizedBox(width: 12),
          Text(value, style: type.sans(17, weight: FontWeight.w700)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in MembershipType.values) ...[
          OptionTile(
            title: option.label(l10n),
            subtitle: option.description(l10n),
            selected: option == state.type,
            onTap: () => viewModel.setType(option),
            minHeight: 76,
            titleWeight: FontWeight.w600,
            trailing: Text(
              Formats.money(option.fee),
              style: type.serif(18, height: 1.2),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.gold, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: OverlineLabel(l10n.addFilledForYou),
              ),
              Divider(height: 1, color: colors.line),
              if (temple != null)
                fact(
                  l10n.addMemberNumber,
                  memberNumberLabel(temple!, preview.number),
                ),
              Divider(height: 1, color: colors.line),
              fact(
                l10n.addValidUntil,
                preview.expiresOn == null
                    ? l10n.commonLifetime
                    : Formats.date(preview.expiresOn!),
              ),
              Divider(height: 1, color: colors.line),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Text(
                  l10n.addRenewalReminders,
                  style: type.sans(15, color: colors.inkMuted, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentStep extends ConsumerWidget {
  const _PaymentStep({required this.state, required this.temple});

  final AddMemberState state;
  final Temple? temple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final viewModel = ref.read(addMemberViewModelProvider.notifier);
    final preview = ref.watch(newMemberPreviewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.addSummaryLine(
                  state.nameEn.trim(),
                  state.type.label(l10n),
                ),
                style: type.sans(15, color: colors.inkMuted),
              ),
              const SizedBox(height: 6),
              Text(
                Formats.moneyExact(state.type.fee),
                style: type.serif(34, height: 1.2),
              ),
              const SizedBox(height: 6),
              if (temple != null)
                Text(
                  l10n.addSummaryMeta(
                    memberNumberLabel(temple!, preview.number),
                    preview.expiresOn == null
                        ? l10n.commonLifetime
                        : Formats.date(preview.expiresOn!),
                  ),
                  style: type.sans(15, color: colors.inkMuted),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.addHowPaying, style: type.sans(17, weight: FontWeight.w600)),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minItemWidth: 150,
          maxColumns: 2,
          spacing: 12,
          children: [
            for (final method in PaymentMethod.values)
              ChoiceButton(
                label: method.label(l10n),
                selected: method == state.payment,
                onTap: () => viewModel.setPayment(method),
                minHeight: 64,
              ),
          ],
        ),
      ],
    );
  }
}

/// "Tenzin is now a member" with ways to pass on the new ID card.
class _AddedView extends ConsumerWidget {
  const _AddedView({required this.member, required this.temple});

  final Member member;
  final Temple temple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final number = memberNumberLabel(temple, member.number);

    Future<void> send(DeliveryChannel channel) async {
      final whatsApp = channel == DeliveryChannel.whatsApp;
      final sent = await showSendPreview(
        context,
        OutgoingMessage(
          channel: channel,
          recipient: whatsApp
              ? '${member.nameEn} · ${member.phone}'
              : (member.email.isEmpty ? l10n.commonEmDash : member.email),
          body: l10n.msgCardBody(firstNameOf(member.nameEn), temple.nameEn),
          attachment: l10n.msgCardAttachment(number),
        ),
      );
      if (sent) {
        ref.toast(whatsApp ? l10n.toastSentWhatsApp : l10n.toastSentEmail);
      }
    }

    return SuccessView(
      title: l10n.addSuccessTitle(member.nameEn),
      message: l10n.addSuccessBody(number),
      primaryLabel: l10n.addViewCard,
      onPrimary: () => context.go(AppRoutes.member(member.id)),
      onDone: () => context.go(AppRoutes.members),
      shareActions: [
        ShareAction(
          icon: AppIcons.print,
          label: l10n.commonPrint,
          onTap: () async {
            if (await ref.read(outboxActionsProvider).printDocument(number)) {
              ref.toast(l10n.toastPrinted);
            }
          },
        ),
        ShareAction(
          icon: AppIcons.mail,
          label: l10n.commonEmail,
          onTap: () => send(DeliveryChannel.email),
        ),
        ShareAction(
          icon: AppIcons.chat,
          label: l10n.commonWhatsApp,
          onTap: () => send(DeliveryChannel.whatsApp),
        ),
      ],
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final outline = Path()..addOval((Offset.zero & size).deflate(1));
    for (final metric in outline.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += 14) {
        canvas.drawPath(metric.extractPath(at, at + 8), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
