import '../../../core/data/fake_repository.dart';
import '../domain/app_preferences.dart';

/// Keeps preferences for the lifetime of the process. Replace with a
/// persisted implementation (shared_preferences or the user's profile
/// document) alongside the Firebase work.
final class InMemoryPreferencesRepository extends FakeRepository
    implements PreferencesRepository {
  InMemoryPreferencesRepository() : super(Duration.zero);

  AppPreferences _stored = const AppPreferences();

  @override
  Future<AppPreferences> load() => respond(() => _stored);

  @override
  Future<void> save(AppPreferences preferences) =>
      respond(() => _stored = preferences);
}
