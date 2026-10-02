import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/clock.dart';
import '../../features/announcements/presentation/views/announcement_screen.dart';
import '../../features/announcements/presentation/views/approve_screen.dart';
import '../../features/auth/presentation/view_models/auth_view_model.dart';
import '../../features/auth/presentation/views/check_email_screen.dart';
import '../../features/auth/presentation/views/login_screen.dart';
import '../../features/home/presentation/views/home_screen.dart';
import '../../features/members/presentation/views/add_member_screen.dart';
import '../../features/members/presentation/views/card_form_screen.dart';
import '../../features/members/presentation/views/check_in_screen.dart';
import '../../features/members/presentation/views/member_card_view.dart';
import '../../features/members/presentation/views/member_detail_view.dart';
import '../../features/members/presentation/views/members_screen.dart';
import '../../features/offerings/domain/offering.dart';
import '../../features/offerings/presentation/views/donation_screen.dart';
import '../../features/offerings/presentation/views/offerings_screen.dart';
import '../../features/offerings/presentation/views/prayer_lists_screen.dart';
import '../../features/offerings/presentation/views/puja_screen.dart';
import '../../features/offerings/presentation/views/receipt_screen.dart';
import '../../features/onboarding/presentation/views/onboarding_screen.dart';
import '../../features/onboarding/presentation/views/splash_screen.dart';
import '../../features/reports/presentation/views/reports_screen.dart';
import '../../features/reports/presentation/views/tax_receipts_screen.dart';
import '../../features/settings/presentation/views/more_screen.dart';
import '../../features/temple/presentation/view_models/temple_session.dart';
import '../../features/temple/presentation/views/team_screen.dart';
import '../../features/temple/presentation/views/temple_picker_screen.dart';
import '../../features/temple/presentation/views/temple_settings_screen.dart';
import '../../features/volunteers/presentation/views/assign_screen.dart';
import '../../features/volunteers/presentation/views/calendar_screen.dart';
import '../../features/volunteers/presentation/views/hours_screen.dart';
import '../../features/volunteers/presentation/views/letter_screen.dart';
import '../../features/volunteers/presentation/views/plan_screen.dart';
import '../shell/app_shell.dart';
import 'app_routes.dart';

/// The app's routes, and the one rule for who may be where: signed out →
/// sign-in; no temple chosen → temple picker; otherwise → the app.
final routerProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect whenever the session or the chosen temple changes.
  final sessionChanged = ValueNotifier(0);
  ref
    ..listen(authViewModelProvider, (_, _) => sessionChanged.value++)
    ..listen(currentTempleIdProvider, (_, _) => sessionChanged.value++)
    ..onDispose(sessionChanged.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: sessionChanged,
    redirect: (context, state) {
      final signedIn = ref.read(authViewModelProvider).isSignedIn;
      final hasTemple = ref.read(currentTempleIdProvider) != null;
      final location = state.matchedLocation;
      final public = AppRoutes.public.contains(location);

      if (!signedIn) return public ? null : AppRoutes.login;
      if (!hasTemple) {
        return location == AppRoutes.temples ? null : AppRoutes.temples;
      }
      if (public || location == AppRoutes.temples) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.checkEmail,
        builder: (_, _) => const CheckEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.temples,
        builder: (_, _) => const TemplePickerScreen(),
      ),
      // Branch order is the tab order in AppShell.
      StatefulShellRoute.indexedStack(
        builder: (_, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          location: state.uri.path,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'letter',
                    builder: (_, state) => LetterScreen(
                      volunteerId: state.uri.queryParameters['volunteer'],
                    ),
                  ),
                  GoRoute(
                    path: 'announce',
                    builder: (_, _) => const AnnouncementScreen(),
                  ),
                  GoRoute(
                    path: 'hours',
                    builder: (_, _) => const HoursScreen(),
                  ),
                  GoRoute(
                    path: 'reports',
                    builder: (_, _) => const ReportsScreen(),
                  ),
                  GoRoute(
                    path: 'tax',
                    builder: (_, _) => const TaxReceiptsScreen(),
                  ),
                  GoRoute(
                    path: 'prayers',
                    builder: (_, _) => const PrayerListsScreen(),
                  ),
                  GoRoute(
                    path: 'approve',
                    builder: (_, _) => const ApproveScreen(),
                  ),
                  GoRoute(
                    path: 'check-in',
                    builder: (_, _) => const CheckInScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.members,
                builder: (_, _) => const MembersScreen(),
                routes: [
                  // Before ':memberId' so "add" and "card" are not read as ids.
                  GoRoute(
                    path: 'add',
                    // With the backend on, a member is added by the flow that
                    // issues their real number and card.
                    redirect: (_, _) => ref.read(appConfigProvider).demoMembers
                        ? null
                        : AppRoutes.newCard,
                    builder: (_, _) => const AddMemberScreen(),
                  ),
                  GoRoute(
                    path: 'card',
                    builder: (_, _) => const CardFormScreen(),
                  ),
                  GoRoute(
                    path: ':memberId',
                    // The demo draws a card; the backend's is the printed one.
                    builder: (_, state) {
                      final memberId = state.pathParameters['memberId']!;
                      return ref.read(appConfigProvider).demoMembers
                          ? MemberCardScreen(memberId: memberId)
                          : MemberDetailScreen(memberId: memberId);
                    },
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (_, state) => EditMemberScreen(
                          memberId: state.pathParameters['memberId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.offerings,
                builder: (_, _) => const OfferingsScreen(),
                routes: [
                  GoRoute(
                    path: 'donation/:kind',
                    builder: (_, state) => DonationScreen(
                      kind:
                          OfferingKind.values
                              .asNameMap()[state.pathParameters['kind']] ??
                          OfferingKind.donation,
                    ),
                  ),
                  GoRoute(
                    path: 'puja',
                    builder: (_, state) => PujaScreen(
                      tsok: state.uri.queryParameters.containsKey('tsok'),
                    ),
                  ),
                  GoRoute(
                    path: 'receipt/:number',
                    builder: (_, state) =>
                        ReceiptScreen(number: state.pathParameters['number']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.calendar,
                builder: (_, _) => const CalendarScreen(),
                routes: [
                  GoRoute(
                    path: 'assign/:date',
                    // A malformed date falls back to the calendar.
                    redirect: (_, state) =>
                        parseIsoDate(state.pathParameters['date']) == null
                        ? AppRoutes.calendar
                        : null,
                    builder: (_, state) => AssignScreen(
                      day: parseIsoDate(state.pathParameters['date'])!,
                    ),
                  ),
                  GoRoute(path: 'plan', builder: (_, _) => const PlanScreen()),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                builder: (_, _) => const MoreScreen(),
                routes: [
                  GoRoute(path: 'team', builder: (_, _) => const TeamScreen()),
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) => const TempleSettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
