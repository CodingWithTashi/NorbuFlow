import '../../../core/data/fake_repository.dart';
import '../domain/auth_repository.dart';

/// Accepts any well-formed email and signs in as the demo front-desk user.
final class FakeAuthRepository extends FakeRepository
    implements AuthRepository {
  FakeAuthRepository(super.latency);

  static const demoUserId = 'user-dolma';

  @override
  Future<void> sendSignInLink(String email) => respond(() {});

  @override
  Future<AuthUser> completeSignIn(String email) => respond(
    () => AuthUser(id: demoUserId, email: email, displayName: 'Dolma Tsering'),
  );

  @override
  Future<void> signOut() => respond(() {});
}
