import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Every location in the app. Plain strings with no feature imports, so
/// feature screens can navigate without depending on the router itself.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const checkEmail = '/check-email';
  static const temples = '/temples';

  static const home = '/home';
  static const letter = '/home/letter';
  static const announce = '/home/announce';
  static const hours = '/home/hours';
  static const reports = '/home/reports';
  static const tax = '/home/tax';
  static const prayers = '/home/prayers';
  static const approve = '/home/approve';
  static const checkIn = '/home/check-in';

  static const members = '/members';
  static const addMember = '/members/add';

  static const offerings = '/offerings';
  static const puja = '/offerings/puja';
  static const tsok = '/offerings/puja?tsok=1';

  static const calendar = '/calendar';
  static const plan = '/calendar/plan';

  static const more = '/more';
  static const team = '/more/team';
  static const templeSettings = '/more/settings';

  static String letterFor(String volunteerId) =>
      '$letter?volunteer=$volunteerId';

  static String member(String memberId) => '$members/$memberId';

  static String donation(String kind) => '$offerings/donation/$kind';

  static String receipt(String number) => '$offerings/receipt/$number';

  /// [isoDate] is `yyyy-MM-dd`.
  static String assign(String isoDate) => '$calendar/assign/$isoDate';

  /// Screens reachable before a temple is chosen.
  static const public = {splash, onboarding, login, checkEmail};

  /// Where the phone tab bar is shown. Everything deeper is a focused task
  /// and hides it.
  static const withTabBar = {home, members, offerings, calendar, more, team};
}

extension AppNavigation on BuildContext {
  /// Goes back if there is somewhere to go back to, otherwise to [fallback]
  /// (the case after a deep link or a tab switch).
  void popOrGo(String fallback) => canPop() ? pop() : go(fallback);
}
