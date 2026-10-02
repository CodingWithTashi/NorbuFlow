import '../../../core/data/fake_repository.dart';
import '../../../core/error/app_failure.dart';
import '../domain/auth_repository.dart';

/// Accepts any well-formed email and signs in as the demo front-desk user.
/// Sends nothing: whatever is passed to [completeSignIn] counts as the link.
final class FakeAuthRepository extends FakeRepository
    implements AuthRepository {
  FakeAuthRepository(super.latency);

  static const demoUserId = 'user-dolma';

  String? _pendingEmail;

  @override
  Future<AuthSession> restore() => respond(() => const AuthSession());

  @override
  Future<void> sendSignInLink(String email) => respond(() {
    _pendingEmail = email;
  });

  @override
  Stream<String> get signInLinks => const Stream.empty();

  @override
  Future<AuthUser> completeSignIn(String link) => respond(() {
    final email = _pendingEmail;
    if (email == null) {
      throw const SignInLinkFailure(reason: SignInLinkReason.differentDevice);
    }
    _pendingEmail = null;
    return AuthUser(id: demoUserId, email: email, displayName: 'Dolma Tsering');
  });

  @override
  Future<void> signOut() => respond(() {
    _pendingEmail = null;
  });
}
