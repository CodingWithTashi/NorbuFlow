import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/validation_issue.dart';
import '../../../../core/utils/validators.dart';
import 'auth_view_model.dart';

@immutable
class LoginState {
  const LoginState({this.email = '', this.issue, this.submitting = false});

  final String email;
  final ValidationIssue? issue;
  final bool submitting;

  LoginState copyWith({
    String? email,
    ValidationIssue? Function()? issue,
    bool? submitting,
  }) {
    return LoginState(
      email: email ?? this.email,
      issue: issue == null ? this.issue : issue(),
      submitting: submitting ?? this.submitting,
    );
  }
}

class LoginViewModel extends Notifier<LoginState> {
  @override
  LoginState build() {
    // The demo pre-fills the invited address so the flow is one tap.
    final config = ref.watch(appConfigProvider);
    return LoginState(email: config.demoMode ? config.demoEmail : '');
  }

  void setEmail(String value) {
    state = state.copyWith(email: value, issue: () => null);
  }

  /// Validates the address and requests a sign-in link. Returns whether the
  /// link was sent.
  Future<bool> submit() async {
    final email = state.email.trim();
    final issue = Validators.requiredEmail(
      email,
      whenEmpty: ValidationIssue.ownEmailRequired,
    );
    if (issue != null) {
      state = state.copyWith(issue: () => issue);
      return false;
    }
    state = state.copyWith(submitting: true);
    final result = await ref
        .read(authViewModelProvider.notifier)
        .sendSignInLink(email);
    if (ref.mounted) state = state.copyWith(submitting: false);
    return result.isOk;
  }
}

final loginViewModelProvider =
    NotifierProvider.autoDispose<LoginViewModel, LoginState>(
      LoginViewModel.new,
    );
