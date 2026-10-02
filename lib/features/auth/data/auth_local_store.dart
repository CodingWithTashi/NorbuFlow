import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/auth_repository.dart';
import 'auth_user_json.dart';

/// What sign-in keeps on the device between launches: the address a link was
/// sent to, and the profile of whoever is signed in.
final class AuthLocalStore {
  static const _pendingEmailKey = 'auth.pendingEmail';
  static const _userKey = 'auth.user';

  final _preferences = SharedPreferencesAsync();

  Future<String?> pendingEmail() => _preferences.getString(_pendingEmailKey);

  Future<void> savePendingEmail(String email) =>
      _preferences.setString(_pendingEmailKey, email);

  Future<AuthUser?> user() async {
    final saved = await _preferences.getString(_userKey);
    return saved == null ? null : authUserFromJson(jsonDecode(saved));
  }

  /// Saves the signed-in [user]. Their link has been used, so the pending
  /// address goes.
  Future<void> saveUser(AuthUser user) async {
    await _preferences.setString(_userKey, jsonEncode(authUserToJson(user)));
    await _preferences.remove(_pendingEmailKey);
  }

  Future<void> clearUser() => _preferences.remove(_userKey);

  Future<void> clear() =>
      _preferences.clear(allowList: {_pendingEmailKey, _userKey});
}
