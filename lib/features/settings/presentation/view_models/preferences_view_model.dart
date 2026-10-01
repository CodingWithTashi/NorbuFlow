import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/command.dart';
import '../../data/preferences_repositories.dart';
import '../../domain/app_preferences.dart';

/// Preferences read from storage before the first frame. `bootstrap`
/// overrides this with the loaded value.
final initialPreferencesProvider = Provider<AppPreferences>(
  (ref) => const AppPreferences(),
);

/// Language, dark mode and Simple Mode. Changes apply immediately and are
/// saved in the background.
class PreferencesViewModel extends Notifier<AppPreferences> {
  @override
  AppPreferences build() => ref.watch(initialPreferencesProvider);

  void setLanguage(AppLanguage language) =>
      _update(state.copyWith(language: language));

  void setDarkMode(bool enabled) => _update(state.copyWith(darkMode: enabled));

  void setSimpleMode(bool enabled) =>
      _update(state.copyWith(simpleMode: enabled));

  void markOnboardingSeen() => _update(state.copyWith(onboardingSeen: true));

  void _update(AppPreferences next) {
    state = next;
    runCommand(
      ref,
      () => ref.read(preferencesRepositoryProvider).save(next),
      source: 'preferences.save',
    );
  }
}

final preferencesProvider =
    NotifierProvider<PreferencesViewModel, AppPreferences>(
      PreferencesViewModel.new,
    );

final localeProvider = Provider<Locale>(
  (ref) =>
      Locale(ref.watch(preferencesProvider.select((p) => p.language.code))),
);
