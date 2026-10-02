import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/command.dart';
import '../../../../core/error/result.dart';
import '../../data/auth_repositories.dart';
import '../../domain/auth_repository.dart';

/// The session read from the device before the first frame. `bootstrap`
/// overrides this with the restored value.
final initialSessionProvider = Provider<AuthSession>(
  (ref) => const AuthSession(),
);

@immutable
class AuthState {
  const AuthState({this.user, this.pendingEmail, this.completing = false});

  final AuthUser? user;

  /// The address a sign-in link was last sent to, awaiting the tap.
  final String? pendingEmail;

  /// A sign-in link has been opened and is being checked.
  final bool completing;

  bool get isSignedIn => user != null;
}

/// The session: who is signed in. The router and every temple-scoped
/// provider derive from this.
class AuthViewModel extends Notifier<AuthState> {
  @override
  AuthState build() {
    final links = _repository.signInLinks.listen(completeSignIn);
    ref.onDispose(links.cancel);
    final session = ref.watch(initialSessionProvider);
    return AuthState(user: session.user, pendingEmail: session.pendingEmail);
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// Emails a sign-in link to [email]. With [notify] off the caller shows a
  /// failure itself, beside the field it is about.
  Future<Result<void>> sendSignInLink(
    String email, {
    bool notify = true,
  }) async {
    final result = await runCommand(
      ref,
      () => _repository.sendSignInLink(email),
      notify: notify,
      source: 'auth.sendSignInLink',
    );
    // Asked for while an earlier link is being checked, that check carries on
    // and, if it has signed the person in meanwhile, stands.
    if (result.isOk && !state.isSignedIn) {
      state = AuthState(pendingEmail: email, completing: state.completing);
    }
    return result;
  }

  /// Finishes sign-in with a [link] the person opened. Driven by the links
  /// arriving from their email; the demo calls it directly.
  Future<void> completeSignIn(String link) async {
    // An old link opened while signed in, or one link delivered twice.
    if (state.isSignedIn || state.completing) return;
    state = AuthState(pendingEmail: state.pendingEmail, completing: true);
    final result = await runCommand(
      ref,
      () => _repository.completeSignIn(link),
      source: 'auth.completeSignIn',
    );
    state = switch (result) {
      Ok(:final value) => AuthState(user: value),
      Err() => AuthState(pendingEmail: state.pendingEmail),
    };
  }

  Future<void> signOut() async {
    await runCommand(ref, _repository.signOut, source: 'auth.signOut');
    // Leave the session locally even if the backend call failed.
    state = const AuthState();
  }
}

final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(
  AuthViewModel.new,
);
