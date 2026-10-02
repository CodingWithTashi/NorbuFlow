import '../../../core/utils/json.dart';
import '../domain/auth_repository.dart';

/// The profile as the backend sends it, which is also how the device keeps it.
AuthUser authUserFromJson(Object? json) {
  final fields = jsonObject(json);
  return AuthUser(
    id: fields['id']! as String,
    email: fields['email']! as String,
    displayName: fields['displayName']! as String,
  );
}

Map<String, Object?> authUserToJson(AuthUser user) => {
  'id': user.id,
  'email': user.email,
  'displayName': user.displayName,
};
