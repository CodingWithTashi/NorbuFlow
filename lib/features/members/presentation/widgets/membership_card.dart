import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/avatars.dart';
import '../../../../core/widgets/decor.dart';
import '../../../temple/domain/temple.dart';
import '../../domain/member.dart';
import '../member_labels.dart';

/// The digital membership ID card. It is a document, so it keeps its light
/// "paper" look in dark mode and always matches what gets printed.
class MembershipCard extends StatelessWidget {
  const MembershipCard({super.key, required this.member, required this.temple});

  final Member member;
  final Temple temple;

  static const width = 310.0;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final l10n = context.l10n;
    final number = member.number;
    final expiry = member.expiresOn;

    Widget fact(
      String label,
      String value, {
      FontWeight weight = FontWeight.w700,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: type.sans(12, color: AppPalette.paperLabel, height: 1.4),
          ),
          Text(
            value,
            style: type.sans(
              16,
              weight: weight,
              color: AppPalette.paperInk,
              height: 1.4,
            ),
          ),
        ],
      );
    }

    return Container(
      width: width,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppPalette.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppPalette.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppPalette.espresso.withValues(alpha: 0.22),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppPalette.gold),
            ),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: context.colors.accent,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Row(
                    children: [
                      TempleBadge(
                        monogram: temple.monogram,
                        logo: temple.logo,
                        background: Colors.transparent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              temple.nameEn,
                              style: type.serif(
                                16,
                                weight: FontWeight.w600,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                            if (temple.nameBo.isNotEmpty)
                              Text(
                                temple.nameBo,
                                style: type.tibetan(
                                  14,
                                  color: AppPalette.parchment,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const PrayerFlagStripe(),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.2,
                      colors: [AppPalette.parchment, AppPalette.paper],
                      stops: [0, 0.7],
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        l10n.cardTitle.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: type.sans(
                          12,
                          weight: FontWeight.w600,
                          color: AppPalette.paperLabel,
                          letterSpacing: 1.7,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppPalette.paper,
                          border: Border.all(
                            color: AppPalette.gold,
                            width: 1.5,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          ),
                        ),
                        child: PersonAvatar(
                          name: member.nameEn,
                          photo: member.photo,
                          size: 104,
                          background: AppPalette.parchment,
                          foreground: context.colors.accent,
                          ringWidth: 0,
                          ringColor: Colors.transparent,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        member.nameEn,
                        textAlign: TextAlign.center,
                        style: type.serif(
                          23,
                          color: AppPalette.paperInk,
                          height: 1.25,
                        ),
                      ),
                      if (member.nameBo.isNotEmpty)
                        Text(
                          member.nameBo,
                          textAlign: TextAlign.center,
                          style: type.tibetan(
                            19,
                            color: AppPalette.paperInkSoft,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(color: AppPalette.paperLine),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: fact(l10n.cardMemberNo, number),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: fact(
                                    l10n.cardValidUntil,
                                    expiry == null
                                        ? l10n.commonLifetime
                                        : Formats.date(expiry),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            fact(
                              l10n.cardType,
                              member.type.label(l10n),
                              weight: FontWeight.w600,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppPalette.paperLine),
                        ),
                        // Encodes the member number the check-in desk scans.
                        child: QrImageView(
                          data: number,
                          size: 100,
                          padding: EdgeInsets.zero,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppPalette.paperInk,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppPalette.paperInk,
                          ),
                          semanticsLabel: number,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned(top: 6, left: 6, child: _CornerDiamond()),
          const Positioned(top: 6, right: 6, child: _CornerDiamond()),
        ],
      ),
    );
  }
}

class _CornerDiamond extends StatelessWidget {
  const _CornerDiamond();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398,
      child: const SizedBox.square(
        dimension: 8,
        child: ColoredBox(color: AppPalette.gold),
      ),
    );
  }
}
