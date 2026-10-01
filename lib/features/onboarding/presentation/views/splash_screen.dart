import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/decor.dart';
import '../../../settings/presentation/view_models/preferences_view_model.dart';

/// Brand screen shown on launch. Moves on by itself, or at once on a tap.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const autoAdvance = Duration(milliseconds: 2200);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen.autoAdvance, _continue);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _continue() {
    _timer?.cancel();
    if (!mounted) return;
    final seen = ref.read(preferencesProvider).onboardingSeen;
    context.go(seen ? AppRoutes.login : AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final l10n = context.l10n;

    Widget frame(double inset, double radius, double alpha) => Positioned.fill(
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppPalette.gold.withValues(alpha: alpha)),
          ),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: context.colors.accent,
        body: Semantics(
          button: true,
          label: l10n.tapToBegin,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _continue,
            child: SafeArea(
              child: Stack(
                children: [
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: PrayerFlagStripe(height: 8),
                  ),
                  frame(28, 28, 0.55),
                  frame(34, 24, 0.3),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          JewelLogo(
                            size: 104,
                            color: AppPalette.gold,
                            fill: AppPalette.gold.withValues(alpha: 0.12),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            l10n.appName,
                            textAlign: TextAlign.center,
                            style: type.serif(
                              40,
                              color: AppPalette.cream,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.appTagline,
                            textAlign: TextAlign.center,
                            style: type.sans(
                              17,
                              color: AppPalette.parchment,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 64,
                    child: Text(
                      l10n.tapToBegin,
                      textAlign: TextAlign.center,
                      style: type.sans(14, color: AppPalette.sand),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
