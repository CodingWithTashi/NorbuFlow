import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/data/backend.dart';
import '../domain/auth_repository.dart';
import 'auth_local_store.dart';
import 'fake_auth_repository.dart';
import 'firebase_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.useFirebase) return FakeAuthRepository(config.fakeLatency);
  return FirebaseAuthRepository(
    auth: FirebaseAuth.instance,
    backend: ref.watch(backendProvider),
    store: AuthLocalStore(),
    incomingLinks: () => AppLinks().stringLinkStream,
  );
});
