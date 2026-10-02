import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norbu_flow/core/error/app_failure.dart';
import 'package:norbu_flow/core/feedback/app_messenger.dart';
import 'package:norbu_flow/features/auth/data/auth_local_store.dart';
import 'package:norbu_flow/features/auth/data/auth_repositories.dart';
import 'package:norbu_flow/features/auth/data/fake_auth_repository.dart';
import 'package:norbu_flow/features/auth/data/firebase_auth_repository.dart';
import 'package:norbu_flow/features/auth/domain/auth_repository.dart';
import 'package:norbu_flow/features/auth/presentation/view_models/auth_view_model.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_backend.dart';
import '../support/test_app.dart';

const _email = 'dolma@jangchub.org';
const _link = 'https://norbu-flow.firebaseapp.com/__/auth/links?oobCode=abc';
const _dolma = AuthUser(
  id: 'uid-dolma',
  email: _email,
  displayName: 'Dolma Tsering',
);

void main() {
  group('what the device saved', () {
    AuthState openedWith(AuthSession saved) => createContainer(
      overrides: [initialSessionProvider.overrideWithValue(saved)],
    ).read(authViewModelProvider);

    test('a saved session opens the app signed in', () {
      expect(openedWith(const AuthSession(user: _dolma)).user, same(_dolma));
    });

    test('a link still awaited opens it signed out, remembering the '
        'address', () {
      final state = openedWith(const AuthSession(pendingEmail: _email));

      expect(state.isSignedIn, isFalse);
      expect(state.pendingEmail, _email);
    });
  });

  group('session', () {
    late _DrivenAuthRepository repository;
    late ProviderContainer container;

    AuthState state() => container.read(authViewModelProvider);
    AuthViewModel auth() => container.read(authViewModelProvider.notifier);
    AppFailure? shownFailure() => container.read(appMessengerProvider)?.failure;

    setUp(() {
      repository = _DrivenAuthRepository();
      container = createContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.read(appMessengerProvider.notifier).dismiss);
    });

    test('a link opened from the email signs the person in', () async {
      await auth().sendSignInLink(_email);
      expect(state().pendingEmail, _email);

      final signedIn = _next(container, (state) => state.isSignedIn);
      repository.open(_link);

      expect((await signedIn).user?.email, _email);
      expect(repository.completed, [_link]);
      expect(state().completing, isFalse);
    });

    test('shows that a link is being checked while it is', () async {
      await auth().sendSignInLink(_email);
      final completion = auth().completeSignIn(_link);

      expect(state().completing, isTrue);
      expect(state().pendingEmail, _email);
      await completion;
      expect(state().completing, isFalse);
    });

    test('a link this device did not ask for is refused, saying why', () async {
      await auth().completeSignIn(_link);

      expect(state().isSignedIn, isFalse);
      expect(
        shownFailure(),
        isA<SignInLinkFailure>().having(
          (failure) => failure.reason,
          'reason',
          SignInLinkReason.differentDevice,
        ),
      );
    });

    test('after a bad link the person can ask for another', () async {
      await auth().sendSignInLink(_email);
      repository.failWith = const SignInLinkFailure(
        reason: SignInLinkReason.invalid,
      );

      await auth().completeSignIn(_link);

      expect(shownFailure(), isA<SignInLinkFailure>());
      expect(state().isSignedIn, isFalse);
      expect(state().completing, isFalse);
      expect(state().pendingEmail, _email);
    });

    test('an old link opened while signed in changes nothing', () async {
      await signIn(container);
      final user = state().user;

      await auth().completeSignIn(_link);

      expect(state().user, same(user));
      expect(shownFailure(), isNull);
    });

    test('one link delivered twice signs in once', () async {
      await auth().sendSignInLink(_email);

      await Future.wait([
        auth().completeSignIn(_link),
        auth().completeSignIn(_link),
      ]);

      expect(repository.completed, [_link]);
      expect(state().isSignedIn, isTrue);
      expect(shownFailure(), isNull);
    });

    test('asking for another link while one is being checked does not start '
        'a second check', () async {
      await auth().sendSignInLink(_email);
      repository.checking = Completer<void>();
      final completion = auth().completeSignIn(_link);

      await auth().sendSignInLink(_email);
      expect(state().completing, isTrue);
      await auth().completeSignIn(_link);
      repository.checking!.complete();
      await completion;

      expect(repository.completed, [_link]);
      expect(state().isSignedIn, isTrue);
    });

    test('a link sent again just as the first one signs in does not sign '
        'the person back out', () async {
      await auth().sendSignInLink(_email);
      repository.sending = Completer<void>();
      final resend = auth().sendSignInLink(_email);

      await auth().completeSignIn(_link);
      repository.sending!.complete();
      await resend;

      expect(state().isSignedIn, isTrue);
    });

    test('signing out forgets who was signed in', () async {
      await signIn(container);
      await auth().signOut();

      expect(state().isSignedIn, isFalse);
      expect(state().pendingEmail, isNull);
    });
  });

  group('FirebaseAuthRepository', () {
    late _FakeFirebaseAuth firebase;
    late FakeBackend backend;
    late AuthLocalStore store;
    late StreamController<String> incoming;
    late int linkStreamsOpened;
    late FirebaseAuthRepository repository;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      firebase = _FakeFirebaseAuth();
      backend = FakeBackend({
        'user': <Object?, Object?>{
          'id': 'uid-dolma',
          'email': _email,
          'displayName': 'Dolma Tsering',
        },
      });
      store = AuthLocalStore();
      incoming = StreamController<String>.broadcast();
      addTearDown(incoming.close);
      linkStreamsOpened = 0;
      repository = FirebaseAuthRepository(
        auth: firebase,
        backend: backend,
        store: store,
        incomingLinks: () {
          linkStreamsOpened++;
          return incoming.stream;
        },
      );
    });

    test('asking for a link sends one that opens the app, and remembers '
        'the address', () async {
      await repository.sendSignInLink(_email);

      final settings = firebase.sent[_email]!;
      expect(settings.handleCodeInApp, isTrue);
      // Firebase rejects the default Hosting domain when it is named here.
      expect(settings.linkDomain, isNull);
      expect(settings.url, 'https://norbu-flow.firebaseapp.com');
      expect(settings.androidPackageName, 'com.kharagedition.norbu_flow');
      expect(settings.iOSBundleId, 'com.kharagedition.norbuFlow');
      expect((await repository.restore()).pendingEmail, _email);
    });

    test('an address Firebase refuses is not remembered', () async {
      firebase.sendError = FirebaseAuthException(code: 'too-many-requests');

      await expectLater(
        repository.sendSignInLink(_email),
        throwsA(isA<TooManyRequestsFailure>()),
      );
      expect(await store.pendingEmail(), isNull);
    });

    test('opening the link signs in, fetches the profile and keeps it '
        'for the next launch', () async {
      await repository.sendSignInLink(_email);

      final user = await repository.completeSignIn(_link);

      expect(firebase.exchanged, [(_email, _link)]);
      expect(backend.calls, ['auth-startSession']);
      expect(user.id, 'uid-dolma');
      expect(user.displayName, 'Dolma Tsering');

      final restored = await repository.restore();
      expect(restored.user?.id, 'uid-dolma');
      expect(restored.user?.displayName, 'Dolma Tsering');
      expect(await store.pendingEmail(), isNull);
      // Restoring is local: no second trip to the backend.
      expect(backend.calls, hasLength(1));
    });

    test('a link opened on a device that did not ask for it is refused '
        'without troubling Firebase', () async {
      await expectLater(
        repository.completeSignIn(_link),
        throwsA(
          isA<SignInLinkFailure>().having(
            (failure) => failure.reason,
            'reason',
            SignInLinkReason.differentDevice,
          ),
        ),
      );
      expect(firebase.exchanged, isEmpty);
    });

    for (final code in [
      'invalid-action-code',
      'expired-action-code',
      // The link was sent to a different address than the one waiting.
      'invalid-email',
    ]) {
      test('a link Firebase rejects as $code is a bad link', () async {
        await repository.sendSignInLink(_email);
        firebase.exchangeError = FirebaseAuthException(code: code);

        await expectLater(
          repository.completeSignIn(_link),
          throwsA(
            isA<SignInLinkFailure>().having(
              (failure) => failure.reason,
              'reason',
              SignInLinkReason.invalid,
            ),
          ),
        );
        expect(backend.calls, isEmpty);
      });
    }

    test('if the profile cannot be fetched, nobody is left half signed '
        'in', () async {
      await repository.sendSignInLink(_email);
      backend.error = FirebaseFunctionsException(
        code: 'internal',
        message: 'INTERNAL',
      );

      await expectLater(
        repository.completeSignIn(_link),
        throwsA(isA<UnknownFailure>()),
      );
      expect(firebase.account, isNull);
      expect((await repository.restore()).user, isNull);
    });

    test('a connection lost while fetching the profile does not spend the '
        'link: opening it again signs in', () async {
      await repository.sendSignInLink(_email);
      backend.error = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'UNAVAILABLE',
      );
      await expectLater(
        repository.completeSignIn(_link),
        throwsA(isA<NetworkFailure>()),
      );

      backend.error = null;
      final user = await repository.completeSignIn(_link);

      expect(user.id, 'uid-dolma');
      // The link was exchanged once; the second time only the profile was.
      expect(firebase.exchanged, [(_email, _link)]);
      expect((await repository.restore()).user?.id, 'uid-dolma');
    });

    test('an email no temple has invited is told so, and is not signed '
        'in', () async {
      await repository.sendSignInLink(_email);
      backend.error = FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'On no team.',
        details: {'reason': 'notOnTeam'},
      );

      await expectLater(
        repository.completeSignIn(_link),
        throwsA(
          isA<PermissionFailure>().having(
            (failure) => failure.reason,
            'reason',
            PermissionReason.notOnTeam,
          ),
        ),
      );
      expect(firebase.account, isNull);
      expect((await repository.restore()).user, isNull);
    });

    test('a Firebase session without its profile is signed out on '
        'launch', () async {
      firebase.account = _FakeAccount('uid-left-behind');

      final session = await repository.restore();

      expect(session.user, isNull);
      expect(firebase.account, isNull);
    });

    test('a profile saved for someone else than the Firebase session is '
        'dropped with it', () async {
      firebase.account = _FakeAccount('uid-someone-else');
      await store.saveUser(_dolma);

      expect((await repository.restore()).user, isNull);
      expect(firebase.account, isNull);
      expect(await store.user(), isNull);
    });

    test('a saved profile without its Firebase session is dropped', () async {
      await store.saveUser(_dolma);

      expect((await repository.restore()).user, isNull);
      expect(await store.user(), isNull);
    });

    test('signing out ends the Firebase session and forgets the '
        'profile', () async {
      await repository.sendSignInLink(_email);
      await repository.completeSignIn(_link);

      await repository.signOut();

      expect(firebase.account, isNull);
      final session = await repository.restore();
      expect(session.user, isNull);
      expect(session.pendingEmail, isNull);
    });

    test('a sign-out Firebase fails still signs out by the next '
        'launch', () async {
      await repository.sendSignInLink(_email);
      await repository.completeSignIn(_link);
      firebase.signOutError = FirebaseAuthException(code: 'internal-error');

      await expectLater(repository.signOut(), throwsA(isA<UnknownFailure>()));
      firebase.signOutError = null;

      expect((await repository.restore()).user, isNull);
      expect(firebase.account, isNull);
    });

    test('does not open the stream of links until someone listens, so the '
        'link that launched the app is not lost', () async {
      expect(linkStreamsOpened, 0);

      final links = <String>[];
      final subscription = repository.signInLinks.listen(links.add);
      addTearDown(subscription.cancel);
      incoming.add(_link);
      await pumpEventQueue();

      expect(linkStreamsOpened, 1);
      expect(links, [_link]);
    });

    test('only sign-in links are passed on', () async {
      final links = <String>[];
      final subscription = repository.signInLinks.listen(links.add);
      addTearDown(subscription.cancel);

      incoming
        ..add('https://norbu-flow.firebaseapp.com/something-else')
        ..add(_link);
      await pumpEventQueue();

      expect(links, [_link]);
    });
  });
}

/// The next [AuthState] matching [test].
Future<AuthState> _next(
  ProviderContainer container,
  bool Function(AuthState state) test,
) {
  final found = Completer<AuthState>();
  final subscription = container.listen(authViewModelProvider, (_, state) {
    if (test(state) && !found.isCompleted) found.complete(state);
  });
  return found.future.whenComplete(subscription.close);
}

/// The fake, with links that can be "opened" and a record of what it was
/// asked to complete.
class _DrivenAuthRepository implements AuthRepository {
  final _fake = FakeAuthRepository(Duration.zero);
  final _links = StreamController<String>.broadcast();
  final completed = <String>[];
  AppFailure? failWith;

  /// When set, the call waits for it: a slow check, a slow send.
  Completer<void>? checking;
  Completer<void>? sending;

  void open(String link) => _links.add(link);

  @override
  Stream<String> get signInLinks => _links.stream;

  @override
  Future<AuthUser> completeSignIn(String link) async {
    completed.add(link);
    await checking?.future;
    if (failWith case final failure?) throw failure;
    return _fake.completeSignIn(link);
  }

  @override
  Future<AuthSession> restore() => _fake.restore();

  @override
  Future<void> sendSignInLink(String email) async {
    await _fake.sendSignInLink(email);
    await sending?.future;
  }

  @override
  Future<void> signOut() => _fake.signOut();
}

class _FakeFirebaseAuth extends Fake implements FirebaseAuth {
  final sent = <String, ActionCodeSettings>{};
  final exchanged = <(String, String)>[];
  FirebaseAuthException? sendError;
  FirebaseAuthException? exchangeError;
  FirebaseAuthException? signOutError;
  User? account;

  @override
  User? get currentUser => account;

  @override
  FirebaseApp get app => _FakeApp();

  @override
  Stream<User?> authStateChanges() => Stream.value(account);

  @override
  Future<void> sendSignInLinkToEmail({
    required String email,
    required ActionCodeSettings actionCodeSettings,
  }) async {
    if (sendError case final error?) throw error;
    sent[email] = actionCodeSettings;
  }

  @override
  bool isSignInWithEmailLink(String emailLink) =>
      emailLink.contains('/__/auth/links');

  @override
  Future<UserCredential> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    if (exchangeError case final error?) throw error;
    exchanged.add((email, emailLink));
    account = _FakeAccount('uid-dolma', email: email);
    return _FakeCredential();
  }

  @override
  Future<void> signOut() async {
    if (signOutError case final error?) throw error;
    account = null;
  }
}

class _FakeApp extends Fake implements FirebaseApp {
  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'key',
    appId: 'app',
    messagingSenderId: 'sender',
    projectId: 'norbu-flow',
  );
}

class _FakeAccount extends Fake implements User {
  _FakeAccount(this.uid, {this.email});

  @override
  final String uid;

  @override
  final String? email;
}

class _FakeCredential extends Fake implements UserCredential {}
