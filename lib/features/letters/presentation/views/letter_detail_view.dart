import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/tiles.dart';
import '../../domain/letter.dart';
import '../view_models/letter_on_file_view_model.dart';
import '../view_models/letters_view_model.dart';
import '../widgets/letter_page.dart';

/// A letter full-screen, reached from its row on phones.
class LetterDetailScreen extends StatelessWidget {
  const LetterDetailScreen({super.key, required this.letterId});

  final String letterId;

  @override
  Widget build(BuildContext context) {
    return LetterDetailView(
      letterId: letterId,
      backLabel: context.l10n.lettersTitle,
      onBack: () => context.popOrGo(AppRoutes.letters),
    );
  }
}

/// A letter on file: its page, and ways to print it, share it or write
/// another like it. On tablets, the pane beside the list.
class LetterDetailView extends ConsumerWidget {
  const LetterDetailView({
    super.key,
    required this.letterId,
    this.backLabel,
    this.onBack,
  });

  final String letterId;
  final String? backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(letterProvider(letterId)),
      onRetry: () => ref.invalidate(lettersProvider),
      data: (letter) => letter == null
          ? AppPage(
              backLabel: backLabel,
              onBack: onBack,
              child: MessageView(message: context.l10n.letterNotFound),
            )
          : _LetterPage(letter: letter, backLabel: backLabel, onBack: onBack),
    );
  }
}

class _LetterPage extends ConsumerWidget {
  const _LetterPage({required this.letter, this.backLabel, this.onBack});

  final Letter letter;
  final String? backLabel;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final type = context.type;
    final colors = context.colors;
    final actions = ref.read(letterActionsProvider);
    final onFile = letterOnFileProvider(letter.id);
    final title = l10n.letterDocumentName(letter.number);

    return AppPage(
      backLabel: backLabel,
      onBack: onBack,
      padding: EdgeInsets.fromLTRB(20, backLabel == null ? 20 : 0, 20, 16),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: l10n.letterPrint,
            icon: AppIcons.print,
            onPressed: () => actions.printLetter(letter.id, title),
          ),
          const SizedBox(height: 10),
          EqualRow(
            children: [
              SecondaryButton(
                label: l10n.letterShare,
                fontSize: 16,
                onPressed: () => actions.shareLetter(letter.id, title),
              ),
              SecondaryButton(
                label: l10n.letterAnotherLike,
                fontSize: 16,
                onPressed: () =>
                    context.go(AppRoutes.newLetter(like: letter.id)),
              ),
            ],
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(letter.name, style: type.screenTitle),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.letterNumber(letter.number),
                style: type.sans(16, color: colors.inkMuted, height: 1.4),
              ),
              if (letter.expiredOn(ref.watch(todayProvider)))
                StatusPill(
                  label: l10n.letterExpired,
                  icon: AppIcons.hours,
                  tone: PillTone.danger,
                ),
            ],
          ),
          const SizedBox(height: 18),
          AsyncValueView(
            value: ref.watch(onFile),
            onRetry: () => ref.invalidate(onFile),
            data: (found) => Center(child: LetterPageView(found.page)),
          ),
          const SizedBox(height: 18),
          GroupedCard(
            children: [
              ListRow(
                title: l10n.letterValidUntil(Formats.date(letter.validUntil)),
                subtitle: l10n.letterIssuedOn(Formats.date(letter.issuedOn)),
                minHeight: 64,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
