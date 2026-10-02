import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/avatars.dart';
import '../../../../core/widgets/decor.dart';
import '../../domain/temple.dart';
import '../temple_labels.dart';
import '../view_models/temple_session.dart';
import '../widgets/add_temple_locked.dart';

/// First screen after sign-in: choose which temple to work in. Choosing one
/// is what lets the router into the app.
class TemplePickerScreen extends ConsumerWidget {
  const TemplePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final temples = ref.watch(templesProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: AsyncValueView(
          value: temples,
          onRetry: () => ref.invalidate(templesProvider),
          data: (memberships) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ContentFrame(
              maxWidth: 960,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.templesTitle, style: type.serif(28)),
                  const SizedBox(height: 6),
                  Text(
                    l10n.templesBody(memberships.length),
                    style: type.sans(17, color: colors.inkMuted, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  ResponsiveGrid(
                    minItemWidth: 320,
                    minColumns: 1,
                    maxColumns: 2,
                    spacing: 18,
                    children: [
                      for (final membership in memberships)
                        _TempleCard(
                          membership: membership,
                          onTap: () => ref
                              .read(currentTempleIdProvider.notifier)
                              .select(membership.temple.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const AddTempleLocked(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TempleCard extends StatelessWidget {
  const _TempleCard({required this.membership, required this.onTap});

  final TempleMembership membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final temple = membership.temple;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.line, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 88),
              color: temple.accent.color,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  TempleBadge(
                    monogram: temple.monogram,
                    logo: temple.logo,
                    size: 56,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          temple.nameEn,
                          style: type.serif(
                            20,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (temple.nameBo.isNotEmpty)
                          Text(
                            temple.nameBo,
                            style: type.tibetan(
                              17,
                              color: AppPalette.parchment,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const PrayerFlagStripe(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (temple.tradition.isNotEmpty) ...[
                    Text(
                      temple.tradition,
                      style: type.sans(16, color: colors.inkMuted),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    context.l10n.templesYouAre(
                      membership.role.label(context.l10n),
                    ),
                    style: type.sans(17, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
