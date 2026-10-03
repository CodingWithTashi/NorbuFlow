import 'dart:convert';

import '../../../core/data/backend.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/error/failure_mapper.dart';
import '../../../core/models/photo_source.dart';
import '../../../core/theme/accent_preset.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json.dart';
import '../domain/role.dart';
import '../domain/temple.dart';
import '../domain/temple_features.dart';

/// The temples the backend has assigned to whoever is signed in.
final class FirebaseTempleRepository implements TempleRepository {
  FirebaseTempleRepository(this._backend);

  final Backend _backend;

  /// The backend knows who is calling, so [userId] is not sent.
  @override
  Future<List<TempleMembership>> fetchMemberships(String userId) =>
      guardFailures(() async {
        final response = await _backend.call('temples-list');
        return [
          for (final temple in response['temples']! as List)
            _membershipFromJson(temple),
        ];
      });

  // The backend keeps a temple's name, description and logo, set when it is
  // registered. It has nothing yet to save the rest of this screen to.
  @override
  Future<Temple> updateTemple(Temple temple) =>
      Future.error(const UnavailableFailure());

  static TempleMembership _membershipFromJson(Object? json) {
    final fields = jsonObject(json);
    final name = fields['name']! as String;
    final logo = fields['logo'] as String?;
    return TempleMembership(
      role: Role.values.byName(fields['role']! as String),
      temple: Temple(
        id: fields['id']! as String,
        nameEn: name,
        nameBo: '',
        monogram: initialsOf(name),
        // The one line a temple says about itself.
        tradition: fields['description']! as String,
        url: '',
        accent: AccentPreset.maroon,
        charityRegistration: '',
        address: '',
        signatory: '',
        logo: logo == null ? null : MemoryPhoto(base64Decode(logo)),
        features: _featuresFromJson(fields['features']),
      ),
    );
  }

  /// `tab.members`, `home.addMember`: names this version does not know are
  /// skipped. A backend that sends none shows everything.
  static TempleFeatures _featuresFromJson(Object? json) {
    if (json == null) return const TempleFeatures.all();
    final names = (json as List).whereType<String>().toSet();
    return TempleFeatures(
      tabs: {
        for (final tab in TempleTab.values)
          if (names.contains('tab.${tab.name}')) tab,
      },
      homeActions: {
        for (final action in HomeAction.values)
          if (names.contains('home.${action.name}')) action,
      },
    );
  }
}
