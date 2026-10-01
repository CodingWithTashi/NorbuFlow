import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/avatars.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/decor.dart';
import '../../../../core/widgets/tiles.dart';
import '../../../temple/domain/temple.dart';
import '../../../temple/presentation/view_models/temple_session.dart';
import '../../domain/member.dart';
import '../member_labels.dart';
import '../view_models/check_in_view_model.dart';
import '../view_models/members_view_model.dart';

/// Front-desk check-in: scan a member's card, or find them by name.
class CheckInScreen extends ConsumerWidget {
  const CheckInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;
    final state = ref.watch(checkInViewModelProvider);
    final viewModel = ref.read(checkInViewModelProvider.notifier);
    final matches = ref.watch(checkInMatchesProvider);
    final temple = ref.watch(currentTempleProvider);
    final demoMode = ref.watch(appConfigProvider).demoMode;
    final result = state.result;

    return AppPage(
      backLabel: l10n.navHome,
      onBack: () => context.popOrGo(AppRoutes.home),
      bottom: PrimaryButton(
        label: l10n.commonDone,
        onPressed: () => context.go(AppRoutes.home),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeading(title: l10n.checkInTitle),
          const SizedBox(height: 14),
          if (result != null && temple != null) ...[
            _CheckedInCard(checkIn: result, temple: temple),
            const SizedBox(height: 14),
            SecondaryButton(
              label: l10n.checkInAnother,
              onPressed: viewModel.reset,
            ),
          ] else ...[
            const _Viewfinder(),
            if (demoMode) ...[
              const SizedBox(height: 14),
              DemoButton(
                label: l10n.checkInDemoScan,
                onPressed: () {
                  // Stands in for decoding a QR code: the first member.
                  final members = ref.read(membersProvider).value;
                  if (members != null && members.isNotEmpty) {
                    viewModel.checkIn(members.first.id);
                  }
                },
              ),
            ],
          ],
          const SizedBox(height: 18),
          Text(l10n.checkInFindByName, style: type.sectionTitle),
          const SizedBox(height: 14),
          SearchField(
            value: state.query,
            hint: l10n.commonSearchHint,
            onChanged: viewModel.setQuery,
          ),
          const SizedBox(height: 14),
          if (matches.isNotEmpty)
            GroupedCard(
              children: [
                for (final member in matches)
                  ListRow(
                    title: member.nameEn,
                    subtitle: temple == null
                        ? null
                        : memberNumberLabel(temple, member.number),
                    minHeight: 64,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    onTap: state.busy
                        ? null
                        : () => viewModel.checkIn(member.id),
                    trailing: Text(
                      l10n.checkInAction,
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
}

/// Camera frame placeholder. Live scanning arrives with the camera plugin;
/// until then the demo button above stands in for a scan.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppPalette.espresso,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox.square(
            dimension: 170,
            child: CustomPaint(painter: _CornerBracketsPainter()),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Text(
              context.l10n.checkInPointCamera,
              textAlign: TextAlign.center,
              style: context.type.sans(15, color: AppPalette.sand, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerBracketsPainter extends CustomPainter {
  const _CornerBracketsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 34.0;
    final paint = Paint()
      ..color = AppPalette.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    final brackets = Path()
      ..moveTo(0, arm)
      ..lineTo(0, 0)
      ..lineTo(arm, 0)
      ..moveTo(w - arm, 0)
      ..lineTo(w, 0)
      ..lineTo(w, arm)
      ..moveTo(w, h - arm)
      ..lineTo(w, h)
      ..lineTo(w - arm, h)
      ..moveTo(arm, h)
      ..lineTo(0, h)
      ..lineTo(0, h - arm);
    canvas.drawPath(brackets, paint);
  }

  @override
  bool shouldRepaint(_CornerBracketsPainter oldDelegate) => false;
}

class _CheckedInCard extends ConsumerWidget {
  const _CheckedInCard({required this.checkIn, required this.temple});

  final CheckIn checkIn;
  final Temple temple;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = context.type;
    final l10n = context.l10n;
    final member = checkIn.member;
    final status = member.statusOn(ref.watch(todayProvider));
    final expiry = member.expiresOn;
    const ink = AppPalette.successFg;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppPalette.successBg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            PersonAvatar(
              name: member.nameEn,
              photo: member.photo,
              size: 60,
              background: Colors.white,
              foreground: ink,
              ringColor: AppPalette.success,
              ringWidth: 2,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconLabel(
                    icon: AppIcons.check,
                    label: member.nameEn,
                    style: type.sans(
                      19,
                      weight: FontWeight.w700,
                      color: ink,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.checkInAt(
                      Formats.time(checkIn.at),
                      memberNumberLabel(temple, member.number),
                    ),
                    style: type.sans(15, color: ink, height: 1.4),
                  ),
                  IconLabel(
                    icon: status.icon,
                    label: l10n.checkInStatus(
                      status.label(l10n).toLowerCase(),
                      expiry == null
                          ? l10n.commonLifetime
                          : Formats.date(expiry),
                    ),
                    style: type.sans(15, color: ink, height: 1.4),
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
