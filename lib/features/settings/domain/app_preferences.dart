import 'package:flutter/foundation.dart';

/// Languages the interface is available in.
enum AppLanguage {
  english('en'),
  tibetan('bo');

  const AppLanguage(this.code);

  final String code;
}

/// Per-device choices that are not tied to a temple.
@immutable
class AppPreferences {
  const AppPreferences({
    this.language = AppLanguage.english,
    this.darkMode = false,
    this.simpleMode = false,
    this.onboardingSeen = false,
  });

  final AppLanguage language;
  final bool darkMode;

  /// Larger text for readers who need it.
  final bool simpleMode;
  final bool onboardingSeen;

  AppPreferences copyWith({
    AppLanguage? language,
    bool? darkMode,
    bool? simpleMode,
    bool? onboardingSeen,
  }) {
    return AppPreferences(
      language: language ?? this.language,
      darkMode: darkMode ?? this.darkMode,
      simpleMode: simpleMode ?? this.simpleMode,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
    );
  }
}

abstract interface class PreferencesRepository {
  Future<AppPreferences> load();

  Future<void> save(AppPreferences preferences);
}
