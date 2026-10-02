import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/data/backend.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../domain/auth_repository.dart';
import 'auth_local_store.dart';
import 'auth_user_json.dart';

/// Sign-in with a Firebase email link. The app counts as signed in only
/// while it has both a Firebase session and the profile from the backend.
final class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth auth,
    required Backend backend,
    required AuthLocalStore store,
    required Stream<String> Function() incomingLinks,
  }) : _auth = auth,
       _backend = backend,
       _store = store,
       _incomingLinks = incomingLinks;

  // The app's store identifiers, which tell a link which app to open.
  static const _androidPackage = 'com.kharagedition.norbu_flow';
  static const _iosBundle = 'com.kharagedition.norbuFlow';

  final FirebaseAuth _auth;
  final Backend _backend;
  final AuthLocalStore _store;

  /// A factory, because app_links starts listening as soon as its stream is
  /// asked for, and the link that launched the app goes to that first listen.
  final Stream<String> Function() _incomingLinks;

  /// Links use the project's default Hosting domain. `linkDomain` stays unset:
  /// it is for custom domains, and Firebase rejects the default one there.
  ActionCodeSettings get _linkSettings => ActionCodeSettings(
    url: 'https://${_auth.app.options.projectId}.firebaseapp.com',
    handleCodeInApp: true,
    androidPackageName: _androidPackage,
    androidInstallApp: true,
    iOSBundleId: _iosBundle,
  );

  @override
  Future<AuthSession> restore() => guardFailures(() async {
    // Firebase loads its saved session asynchronously; the first event is it.
    final account = await _auth.authStateChanges().first;
    final user = await _store.user();
    if (account != null && user?.id == account.uid) {
      return AuthSession(user: user);
    }
    // Half a session is none. iOS, for one, keeps the Firebase session
    // across a reinstall but not the profile.
    if (account != null) await _auth.signOut();
    if (user != null) await _store.clearUser();
    return AuthSession(pendingEmail: await _store.pendingEmail());
  });

  @override
  Future<void> sendSignInLink(String email) => guardFailures(() async {
    // Asked first, so nobody waits for a link that could not let them in.
    final response = await _backend.call(
      'auth-checkEmail',
      input: {'email': email},
    );
    if (response['invited'] != true) {
      throw const PermissionFailure(reason: PermissionReason.notOnTeam);
    }
    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: _linkSettings,
    );
    await _store.savePendingEmail(email);
  });

  @override
  Stream<String> get signInLinks =>
      _incomingLinks().where(_auth.isSignInWithEmailLink);

  @override
  Future<AuthUser> completeSignIn(String link) => guardFailures(() async {
    final email = await _store.pendingEmail();
    if (email == null) {
      throw const SignInLinkFailure(reason: SignInLinkReason.differentDevice);
    }
    // A link works once. If only the profile was missing last time, the
    // session it opened is still here.
    if (_auth.currentUser?.email != email.toLowerCase()) {
      await _exchange(email, link);
    }
    try {
      final response = await _backend.call('auth-startSession');
      final user = authUserFromJson(response['user']);
      await _store.saveUser(user);
      return user;
    } on Object catch (error) {
      // A refusal ends the session. A lost connection keeps it, so that
      // opening the same link again can finish the job.
      if (!FailureMapper.map(error).isTransient) await _auth.signOut();
      rethrow;
    }
  });

  Future<void> _exchange(String email, String link) async {
    try {
      await _auth.signInWithEmailLink(email: email, emailLink: link);
    } on FirebaseAuthException catch (error) {
      // Here this code means the link was sent to a different address than
      // the one waiting, not that the address is malformed.
      if (error.code != 'invalid-email') rethrow;
      throw SignInLinkFailure(reason: SignInLinkReason.invalid, cause: error);
    }
  }

  @override
  Future<void> signOut() => guardFailures(() async {
    // The profile goes first: if Firebase then fails, the next launch finds
    // half a session and finishes the job.
    await _store.clear();
    await _auth.signOut();
  });
}
