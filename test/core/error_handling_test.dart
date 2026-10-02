import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/core/error/app_failure.dart';
import 'package:norbu_flow/core/error/command.dart';
import 'package:norbu_flow/core/error/error_reporter.dart';
import 'package:norbu_flow/core/error/failure_mapper.dart';
import 'package:norbu_flow/core/error/failure_text.dart';
import 'package:norbu_flow/core/error/provider_error_observer.dart';
import 'package:norbu_flow/core/error/result.dart';
import 'package:norbu_flow/core/error/validation_issue.dart';
import 'package:norbu_flow/core/feedback/app_messenger.dart';
import 'package:norbu_flow/core/utils/validators.dart';
import 'package:norbu_flow/l10n/generated/app_localizations.dart';

import '../support/test_app.dart';

class _RecordingReporter implements ErrorReporter {
  final reported = <AppFailure>[];

  @override
  void report(AppFailure failure, {StackTrace? stackTrace, String? source}) =>
      reported.add(failure);
}

/// Exposes a [Ref] so `runCommand` can be exercised directly.
final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  group('FailureMapper', () {
    test('passes an AppFailure through unchanged', () {
      const failure = ConflictFailure(reason: ConflictReason.alreadyOnTeam);
      expect(FailureMapper.map(failure), same(failure));
    });

    test('turns a timeout into a transient TimeoutFailure', () {
      final failure = FailureMapper.map(TimeoutException('slow'));
      expect(failure, isA<TimeoutFailure>());
      expect(failure.isTransient, isTrue);
    });

    test('wraps anything unexpected as UnknownFailure, keeping the cause', () {
      final cause = StateError('boom');
      final failure = FailureMapper.map(cause);
      expect(failure, isA<UnknownFailure>());
      expect(failure.cause, same(cause));
    });

    group('backend errors', () {
      AppFailure mapped(String code, [Object? details]) => FailureMapper.map(
        FirebaseFunctionsException(code: code, message: code, details: details),
      );

      test('become the matching failure, keeping the reason', () {
        expect(mapped('unauthenticated'), isA<UnauthenticatedFailure>());
        expect(mapped('not-found'), isA<NotFoundFailure>());
        expect(mapped('internal'), isA<UnknownFailure>());
        expect(
          mapped('permission-denied', {'reason': 'adminOnlyRoles'}),
          isA<PermissionFailure>().having(
            (failure) => failure.reason,
            'reason',
            PermissionReason.adminOnlyRoles,
          ),
        );
        expect(
          mapped('already-exists', {'reason': 'alreadyOnTeam'}),
          isA<ConflictFailure>().having(
            (failure) => failure.reason,
            'reason',
            ConflictReason.alreadyOnTeam,
          ),
        );
      });

      test('a reason the app does not know falls back to the general one', () {
        expect(
          mapped('permission-denied', {'reason': 'addedNextYear'}),
          isA<PermissionFailure>().having(
            (failure) => failure.reason,
            'reason',
            PermissionReason.general,
          ),
        );
        expect(mapped('permission-denied'), isA<PermissionFailure>());
      });

      test('rejected input names each field and its issue', () {
        final failure = mapped('invalid-argument', {
          'fields': {'email': 'emailIncomplete', 'role': 'addedNextYear'},
        });
        expect(
          failure,
          isA<ValidationFailure>().having(
            (failure) => failure.issues,
            'issues',
            {'email': ValidationIssue.emailIncomplete},
          ),
        );
      });

      test('an unreachable or slow backend is worth retrying', () {
        expect(mapped('unavailable'), isA<NetworkFailure>());
        expect(mapped('deadline-exceeded'), isA<TimeoutFailure>());
        expect(mapped('unavailable').isTransient, isTrue);
      });

      test('a backend that is asked too often says so', () {
        expect(mapped('resource-exhausted'), isA<TooManyRequestsFailure>());
      });
    });

    test('sign-in errors become failures the app has words for', () {
      AppFailure mapped(String code) =>
          FailureMapper.map(FirebaseAuthException(code: code));

      expect(mapped('network-request-failed'), isA<NetworkFailure>());
      expect(mapped('too-many-requests'), isA<TooManyRequestsFailure>());
      expect(mapped('quota-exceeded'), isA<TooManyRequestsFailure>());
      expect(mapped('operation-not-allowed'), isA<UnavailableFailure>());
      expect(
        mapped('invalid-email'),
        isA<ValidationFailure>().having((failure) => failure.issues, 'issues', {
          'email': ValidationIssue.emailIncomplete,
        }),
      );
      expect(mapped('expired-action-code'), isA<SignInLinkFailure>());
      expect(mapped('invalid-action-code'), isA<SignInLinkFailure>());
      expect(mapped('user-token-expired'), isA<UnauthenticatedFailure>());
      expect(
        mapped('user-disabled'),
        isA<PermissionFailure>().having(
          (failure) => failure.reason,
          'reason',
          PermissionReason.accountDisabled,
        ),
      );
      expect(mapped('something-new'), isA<UnknownFailure>());
    });

    test('guardFailures only ever throws AppFailure', () async {
      await expectLater(
        guardFailures<void>(() async => throw const FormatException('bad')),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('appRetryPolicy', () {
    test('retries transient failures twice, then gives up', () {
      const failure = NetworkFailure();
      expect(appRetryPolicy(0, failure), isNotNull);
      expect(appRetryPolicy(1, failure), isNotNull);
      expect(appRetryPolicy(2, failure), isNull);
    });

    test('never retries a failure that needs the user to act', () {
      expect(appRetryPolicy(0, const NotFoundFailure()), isNull);
      expect(appRetryPolicy(0, const PermissionFailure()), isNull);
    });
  });

  group('runCommand', () {
    test('returns Ok and shows nothing when the action succeeds', () async {
      final container = createContainer();
      final result = await runCommand(
        container.read(_refProvider),
        () async => 42,
      );
      expect(result, isA<Ok<int>>());
      expect(result.valueOrNull, 42);
      expect(container.read(appMessengerProvider), isNull);
    });

    test('reports the failure and shows it as a toast', () async {
      final reporter = _RecordingReporter();
      final container = createContainer(
        overrides: [errorReporterProvider.overrideWithValue(reporter)],
      );
      final result = await runCommand<int>(
        container.read(_refProvider),
        () async => throw const NotFoundFailure(),
      );

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(reporter.reported.single, isA<NotFoundFailure>());
      expect(
        container.read(appMessengerProvider)?.failure,
        isA<NotFoundFailure>(),
      );
      container.read(appMessengerProvider.notifier).dismiss();
    });

    test('stays quiet when the caller shows the failure itself', () async {
      final container = createContainer();
      await runCommand<int>(
        container.read(_refProvider),
        () async => throw const NotFoundFailure(),
        notify: false,
      );
      expect(container.read(appMessengerProvider), isNull);
    });
  });

  group('failureText', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('has distinct wording for specific reasons', () {
      expect(
        failureText(
          l10n,
          const ConflictFailure(reason: ConflictReason.alreadyOnTeam),
        ),
        'This person is already on the team.',
      );
      expect(
        failureText(
          l10n,
          const PermissionFailure(reason: PermissionReason.ownRole),
        ),
        'Another Temple Admin must change your own role.',
      );
    });

    test('tells the person what to do about a sign-in link', () {
      expect(
        failureText(
          l10n,
          const SignInLinkFailure(reason: SignInLinkReason.invalid),
        ),
        'This sign-in link has expired or was already used. '
        'Please ask for a new one.',
      );
      expect(
        failureText(
          l10n,
          const SignInLinkFailure(reason: SignInLinkReason.differentDevice),
        ),
        'Please ask for the sign-in link on this device, then open it here.',
      );
    });

    test('never leaks the underlying error to the user', () {
      final text = failureText(
        l10n,
        UnknownFailure(cause: StateError('secret stack detail')),
      );
      expect(text, isNot(contains('secret')));
    });
  });

  group('localised messages', () {
    // gen-l10n sorts inferred placeholders alphabetically, swapping arguments
    // silently, so these messages declare their order in the ARB.
    test('take their arguments in reading order', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l10n.tibetanDate(8, 19), 'Tibetan month 8, day 19');
      expect(
        l10n.addSummaryMeta('JC-0204', 'Sep 30, 2027'),
        'Member no. JC-0204 · Valid until Sep 30, 2027',
      );
      expect(
        l10n.assignSuccessBody('Pema', 'Kitchen', 'Saturday, October 10'),
        'Pema will help with Kitchen on Saturday, October 10.',
      );
    });
  });

  group('Validators', () {
    test('email', () {
      expect(
        Validators.requiredEmail(
          '',
          whenEmpty: ValidationIssue.ownEmailRequired,
        ),
        ValidationIssue.ownEmailRequired,
      );
      expect(
        Validators.requiredEmail(
          'dolma@',
          whenEmpty: ValidationIssue.ownEmailRequired,
        ),
        ValidationIssue.emailIncomplete,
      );
      expect(
        Validators.requiredEmail(
          'dolma@jangchub.org',
          whenEmpty: ValidationIssue.ownEmailRequired,
        ),
        isNull,
      );
      expect(Validators.optionalEmail(''), isNull);
    });

    test('phone needs ten digits, however it is punctuated', () {
      expect(Validators.phone('416 555'), ValidationIssue.phoneTooShort);
      expect(Validators.phone('(416) 555-0142'), isNull);
    });

    test('an optional contact may be an email or a phone number', () {
      expect(Validators.optionalContact(''), isNull);
      expect(Validators.optionalContact('a@b.co'), isNull);
      expect(Validators.optionalContact('416 555 0142'), isNull);
      expect(
        Validators.optionalContact('tenzin'),
        ValidationIssue.contactIncomplete,
      );
    });
  });
}
