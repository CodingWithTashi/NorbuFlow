import 'package:flutter/foundation.dart';

/// The signed-in person.
@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final String id;
  final String email;
  final String displayName;
}

/// Passwordless, invite-only sign-in: the temple invites an email address and
/// the person signs in by tapping a link sent to it.
abstract interface class AuthRepository {
  /// Emails a sign-in link to [email].
  Future<void> sendSignInLink(String email);

  /// Finishes sign-in once the link sent to [email] has been opened.
  Future<AuthUser> completeSignIn(String email);

  Future<void> signOut();
}
