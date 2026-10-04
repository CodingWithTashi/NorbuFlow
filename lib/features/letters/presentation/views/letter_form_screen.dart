import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/error/failure_text.dart';
import '../../../../core/feedback/app_messenger.dart';
import '../../../../core/feedback/dialogs.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/formatted_text_field.dart';
import '../../../../core/widgets/success_view.dart';
import '../../../../core/widgets/tiles.dart';
import '../../../members/presentation/view_models/members_view_model.dart';
import '../../domain/letter.dart';
import '../view_models/letter_form_view_model.dart';
import '../view_models/letters_view_model.dart';
import '../widgets/letter_page.dart';

/// A support letter in three steps: what it says, the letter to check, the
/// letter to print. It may start from a [name] or from the letter [like].
class LetterFormScreen extends ConsumerStatefulWidget {
  const LetterFormScreen({super.key, this.name, this.like});

  final String? name;
  final String? like;

  @override
  ConsumerState<LetterFormScreen> createState() => _LetterFormScreenState();
}

class _LetterFormScreenState extends ConsumerState<LetterFormScreen> {
  LetterStart get _start => (name: widget.name, like: widget.like);

  LetterFormViewModel get _viewModel =>
      ref.read(letterFormViewModelProvider(_start).notifier);

  // Where each problem is said, so that it can be brought into view.
  final _nameKey = GlobalKey();
  final _bodyKey = GlobalKey();
  final _dateKey = GlobalKey();

  void _leave() => context.popOrGo(AppRoutes.letters);

  /// Asks for the preview. If the form has a problem instead, shows where:
  /// a long letter pushes what is said about it off the screen.
  Future<void> _previewLetter() async {
    await _viewModel.previewLetter();
    if (!mounted) return;
    final state = ref.read(letterFormViewModelProvider(_start));
    final issues = state.issues;
    final (problem, atEnd) = issues.containsKey(LetterField.name)
        ? (_nameKey, false)
        : issues.containsKey(LetterField.body) || state.tooLong != null
        ? (_bodyKey, true)
        : issues.containsKey(LetterField.validUntil)
        ? (_dateKey, true)
        : (null, false);
    if (problem == null) return;
    // What is wrong is drawn with the next frame, under the body if it is
    // about the body: so it is the field's foot that is brought into view.
    await WidgetsBinding.instance.endOfFrame;
    final shown = problem.currentContext;
    if (shown == null || !shown.mounted) return;
    await Scrollable.ensureVisible(
      shown,
      duration: const Duration(milliseconds: 250),
      alignmentPolicy: atEnd
          ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
          : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  /// A new letter with nothing in it: this form again if it began empty,
  /// else the plain one, without the name or wording this one began from.
  void _another() {
    if (widget.name == null && widget.like == null) {
      _viewModel.startAnother();
    } else {
      context.go(AppRoutes.newLetter());
    }
  }

  Future<void> _paste() async {
    final pasted = await _viewModel.pasteBody();
    if (!pasted && mounted) ref.toast(context.l10n.toastNothingToPaste);
  }

  Future<void> _useEarlier() async {
    final letter = await showAppSheet<Letter>(
      context: context,
      title: context.l10n.letterUseEarlierTitle,
      builder: (_) => const _EarlierLetters(),
    );
    if (letter != null && mounted) await _viewModel.useWordingOf(letter);
  }

  Future<void> _pickDate(DateTime current) async {
    final picked = await showAppSheet<DateTime>(
      context: context,
      title: context.l10n.letterValidUntilTitle,
      builder: (_) =>
          _DateSheet(initial: current, first: ref.read(todayProvider)),
    );
    if (picked != null && mounted) _viewModel.setValidUntil(picked);
  }

  Future<void> _editNumber() {
    _viewModel.editNumber();
    return showAppSheet<void>(
      context: context,
      title: context.l10n.letterNumberEditTitle,
      builder: (_) => _NumberSheet(start: _start),
    );
  }

  /// The number on the letter is another letter's: says so, and offers to
  /// choose a different one.
  Future<void> _resolveTaken(LetterNumberTaken taken) async {
    final l10n = context.l10n;
    final choose = await showConfirmDialog(
      context: context,
      title: l10n.letterNumberTakenTitle(taken.number),
      message: l10n.letterNumberTakenBody(taken.number, taken.name),
      confirmLabel: l10n.letterNumberChoose,
      cancelLabel: l10n.commonCancel,
    );
    if (!mounted) return;
    _viewModel.dismissTaken();
    if (choose) await _editNumber();
  }

  /// The form's letter: a spinner while it is drawn, the reason if it
  /// cannot be.
  Widget _page() {
    final page = letterFormPageProvider(_start);
    return AsyncValueView(
      value: ref.watch(page),
      onRetry: () => ref.invalidate(page),
      data: (page) =>
          page == null ? const SizedBox.shrink() : LetterPageView(page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = letterFormViewModelProvider(_start);
    final state = ref.watch(provider);
    ref.listen(provider.select((state) => state.taken), (_, taken) {
      if (taken != null) _resolveTaken(taken);
    });

    if (state.issued case final issued?) return _issued(issued);
    if (state.preview case final preview?) return _preview(state, preview);
    return _details(state);
  }

  Widget _details(LetterFormState state) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;

    String? error(LetterField field) {
      final issue = state.issues[field];
      return issue == null ? null : validationText(l10n, issue);
    }

    final matches = ref.watch(letterMemberMatchesProvider(_start));
    final memberId = state.memberId;
    final member = memberId == null
        ? null
        : ref.watch(memberProvider(memberId)).value;
    final dateError = error(LetterField.validUntil);

    return FormattedTextField(
      label: l10n.letterBodyLabel,
      hint: l10n.letterBodyHint,
      value: state.body,
      onChanged: _viewModel.setBody,
      errorText: switch (state.tooLong) {
        final lines? => l10n.letterTooLong(lines),
        null => error(LetterField.body),
      },
      onPaste: _paste,
      emptyActions: [
        LinkButton(label: l10n.letterUseEarlier, onPressed: _useEarlier),
      ],
      // While the body is being typed on a phone, its buttons take the
      // place of "Preview letter" above the keyboard.
      builder: (context, body, accessory) => AppPage(
        backLabel: l10n.lettersTitle,
        onBack: _leave,
        bottom:
            accessory ??
            PrimaryButton(
              label: l10n.letterPreviewCta,
              onPressed: _previewLetter,
              busy: state.busy,
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(l10n.letterNewTitle, style: type.screenTitle),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.letterNewIntro,
              style: type.sans(16, color: colors.inkMuted, height: 1.5),
            ),
            const SizedBox(height: 20),
            KeyedSubtree(
              key: _nameKey,
              child: AppTextField(
                label: l10n.letterNameLabel,
                hint: l10n.letterNameHint,
                value: state.name,
                onChanged: _viewModel.setName,
                errorText: error(LetterField.name),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                fontSize: 19,
              ),
            ),
            if (member != null) ...[
              const SizedBox(height: 8),
              IconLabel(
                icon: AppIcons.check,
                label: l10n.letterNameMember(member.number),
                style: type.sans(15, color: colors.inkMuted, height: 1.4),
              ),
            ],
            if (matches.isNotEmpty) ...[
              const SizedBox(height: 10),
              OverlineLabel(l10n.letterNameMatches),
              const SizedBox(height: 6),
              GroupedCard(
                children: [
                  for (final match in matches)
                    ListRow(
                      title: match.nameEn,
                      subtitle: match.number,
                      minHeight: 60,
                      onTap: () => _viewModel.pickMember(match),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            KeyedSubtree(key: _bodyKey, child: body),
            const SizedBox(height: 20),
            Column(
              key: _dateKey,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GroupedCard(
                  children: [
                    ListRow(
                      title: l10n.letterValidUntil(
                        Formats.date(state.validUntil),
                      ),
                      subtitle: state.datePicked
                          ? null
                          : l10n.letterValidUntilHelp,
                      onTap: () => _pickDate(state.validUntil),
                      trailing: Text(
                        l10n.letterValidUntilChange,
                        style: type.sans(
                          15,
                          weight: FontWeight.w700,
                          color: colors.accentText,
                        ),
                      ),
                    ),
                  ],
                ),
                if (dateError != null) ...[
                  const SizedBox(height: 8),
                  FieldError(dateError),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(LetterFormState state, LetterPreview preview) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    // What is being issued is the letter as it was previewed.
    final movable = !state.issuing;

    return AppPage(
      backLabel: l10n.letterPreviewBack,
      onBack: _viewModel.backToDetails,
      bottom: PrimaryButton(
        label: l10n.letterIssueCta,
        onPressed: _viewModel.save,
        busy: state.busy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.letterPreviewTitle, style: type.screenTitle),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.letterPreviewIntro,
            style: type.sans(16, color: colors.inkMuted, height: 1.5),
          ),
          // Above the page, so that what a tap does is seen just below it.
          if (state.lowest > 0) ...[
            const SizedBox(height: 16),
            Text(
              l10n.letterPositionHelp,
              style: type.sans(16, weight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 10),
            EqualRow(
              children: [
                SecondaryButton(
                  label: l10n.letterMoveUp,
                  icon: AppIcons.arrowUp,
                  fontSize: 16,
                  onPressed: movable && state.linesDown > 0
                      ? _viewModel.moveUp
                      : null,
                ),
                SecondaryButton(
                  label: l10n.letterMoveDown,
                  icon: AppIcons.arrowDown,
                  fontSize: 16,
                  onPressed: movable && state.linesDown < state.lowest
                      ? _viewModel.moveDown
                      : null,
                ),
              ],
            ),
            LinkButton(
              label: l10n.letterMoveMiddle,
              expand: true,
              onPressed: movable && state.linesDown != state.lowest ~/ 2
                  ? _viewModel.moveToMiddle
                  : null,
            ),
          ],
          const SizedBox(height: 12),
          // Faded while it is drawn again; the page before stays in place.
          AnimatedOpacity(
            opacity: state.busy ? 0.45 : 1,
            duration: const Duration(milliseconds: 150),
            child: Center(child: _page()),
          ),
          const SizedBox(height: 20),
          GroupedCard(
            children: [
              ListRow(
                title: l10n.letterNumber(preview.number),
                subtitle: state.number != null
                    ? l10n.letterPreviewNumberTyped
                    : l10n.letterPreviewNumberHelp,
                // Not while the letter is being drawn again or issued: the
                // sheet would be typed into over a letter that is changing.
                onTap: state.busy ? null : _editNumber,
                trailing: Text(
                  l10n.letterChangeNumber,
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

  Widget _issued(IssuedLetter issued) {
    final l10n = context.l10n;
    final letter = issued.letter;
    final title = l10n.letterDocumentName(letter.number);

    return SuccessView(
      title: l10n.letterReadyTitle,
      message: l10n.letterReadyBody(
        letter.name,
        letter.number,
        Formats.date(letter.validUntil),
      ),
      preview: _page(),
      primaryLabel: l10n.letterPrint,
      onPrimary: () => _viewModel.printLetter(title),
      onDone: _leave,
      shareActions: [
        ShareAction(
          icon: AppIcons.share,
          label: l10n.letterShare,
          onTap: () => _viewModel.shareLetter(title),
        ),
        ShareAction(
          icon: AppIcons.plus,
          label: l10n.letterAnother,
          onTap: _another,
        ),
      ],
    );
  }
}

/// "Change number": the one place a letter's number is typed by hand.
class _NumberSheet extends ConsumerWidget {
  const _NumberSheet({required this.start});

  final LetterStart start;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = letterFormViewModelProvider(start);
    final state = ref.watch(provider);
    final viewModel = ref.read(provider.notifier);
    final issue = state.issues[LetterField.number];

    Future<void> apply() async {
      final applied = await viewModel.applyNumber();
      if (applied && context.mounted) Navigator.of(context).pop();
    }

    Future<void> useNext() async {
      final applied = await viewModel.useNextNumber();
      if (applied && context.mounted) Navigator.of(context).pop();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.letterNumberEditHelp,
          style: context.type.sans(
            16,
            color: context.colors.inkMuted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: l10n.letterNumberEditLabel,
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
          label: l10n.letterNumberEditApply,
          onPressed: apply,
          busy: state.busy,
        ),
        const SizedBox(height: 4),
        // The way back from a number typed by hand, such as one in use.
        if (state.number != null)
          LinkButton(
            label: l10n.letterNumberUseNext,
            expand: true,
            onPressed: state.busy ? null : useNext,
          ),
        LinkButton(
          label: l10n.commonCancel,
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// A calendar to pick the last day the letter holds.
class _DateSheet extends StatefulWidget {
  const _DateSheet({required this.initial, required this.first});

  final DateTime initial;

  /// Today: a letter cannot end before it starts.
  final DateTime first;

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  // An unsaved choice, which a rule sees only once it is used.
  late DateTime _picked = widget.initial.isBefore(widget.first)
      ? widget.first
      : widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalendarDatePicker(
          initialDate: _picked,
          firstDate: widget.first,
          // The day the app takes for today, which is the one it rings.
          currentDate: widget.first,
          // Far enough for any letter, near enough to scroll to.
          lastDate: DateTime(widget.first.year + 10, 12, 31),
          onDateChanged: (date) => setState(() => _picked = date),
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: l10n.letterValidUntilApply(Formats.date(_picked)),
          onPressed: () => Navigator.of(context).pop(_picked),
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

/// The temple's letters, to start a new one from the wording of one.
class _EarlierLetters extends ConsumerWidget {
  const _EarlierLetters();

  /// The newest few: an older wording is found from the list itself.
  static const _shown = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return AsyncValueView(
      value: ref.watch(lettersProvider),
      onRetry: () => ref.invalidate(lettersProvider),
      data: (letters) => letters.isEmpty
          ? MessageView(message: l10n.lettersEmpty)
          : GroupedCard(
              children: [
                for (final letter in letters.take(_shown))
                  ListRow(
                    title: letter.name,
                    subtitle: l10n.letterRowSubtitle(
                      letter.number,
                      Formats.date(letter.validUntil),
                    ),
                    onTap: () => Navigator.of(context).pop(letter),
                  ),
              ],
            ),
    );
  }
}
