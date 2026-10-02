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

/// What the device remembers about sign-in between launches.
@immutable
class AuthSession {
  const AuthSession({this.user, this.pendingEmail});

  /// Who is signed in, if anyone.
  final AuthUser? user;

  /// The address a sign-in link was sent to and has not been opened from yet.
  final String? pendingEmail;
}

/// Passwordless, invite-only sign-in: the temple invites an email address and
/// the person signs in by tapping a link sent to it.
abstract interface class AuthRepository {
  /// The session saved on this device.
  Future<AuthSession> restore();

  /// Emails a sign-in link to [email] and remembers the address for when it
  /// is opened. `PermissionFailure(notOnTeam)` if no temple added the address.
  Future<void> sendSignInLink(String email);

  /// Sign-in links opened on this device, including one that launched it.
  Stream<String> get signInLinks;

  /// Finishes sign-in with a [link] the person opened. Fails with
  /// `SignInLinkFailure` if the link is spent or was asked for elsewhere.
  Future<AuthUser> completeSignIn(String link);

  Future<void> signOut();
}
