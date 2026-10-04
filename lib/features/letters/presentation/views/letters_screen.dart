import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../domain/letter.dart';
import '../view_models/letters_view_model.dart';
import 'letter_detail_view.dart';

/// The support letters the temple has issued. On phones a row opens the
/// letter; on tablets it appears beside the list.
class LettersScreen extends ConsumerWidget {
  const LettersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= Breakpoints.expanded;
        if (!twoPane) {
          return _LetterList(
            onOpen: (letter) => context.go(AppRoutes.letterOnFile(letter.id)),
          );
        }
        final selectedId = ref.watch(selectedLetterProvider);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 400,
              child: _LetterList(
                selectedId: selectedId,
                onOpen: (letter) =>
                    ref.read(selectedLetterProvider.notifier).select(letter.id),
              ),
            ),
            VerticalDivider(width: 1, color: context.colors.line),
            Expanded(
              child: selectedId == null
                  ? MessageView(message: context.l10n.lettersSelectHint)
                  : LetterDetailView(
                      key: ValueKey(selectedId),
                      letterId: selectedId,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _LetterList extends ConsumerWidget {
  const _LetterList({required this.onOpen, this.selectedId});

  final ValueChanged<Letter> onOpen;

  /// Highlighted row in the two-pane layout.
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final list = ref.watch(letterListProvider);
    final today = ref.watch(todayProvider);
    final query = ref.watch(letterSearchProvider);

    return ColoredBox(
      color: colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: BackLink(
                label: l10n.navHome,
                onPressed: () => context.popOrGo(AppRoutes.home),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(l10n.lettersTitle, style: type.screenTitle),
                ),
                const SizedBox(height: 6),
                if (list.value case final state?)
                  StatusPill(
                    label: state.isSearching
                        ? l10n.lettersFoundCount(state.visible.length)
                        : l10n.lettersCount(state.total),
                    tone: PillTone.plain,
                    height: 30,
                    fontSize: 14,
                  ),
                const SizedBox(height: 12),
                SearchField(
                  value: query,
                  hint: l10n.lettersSearchHint,
                  onChanged: ref.read(letterSearchProvider.notifier).setQuery,
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: list,
              onRetry: () => ref.invalidate(lettersProvider),
              data: (state) {
                if (state.visible.isEmpty) {
                  return MessageView(
                    message: state.isSearching
                        ? l10n.lettersNoResults(state.query.trim())
                        : l10n.lettersEmpty,
                  );
                }
                return RefreshIndicator(
                  color: colors.accentText,
                  backgroundColor: colors.surface,
                  onRefresh: ref.read(lettersProvider.notifier).refresh,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: state.visible.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, color: colors.line),
                    itemBuilder: (context, index) {
                      final letter = state.visible[index];
                      return _LetterRow(
                        letter: letter,
                        expired: letter.expiredOn(today),
                        selected: letter.id == selectedId,
                        onTap: () => onOpen(letter),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          BottomActionBar(
            child: PrimaryButton(
              label: l10n.lettersNewCta,
              onPressed: () => context.go(AppRoutes.newLetter()),
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterRow extends StatelessWidget {
  const _LetterRow({
    required this.letter,
    required this.expired,
    required this.selected,
    required this.onTap,
  });

  final Letter letter;
  final bool expired;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    return Material(
      color: selected ? colors.card : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        letter.name,
                        style: type.sans(
                          18,
                          weight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.letterRowSubtitle(
                          letter.number,
                          Formats.date(letter.validUntil),
                        ),
                        style: type.sans(
                          14,
                          color: colors.inkMuted,
                          height: 1.4,
                        ),
                      ),
                      if (expired) ...[
                        const SizedBox(height: 6),
                        StatusPill(
                          label: l10n.letterExpired,
                          icon: AppIcons.hours,
                          tone: PillTone.danger,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AppIcon(
                  AppIcons.chevronRight,
                  size: 20,
                  color: colors.inkMuted,
                  strokeWidth: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
