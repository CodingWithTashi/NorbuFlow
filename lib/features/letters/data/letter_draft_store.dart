import 'package:shared_preferences/shared_preferences.dart';

import '../domain/letter.dart';
import 'letter_json.dart';

/// Keeps a half-written letter on the device, so that leaving the screen or
/// closing the app does not lose it.
final class DeviceLetterDraftStore implements LetterDraftStore {
  final _preferences = SharedPreferencesAsync();

  static String _name(String key) => 'letters.draft.$key';

  @override
  Future<LetterDraft?> read(String key) async {
    try {
      final stored = await _preferences.getString(_name(key));
      return stored == null ? null : draftFromJson(stored);
    } on Object {
      // A draft that cannot be read is no draft: the form starts empty.
      return null;
    }
  }

  @override
  Future<void> write(String key, LetterDraft draft) async {
    try {
      await _preferences.setString(_name(key), draftToJson(draft));
    } on Object {
      // Not kept this time. The next change tries again.
    }
  }

  @override
  Future<void> clear(String key) async {
    try {
      await _preferences.remove(_name(key));
    } on Object {
      // Left behind: it is offered again, and cleared by the next letter.
    }
  }
}

/// Keeps drafts for as long as the app runs: the demo, and tests.
final class MemoryLetterDraftStore implements LetterDraftStore {
  final drafts = <String, LetterDraft>{};

  @override
  Future<LetterDraft?> read(String key) async => drafts[key];

  @override
  Future<void> write(String key, LetterDraft draft) async =>
      drafts[key] = draft;

  @override
  Future<void> clear(String key) async => drafts.remove(key);
}
