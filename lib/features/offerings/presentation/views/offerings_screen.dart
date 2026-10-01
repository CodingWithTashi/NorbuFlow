import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/layout/breakpoints.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/tiles.dart';
import '../../domain/offering.dart';

/// "What is this payment for?" — one tile per kind of offering.
class OfferingsScreen extends StatelessWidget {
  const OfferingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final l10n = context.l10n;

    String donation(OfferingKind kind) => AppRoutes.donation(kind.name);
    final tiles = [
      (
        AppIcons.idCard,
        l10n.offeringMembership,
        l10n.offeringMembershipSub,
        AppRoutes.members,
      ),
      (
        AppIcons.heart,
        l10n.offeringDonation,
        l10n.offeringDonationSub,
        donation(OfferingKind.donation),
      ),
      (AppIcons.bell, l10n.offeringPuja, l10n.offeringPujaSub, AppRoutes.puja),
      (AppIcons.bowl, l10n.offeringTsok, l10n.offeringTsokSub, AppRoutes.tsok),
      (
        AppIcons.lamp,
        l10n.offeringButterLamp,
        l10n.offeringButterLampSub,
        donation(OfferingKind.butterLamp),
      ),
      (
        AppIcons.building,
        l10n.offeringBuildingFund,
        l10n.offeringBuildingFundSub,
        donation(OfferingKind.buildingFund),
      ),
      (
        AppIcons.plus,
        l10n.offeringOther,
        l10n.offeringOtherSub,
        donation(OfferingKind.other),
      ),
    ];

    return AppPage(
      maxWidth: Breakpoints.wideContentMaxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.offeringsTitle, style: type.screenTitle),
          ),
          const SizedBox(height: 4),
          Text(l10n.offeringsAsk, style: type.sans(17, color: colors.inkMuted)),
          const SizedBox(height: 16),
          ResponsiveGrid(
            minItemWidth: 164,
            maxColumns: 4,
            spacing: 12,
            children: [
              for (final (icon, title, subtitle, location) in tiles)
                ActionTile(
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                  minHeight: 128,
                  chipSize: 44,
                  titleLines: 1,
                  onTap: () => context.go(location),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
