import 'package:flutter/foundation.dart';

import 'role.dart';

/// A tab a temple may switch off. Home and More are always shown.
enum TempleTab { members, offerings, calendar }

/// The tabs and Home cards a temple's app shows. The backend decides.
@immutable
class TempleFeatures {
  const TempleFeatures({
    required Set<TempleTab> tabs,
    required Set<HomeAction> homeActions,
  }) : _tabs = tabs,
       _homeActions = homeActions;

  /// Everything on: the demo, and a backend that does not say.
  const TempleFeatures.all() : _tabs = null, _homeActions = null;

  final Set<TempleTab>? _tabs;
  final Set<HomeAction>? _homeActions;

  bool shows(TempleTab tab) => _tabs?.contains(tab) ?? true;

  bool showsHome(HomeAction action) => _homeActions?.contains(action) ?? true;
}
