import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/command.dart';
import '../../../../core/error/result.dart';
import '../../data/auth_repositories.dart';
import '../../domain/auth_repository.dart';

@immutable
class AuthState {
  const AuthState({this.user, this.pendingEmail});

  final AuthUser? user;

  /// The address a sign-in link was last sent to, awaiting the tap.
  final String? pendingEmail;

  bool get isSignedIn => user != null;
}

/// The session: who is signed in. The router and every temple-scoped
/// provider derive from this.
class AuthViewModel extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<Result<void>> sendSignInLink(String email) async {
    final result = await runCommand(
      ref,
      () => _repository.sendSignInLink(email),
      source: 'auth.sendSignInLink',
    );
    if (result.isOk) state = AuthState(pendingEmail: email);
    return result;
  }

  /// Completes sign-in for the pending email. In production this is driven
  /// by the email link; the demo calls it directly.
  Future<Result<AuthUser>> completeSignIn() async {
    final email = state.pendingEmail;
    if (email == null) return const Err(UnauthenticatedFailure());
    final result = await runCommand(
      ref,
      () => _repository.completeSignIn(email),
      source: 'auth.completeSignIn',
    );
    if (result case Ok(:final value)) state = AuthState(user: value);
    return result;
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
